--========================================================
-- Chinoike : Ketsuryugan (SERVEUR)
--
-- Technique à activer / désactiver (même touche) :
--   - les yeux passent au Ketsuryugan (sv_yeux.lua) et s'allument
--     (particule ketsuryugan_pat, cl_chinoike_ketsuryugan.lua) ;
--   - tant qu'il est actif : dégâts infligés et vitesse de déplacement augmentés,
--     et chaque coup porté soigne d'un pourcentage des dégâts infligés (vol de vie) ;
--   - il consomme du chakra chaque seconde (la régénération AUTOMATIQUE est
--     coupée, mais on peut recharger avec R en même temps : sv_sprint_chakra.lua) ;
--     à 0 chakra, il se désactive.
--
-- Réseau : NW2Bool "NA_Ketsuryugan" (actif), "chinoike_ketsuryugan_on" (flash des yeux)
--========================================================

if not SERVER then return end

util.AddNetworkString("chinoike_ketsuryugan_cast")
util.AddNetworkString("chinoike_ketsuryugan_on")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local BONUS_DEGATS  = 20     -- % de dégâts infligés en plus
local BONUS_VITESSE = 5     -- % de vitesse de déplacement en plus
local VOL_VIE       = 2     -- % des dégâts infligés rendus en vie

local CHAKRA_SEC    = 5      -- chakra consommé par seconde
local CHAKRA_MINI   = 20     -- chakra requis pour l'activer
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 5      -- secondes avant de pouvoir le réactiver (après l'arrêt)
local DUREE_MUDRA   = 0.4    -- incantation avant l'activation
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "genjutsu/ketsuryugan_fort.wav"   -- ketsuryugan.wav amplifié de +6 dB
local SON_FIN       = "genjutsu/ketsuryugan_fin.wav"    -- le même, à l'envers, plus grave, avec fondu
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "chinoike_ketsuryugan", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_Ketsuryugan", false)
end

local function Arreter(ply, raison)
    if not Actif(ply) then return end
    ply:SetNW2Bool("NA_Ketsuryugan", false)

    -- yeux d'avant
    ply:SetNW2String("NA_Yeux", ply.NA_YeuxAvantKetsu or "")
    ply.NA_YeuxAvantKetsu = nil
    if NA_AppliquerYeux then NA_AppliquerYeux(ply) end

    local recharge = NA_Stat(ply, "chinoike_ketsuryugan", "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "chinoike_ketsuryugan", recharge) end   -- recharge visible dans la barre

    if ply:Alive() then ply:EmitSound(SON_FIN, 75, 100, 1) end
    if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    ply:SetNW2Bool("NA_Ketsuryugan", true)

    -- yeux Ketsuryugan (on garde les yeux d'avant pour les remettre à l'arrêt)
    ply.NA_YeuxAvantKetsu = ply:GetNW2String("NA_Yeux", "")
    if NA_ChangerYeux then NA_ChangerYeux(ply, "ketsuryugan") end

    net.Start("chinoike_ketsuryugan_on")
        net.WriteEntity(ply)
    net.Broadcast()
    ply:EmitSound(SON_DEBUT, 75, 100, 1)
end

net.Receive("chinoike_ketsuryugan_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà actif : on le coupe, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not NA_Debloquee(ply, "chinoike_ketsuryugan") then return end   -- technique pas encore débloquée (F6)
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

-- secours : couper le Ketsuryugan depuis la console ou le chat
concommand.Add("ketsuryugan_off", function(ply)
    if IsValid(ply) then Arreter(ply) end
end)
hook.Add("PlayerSay", "ChinoikeKetsuryugan_Chat", function(ply, texte)
    local t = string.lower(string.Trim(texte))
    if t == "!ketsuoff" or t == "/ketsuoff" then
        Arreter(ply)
        return ""
    end
end)

----------------------------------------------------------
-- Consommation du chakra (10 fois par seconde)
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "ChinoikeKetsuryugan_Chakra", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end
        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - NA_Stat(ply, "chinoike_ketsuryugan", "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, NA_ChakraMax(ply)))
        if reste <= 0 then Arreter(ply, "Chakra épuisé : le Ketsuryugan s'éteint") end
    end
end)

----------------------------------------------------------
-- Bonus
----------------------------------------------------------
hook.Add("EntityTakeDamage", "ChinoikeKetsuryugan_Degats", function(cible, dmg)
    local att = dmg:GetAttacker()
    if IsValid(att) and att:IsPlayer() and att ~= cible and Actif(att) then
        dmg:ScaleDamage(1 + NA_Stat(att, "chinoike_ketsuryugan", "bonus_degats", BONUS_DEGATS) / 100)
    end
end)

-- vol de vie : un % des dégâts VRAIMENT infligés (après armures, boucliers...)
-- revient en vie au lanceur ; les fractions de PV s'accumulent d'un coup à l'autre
hook.Add("PostEntityTakeDamage", "ChinoikeKetsuryugan_VolDeVie", function(cible, dmg, subi)
    if not subi then return end
    local att = dmg:GetAttacker()
    if not IsValid(att) or not att:IsPlayer() or att == cible or not att:Alive() or not Actif(att) then return end
    if not (cible:IsPlayer() or cible:IsNPC() or cible:IsNextBot()) then return end   -- pas de soin sur le décor

    local maxi = att:GetMaxHealth()
    if att:Health() >= maxi then att.NA_KetsuSoin = 0 return end

    att.NA_KetsuSoin = (att.NA_KetsuSoin or 0) + dmg:GetDamage() * Niv(att, "vol_vie", VOL_VIE) / 100
    local entier = math.floor(att.NA_KetsuSoin)
    if entier >= 1 then
        att.NA_KetsuSoin = att.NA_KetsuSoin - entier
        att:SetHealth(math.min(att:Health() + entier, maxi))
    end
end)

hook.Add("Move", "ChinoikeKetsuryugan_Vitesse", function(ply, mv)
    if not Actif(ply) then return end
    local mult = 1 + NA_Stat(ply, "chinoike_ketsuryugan", "bonus_vitesse", BONUS_VITESSE) / 100
    mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "ChinoikeKetsuryugan_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "ChinoikeKetsuryugan_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "ChinoikeKetsuryugan_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
