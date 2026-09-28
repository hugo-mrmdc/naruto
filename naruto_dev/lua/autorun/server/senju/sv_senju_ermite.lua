--========================================================
-- Senju : Ermite naturel (SERVEUR)
--
-- Technique à durée fixe : le lanceur puise dans l'énergie de la nature pendant "duree" secondes.
--   - une aura entoure le corps (particule ermite_naturel_pat, particles/patlick_atgparticules.pcf,
--     dessinée par cl_senju_ermite.lua) ;
--   - tant qu'elle dure : dégâts infligés et vitesse augmentés, dégâts subis réduits,
--     et la vie se régénère ;
--   - coûte du chakra une seule fois, au lancement ; on ne peut pas la relancer tant qu'elle agit.
--
-- Réseau : NW2Bool "NA_SenjuErmite" (actif)
--========================================================

if not SERVER then return end

util.AddNetworkString("senju_ermite_cast")

resource.AddFile("materials/naruto_dev/marques/ermite_naturel_visible.vmt")
resource.AddFile("materials/naruto_dev/marques/ermite_naturel.vtf")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.senju_ermite)
--========================================================
local BONUS_DEGATS  = 20     -- % de dégâts infligés en plus
local REDUCTION     = 15     -- % de dégâts subis en moins
local BONUS_VITESSE = 10     -- % de vitesse de déplacement en plus
local REGEN_VIE     = 3      -- points de vie rendus par seconde

local DUREE         = 20     -- secondes d'effet
local CHAKRA_COUT   = 50     -- chakra consommé au lancement (une seule fois)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 45     -- secondes avant de pouvoir la relancer (après la fin)
local DUREE_MUDRA   = 1      -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "items/suitchargeok1.wav"
local SON_FIN       = "items/suitchargeno1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_ermite", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local fins    = {}   -- joueur -> moment où l'effet se termine
local regen   = {}   -- joueur -> fractions de PV accumulées

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_SenjuErmite", false)
end

local function Arreter(ply)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_SenjuErmite", false)
    fins[ply], regen[ply] = nil, nil

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "senju_ermite", recharge) end   -- recharge visible dans la barre

    if ply:Alive() then ply:EmitSound(SON_FIN, 70, 100, 0.7) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    fins[ply] = CurTime() + Niv(ply, "duree", DUREE)
    ply:SetNW2Bool("NA_SenjuErmite", true)
    ply:EmitSound(SON_DEBUT, 75, 90, 0.8)
end

net.Receive("senju_ermite_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "senju_ermite") then return end   -- technique pas encore débloquée (F6)
    if Actif(ply) or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then
        ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    enCours[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Fin du temps imparti et régénération de la vie, 10 fois par seconde
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "SenjuErmite_Tick", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end

        if now >= (fins[ply] or 0) then
            Arreter(ply)
        elseif ply:Alive() and ply:Health() < ply:GetMaxHealth() then
            -- les fractions de PV s'accumulent d'un tick à l'autre
            regen[ply] = (regen[ply] or 0) + Niv(ply, "regen_vie", REGEN_VIE) * dt
            local entier = math.floor(regen[ply])
            if entier >= 1 then
                regen[ply] = regen[ply] - entier
                ply:SetHealth(math.min(ply:Health() + entier, ply:GetMaxHealth()))
            end
        end
    end
end)

----------------------------------------------------------
-- Bonus de dégâts, résistance, vitesse
----------------------------------------------------------
hook.Add("EntityTakeDamage", "SenjuErmite_Degats", function(cible, dmg)
    -- dégâts infligés
    local att = dmg:GetAttacker()
    if IsValid(att) and att:IsPlayer() and att ~= cible and Actif(att) then
        dmg:ScaleDamage(1 + Niv(att, "bonus_degats", BONUS_DEGATS) / 100)
    end

    -- dégâts subis
    if IsValid(cible) and cible:IsPlayer() and Actif(cible) then
        dmg:ScaleDamage(1 - Niv(cible, "reduction", REDUCTION) / 100)
    end
end)

hook.Add("Move", "SenjuErmite_Vitesse", function(ply, mv)
    if not Actif(ply) then return end
    local mult = 1 + Niv(ply, "bonus_vitesse", BONUS_VITESSE) / 100
    mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
local function Nettoyer(ply)
    enCours[ply] = nil
    fins[ply], regen[ply] = nil, nil
    if IsValid(ply) then ply:SetNW2Bool("NA_SenjuErmite", false) end   -- pas de recharge en cas de mort
end

hook.Add("PlayerDeath", "SenjuErmite_Mort", Nettoyer)
hook.Add("PlayerSpawn", "SenjuErmite_Spawn", Nettoyer)
hook.Add("PlayerDisconnected", "SenjuErmite_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
