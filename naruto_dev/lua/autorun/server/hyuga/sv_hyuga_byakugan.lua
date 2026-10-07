--========================================================
-- Hyuga : Byakugan (SERVEUR)
--
-- Technique à activer / désactiver (même touche) :
--   - les yeux passent au Byakugan (sv_yeux.lua) ;
--   - tant qu'il est actif : les ennemis proches (joueurs et PNJ) sont détectés
--     à travers les murs, dans un rayon qui augmente avec le niveau
--     (halo côté client, cl_hyuga_byakugan.lua) ;
--   - il consomme du chakra chaque seconde (la régénération AUTOMATIQUE est
--     coupée, mais on peut recharger avec R en même temps : sv_sprint_chakra.lua) ;
--     à 0 chakra, il se désactive.
--
-- Réseau : NW2Bool "NA_Byakugan" (actif), NW2Float "NA_ByakuganRayon" (rayon de vision)
--========================================================

if not SERVER then return end

util.AddNetworkString("hyuga_byakugan_cast")
util.AddNetworkString("hyuga_byakugan_on")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local RAYON         = 1000   -- rayon de détection à travers les murs

local CHAKRA_SEC    = 1      -- chakra consommé par seconde
local CHAKRA_MINI   = 15     -- chakra requis pour l'activer
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 15     -- secondes avant de pouvoir le réactiver (après l'arrêt)
local DUREE_MUDRA   = 0.3    -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "genjutsu/byakugan_deploy.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "hyuga_byakugan", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_Byakugan", false)
end

local function Arreter(ply, raison)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_Byakugan", false)

    -- yeux d'avant
    ply:SetNW2String("NA_Yeux", ply.NA_YeuxAvantByakugan or "")
    ply.NA_YeuxAvantByakugan = nil
    if NA_AppliquerYeux then NA_AppliquerYeux(ply) end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "hyuga_byakugan", recharge) end   -- recharge visible dans la barre

    if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    ply:SetNW2Bool("NA_Byakugan", true)
    ply:SetNW2Float("NA_ByakuganRayon", Niv(ply, "rayon", RAYON))

    -- yeux Byakugan (on garde les yeux d'avant pour les remettre à l'arrêt)
    ply.NA_YeuxAvantByakugan = ply:GetNW2String("NA_Yeux", "")
    if NA_ChangerYeux then NA_ChangerYeux(ply, "byakugan") end

    net.Start("hyuga_byakugan_on")
        net.WriteEntity(ply)
    net.Broadcast()
    ply:EmitSound(SON_DEBUT, 75, 100, 1)
end

net.Receive("hyuga_byakugan_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà actif : on le coupe, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not NA_Debloquee(ply, "hyuga_byakugan") then return end   -- technique pas encore débloquée (F6)
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

-- secours : couper le Byakugan depuis la console ou le chat
concommand.Add("byakugan_off", function(ply)
    if IsValid(ply) then Arreter(ply) end
end)
hook.Add("PlayerSay", "HyugaByakugan_Chat", function(ply, texte)
    local t = string.lower(string.Trim(texte))
    if t == "!byakuoff" or t == "/byakuoff" then
        Arreter(ply)
        return ""
    end
end)

----------------------------------------------------------
-- Consommation du chakra (10 fois par seconde)
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "HyugaByakugan_Chakra", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end
        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - Niv(ply, "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, NA_ChakraMax(ply)))
        if reste <= 0 then Arreter(ply, "Chakra épuisé : le Byakugan s'éteint") end
    end
end)

----------------------------------------------------------
-- Boost Hyuga : tenketsu abîmés
-- Byakugan actif, chaque coup de poing / taijutsu / technique Hyuga (tous en DMG_CLUB, attaquant = le joueur)
-- abîme les tenketsu de la cible : ils virent au rouge (cl_hyuga_byakugan.lua) et tes dégâts de ce type
-- augmentent contre elle, jusqu'à TENKETSU_MAX coups. Sans coup pendant TENKETSU_DUREE, ils guérissent.
-- Réseau (sur la cible) : NW2Float "NA_TenketsuRatio" (0 à 1), NW2Float "NA_TenketsuFin" (CurTime de guérison)
----------------------------------------------------------
local TENKETSU_MAX    = 10     -- coups pour des tenketsu entièrement rouges
local TENKETSU_BONUS  = 0.05   -- dégâts en plus par coup déjà porté (10 coups = +50 %)
local TENKETSU_DUREE  = 5      -- secondes sans coup avant que les tenketsu guérissent

local function Tenketsu(ent)
    if CurTime() > ent:GetNW2Float("NA_TenketsuFin", 0) then return 0 end
    return math.Round(ent:GetNW2Float("NA_TenketsuRatio", 0) * TENKETSU_MAX)
end

hook.Add("EntityTakeDamage", "HyugaByakugan_Tenketsu", function(cible, dmg)
    local ply = dmg:GetAttacker()
    if not (IsValid(ply) and ply:IsPlayer() and Actif(ply)) or cible == ply then return end
    if not dmg:IsDamageType(DMG_CLUB) then return end
    if not (cible:IsPlayer() or cible:IsNPC() or cible:IsNextBot()) then return end

    local coups = Tenketsu(cible)
    dmg:ScaleDamage(1 + coups * Niv(ply, "tenketsu_bonus", TENKETSU_BONUS))

    cible:SetNW2Float("NA_TenketsuRatio", math.min(coups + 1, TENKETSU_MAX) / TENKETSU_MAX)
    cible:SetNW2Float("NA_TenketsuFin", CurTime() + TENKETSU_DUREE)
end)

hook.Add("PlayerDeath", "HyugaByakugan_TenketsuGuerison", function(ply) ply:SetNW2Float("NA_TenketsuFin", 0) end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "HyugaByakugan_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "HyugaByakugan_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "HyugaByakugan_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
