--========================================================
-- Senju : Renforcement (SERVEUR)
--
-- Technique à activer / désactiver (même touche) :
--   - une aura verte entoure le corps (particule aura_senju_renfo,
--     particles/slyzz_particles.pcf, dessinée par cl_senju_renfo.lua) ;
--   - tant qu'elle est active : dégâts infligés et vitesse augmentés, dégâts subis
--     réduits, et la vie se régénère doucement ;
--   - elle consomme du chakra chaque seconde (la régénération AUTOMATIQUE est
--     coupée, mais on peut recharger avec R en même temps : sv_sprint_chakra.lua) ;
--     à 0 chakra, elle s'arrête.
--
-- Réseau : NW2Bool "NA_SenjuRenfo" (actif)
--========================================================

if not SERVER then return end

util.AddNetworkString("senju_renfo_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.senju_renfo)
--========================================================
local BONUS_DEGATS  = 15     -- % de dégâts infligés en plus
local REDUCTION     = 15     -- % de dégâts subis en moins
local BONUS_VITESSE = 8      -- % de vitesse de déplacement en plus
local REGEN_VIE     = 2      -- points de vie rendus par seconde

local CHAKRA_SEC    = 3      -- chakra consommé par seconde
local CHAKRA_MINI   = 20     -- chakra requis pour l'activer
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 15     -- secondes avant de pouvoir la réactiver (après l'arrêt)
local DUREE_MUDRA   = 0.5    -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "items/suitchargeok1.wav"
local SON_FIN       = "items/suitchargeno1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_renfo", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_SenjuRenfo", false)
end

local function Arreter(ply, raison)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_SenjuRenfo", false)
    ply.NA_SenjuSoin = nil

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "senju_renfo", recharge) end   -- recharge visible dans la barre

    if ply:Alive() then ply:EmitSound(SON_FIN, 70, 100, 0.7) end
    if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    ply:SetNW2Bool("NA_SenjuRenfo", true)
    ply:EmitSound(SON_DEBUT, 75, 100, 0.8)
end

net.Receive("senju_renfo_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà actif : on l'arrête, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not NA_Debloquee(ply, "senju_renfo") then return end   -- technique pas encore débloquée (F6)
    if not ply:Alive() or enCours[ply] then return end

    if (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) < Niv(ply, "chakra_mini", CHAKRA_MINI) then
        ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
        return
    end

    enCours[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

-- secours : arrêter le renforcement depuis la console
concommand.Add("senju_renfo_off", function(ply)
    if IsValid(ply) then Arreter(ply) end
end)

----------------------------------------------------------
-- Chakra (consommation) et vie (régénération), 10 fois par seconde
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "SenjuRenfo_Tick", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end

        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - Niv(ply, "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, CHAKRA_MAX))
        if reste <= 0 then
            Arreter(ply, "Chakra épuisé : le renforcement s'arrête")
        elseif ply:Alive() and ply:Health() < ply:GetMaxHealth() then
            -- les fractions de PV s'accumulent d'un tick à l'autre
            ply.NA_SenjuSoin = (ply.NA_SenjuSoin or 0) + Niv(ply, "regen_vie", REGEN_VIE) * dt
            local entier = math.floor(ply.NA_SenjuSoin)
            if entier >= 1 then
                ply.NA_SenjuSoin = ply.NA_SenjuSoin - entier
                ply:SetHealth(math.min(ply:Health() + entier, ply:GetMaxHealth()))
            end
        end
    end
end)

----------------------------------------------------------
-- Bonus de dégâts, résistance, vitesse
----------------------------------------------------------
hook.Add("EntityTakeDamage", "SenjuRenfo_Degats", function(cible, dmg)
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

hook.Add("Move", "SenjuRenfo_Vitesse", function(ply, mv)
    if not Actif(ply) then return end
    local mult = 1 + Niv(ply, "bonus_vitesse", BONUS_VITESSE) / 100
    mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "SenjuRenfo_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "SenjuRenfo_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "SenjuRenfo_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
