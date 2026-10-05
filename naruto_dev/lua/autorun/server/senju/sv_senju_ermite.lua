--========================================================
-- Senju : Ermite naturel (SERVEUR)
--
-- Technique à activer / désactiver (même touche, comme le Ketsuryugan) : le lanceur puise dans l'énergie de la nature.
--   - une aura entoure le corps (particule ermite_naturel_pat, particles/patlick_atgparticules.pcf,
--     dessinée par cl_senju_ermite.lua) ;
--   - tant qu'elle dure : dégâts infligés et vitesse augmentés, dégâts subis réduits,
--     et la vie se régénère ;
--   - consomme du chakra chaque seconde (la régénération AUTOMATIQUE est coupée, mais on peut
--     recharger avec R : sv_sprint_chakra.lua) ; à 0 chakra, elle se désactive.
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

local CHAKRA_SEC    = 4      -- chakra consommé par seconde
local CHAKRA_MINI   = 30     -- chakra requis pour l'activer
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 45     -- secondes avant de pouvoir la relancer (après l'arrêt)
local DUREE_MUDRA   = 1      -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "naruto_sound/jutsu/senju/senju3.wav"
local SON_FIN       = "naruto_sound/jutsu/senju/senju4.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_ermite", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local regen   = {}   -- joueur -> fractions de PV accumulées

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_SenjuErmite", false)
end

local function Arreter(ply, raison)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_SenjuErmite", false)
    regen[ply] = nil

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "senju_ermite", recharge) end   -- recharge visible dans la barre

    if ply:Alive() then ply:EmitSound(SON_FIN, 70, 100, 0.7) end
    if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    ply:SetNW2Bool("NA_SenjuErmite", true)
    ply:EmitSound(SON_DEBUT, 75, 90, 0.8)
end

net.Receive("senju_ermite_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà active : on la coupe, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not ply:Alive() or enCours[ply] then return end
    if not NA_Debloquee(ply, "senju_ermite") then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    if ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) < Niv(ply, "chakra_mini", CHAKRA_MINI) then
        ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
        return
    end

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
-- Consommation du chakra et régénération de la vie, 10 fois par seconde
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "SenjuErmite_Tick", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end

        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - Niv(ply, "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, CHAKRA_MAX))

        if reste <= 0 then
            Arreter(ply, "Chakra épuisé : l'Ermite naturel s'éteint")
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
    regen[ply] = nil
    if IsValid(ply) then ply:SetNW2Bool("NA_SenjuErmite", false) end   -- pas de recharge en cas de mort
end

hook.Add("PlayerDeath", "SenjuErmite_Mort", Nettoyer)
hook.Add("PlayerSpawn", "SenjuErmite_Spawn", Nettoyer)
hook.Add("PlayerDisconnected", "SenjuErmite_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
