--========================================================
-- Uchiha : Genjutsu du Sharingan (SERVEUR)
--
-- On vise un ennemi à portée. Après les mudras, il croise ton regard : il est
-- étourdi (étourdissement commun, sv_etourdissement.lua) pendant DUREE secondes
-- et, si c'est un joueur, il voit le modèle du genjutsu autour de lui
-- (cl_uchiha_genjutsu.lua). Aucun dégât : c'est un stun pur.
--
-- Réseau : "uchiha_genjutsu_cast" (client -> serveur)
--          "uchiha_genjutsu_cible" (serveur -> clients : cible + durée)
--========================================================

util.AddNetworkString("uchiha_genjutsu_cast")
util.AddNetworkString("uchiha_genjutsu_cible")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local PORTEE       = 800    -- distance maximale de la cible
local TAILLE_VISEE = 20     -- demi-taille de la hitbox de visée (developer 1 pour la voir)
local DUREE        = 3      -- secondes d'étourdissement
local RECHARGE     = 20     -- secondes avant de pouvoir relancer
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.5    -- incantation avant le genjutsu
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local SON_CIBLE    = "genjutsu/sharingan_deploy.wav"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "uchiha_genjutsu", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Ennemi visé : boîte lancée depuis les yeux jusqu'au premier mur, on prend le plus proche
local function TrouverCible(ply)
    local oeil = ply:EyePos()
    local t = Vector(1, 1, 1) * Niv(ply, "hitbox", TAILLE_VISEE)
    local portee = Niv(ply, "portee", PORTEE)

    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.SweptBox(oeil, mur.HitPos, -t, t, angle_zero, 2, cible and Color(0, 255, 0, 40) or Color(255, 60, 60, 40))
    end

    return cible
end

local function Pieger(ply, cible)
    local duree = Niv(ply, "duree", DUREE)

    net.Start("uchiha_genjutsu_cible")
        net.WriteEntity(cible)
        net.WriteFloat(duree)
    net.Broadcast()

    cible:EmitSound(SON_CIBLE, 75, 100, 0.8)
    if NA_Etourdir then NA_Etourdir(cible, duree) end
end

net.Receive("uchiha_genjutsu_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if not NA_Debloquee(ply, "uchiha_genjutsu") then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    local cible = TrouverCible(ply)

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "uchiha_genjutsu", recharge) end

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        -- la cible a pu mourir ou s'éloigner pendant l'incantation
        if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > Niv(ply, "portee", PORTEE) * 1.2 then return end
        Pieger(ply, cible)
    end)
end)

hook.Add("PlayerDisconnected", "UchihaGenjutsu_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
