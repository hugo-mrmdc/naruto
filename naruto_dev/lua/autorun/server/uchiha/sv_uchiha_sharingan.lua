--========================================================
-- Uchiha : Sharingan (SERVEUR)
--
-- Technique à activer / désactiver (même touche) :
--   - le niveau de la technique (F6) fait évoluer les tomoe :
--       niveaux 1 et 2 : 1 tomoe, niveau 3 : 2 tomoe, niveaux 4 et 5 : 3 tomoe ;
--     les yeux suivent (sharingan1 / sharingan2 / sharingan3, sv_yeux.lua) ;
--   - tant qu'il est actif : les ennemis proches sont surlignés à travers les
--     murs (cl_uchiha_sharingan.lua), tes dégâts augmentent et tu en subis moins ;
--   - il consomme du chakra chaque seconde (la régénération AUTOMATIQUE est
--     coupée, mais on peut recharger avec R en même temps : sv_sprint_chakra.lua) ;
--     à 0 chakra, il se désactive.
--
-- Réseau : NW2Bool "NA_Sharingan" (actif), NW2Int "NA_SharinganTomoe" (1 à 3),
-- NW2Float "NA_SharinganRayon" (rayon de vision)
--========================================================

if not SERVER then return end

util.AddNetworkString("uchiha_sharingan_cast")
util.AddNetworkString("uchiha_sharingan_on")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua)
--========================================================
local TOMOE         = 1      -- nombre de tomoe (1 à 3)
local RAYON         = 800    -- rayon de détection à travers les murs
local BONUS_DEGATS  = 5      -- % de dégâts infligés en plus
local REDUCTION     = 5      -- % de dégâts subis en moins

local CHAKRA_SEC    = 1.5    -- chakra consommé par seconde
local CHAKRA_MINI   = 15     -- chakra requis pour l'activer
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 10     -- secondes avant de pouvoir le réactiver (après l'arrêt)
local DUREE_MUDRA   = 0.3    -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "naruto_sound/jutsu/uchiha/uchiha3.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "uchiha_sharingan", stat, base) end

local function NbTomoe(ply)
    return math.Clamp(math.floor(Niv(ply, "tomoe", TOMOE)), 1, 3)
end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_Sharingan", false)
end

local function Arreter(ply, raison)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_Sharingan", false)
    ply:SetNW2Int("NA_SharinganTomoe", 0)

    -- yeux d'avant
    ply:SetNW2String("NA_Yeux", ply.NA_YeuxAvantSharingan or "")
    ply.NA_YeuxAvantSharingan = nil
    if NA_AppliquerYeux then NA_AppliquerYeux(ply) end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "uchiha_sharingan", recharge) end   -- recharge visible dans la barre

    if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    local tomoe = NbTomoe(ply)
    ply:SetNW2Bool("NA_Sharingan", true)
    ply:SetNW2Int("NA_SharinganTomoe", tomoe)
    ply:SetNW2Float("NA_SharinganRayon", Niv(ply, "rayon", RAYON))

    -- yeux Sharingan du bon nombre de tomoe (on garde les yeux d'avant pour les remettre à l'arrêt)
    ply.NA_YeuxAvantSharingan = ply:GetNW2String("NA_Yeux", "")
    if NA_ChangerYeux then NA_ChangerYeux(ply, "sharingan" .. tomoe) end

    net.Start("uchiha_sharingan_on")
        net.WriteEntity(ply)
    net.Broadcast()
    ply:EmitSound(SON_DEBUT, 75, 130, 1)
end

net.Receive("uchiha_sharingan_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà actif : on le coupe, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not NA_Debloquee(ply, "uchiha_sharingan") then return end   -- technique pas encore débloquée (F6)
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

-- secours : couper le Sharingan depuis la console ou le chat
concommand.Add("sharingan_off", function(ply)
    if IsValid(ply) then Arreter(ply) end
end)
hook.Add("PlayerSay", "UchihaSharingan_Chat", function(ply, texte)
    local t = string.lower(string.Trim(texte))
    if t == "!sharioff" or t == "/sharioff" then
        Arreter(ply)
        return ""
    end
end)

----------------------------------------------------------
-- Consommation du chakra (10 fois par seconde)
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "UchihaSharingan_Chakra", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end
        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - Niv(ply, "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, CHAKRA_MAX))
        if reste <= 0 then Arreter(ply, "Chakra épuisé : le Sharingan s'éteint") end
    end
end)

----------------------------------------------------------
-- Bonus
----------------------------------------------------------
hook.Add("EntityTakeDamage", "UchihaSharingan_Degats", function(cible, dmg)
    local att = dmg:GetAttacker()
    if IsValid(att) and att:IsPlayer() and att ~= cible and Actif(att) then
        dmg:ScaleDamage(1 + Niv(att, "bonus_degats", BONUS_DEGATS) / 100)
    end

    if IsValid(cible) and cible:IsPlayer() and Actif(cible) then
        dmg:ScaleDamage(math.max(0, 1 - Niv(cible, "reduction", REDUCTION) / 100))
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "UchihaSharingan_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "UchihaSharingan_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "UchihaSharingan_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
