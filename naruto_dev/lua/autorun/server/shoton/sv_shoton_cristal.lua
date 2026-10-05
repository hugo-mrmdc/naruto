--========================================================
-- Shoton : Cristal (SERVEUR) - stun
-- Après les mudras, un projectile INVISIBLE avance tout droit devant le lanceur ; le premier ennemi touché est
-- étourdi DUREE secondes (NA_Etourdir) dans un cristal (entité shoton_cristal). Les particules ne bougent pas :
-- elles restent sur le lanceur tant que le projectile avance (cl_shoton_cristal.lua).
-- Sans ennemi touché : mudras + recharge quand même.
--
-- Réseau : "shoton_cristal_cast" (client -> serveur), "shoton_cristal_fx" (serveur -> clients : particules du lanceur)
--========================================================

util.AddNetworkString("shoton_cristal_cast")
util.AddNetworkString("shoton_cristal_fx")
util.AddNetworkString("shoton_cristal_touche")
util.AddNetworkString("shoton_cristal_brise")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 3      -- durée du stun (secondes)
local PORTEE       = 900    -- distance maximale parcourue par le projectile invisible
local VITESSE      = 1500   -- vitesse du projectile (unités/s)
local RAYON        = 30     -- demi-largeur de sa hitbox
local RECHARGE     = 18
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.3
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local PAS          = 0.02   -- secondes entre deux avancées du projectile
--========================================================

local ID = "shoton_cristal"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Particules(ply, actif)
    net.Start("shoton_cristal_fx")
        net.WriteEntity(ply)
        net.WriteBool(actif)
    net.Broadcast()
end

local function Emprisonner(ply, cible)
    local duree = Niv(ply, "duree", DUREE)
    if NA_Etourdir then NA_Etourdir(cible, duree) end
    local ent = ents.Create("shoton_cristal")
    if not IsValid(ent) then return end
    ent:SetOwner(ply)
    ent.Cible    = cible
    ent.DureeVie = duree
    ent:Spawn()
    net.Start("shoton_cristal_touche")   -- particules sur la personne touchée (cl_shoton_cristal.lua)
        net.WriteEntity(cible)
        net.WriteFloat(duree)
    net.Broadcast()
    cible:EmitSound("geams/solve_jutsu/shoton/solve_shoton_shuriken_start.wav", 75, 70)
end

-- Projectile invisible : avance par pas, s'arrête sur un mur, un obstacle ou le premier ennemi touché
local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local pos = ply:GetShootPos()
    local dir = ply:GetAimVector()
    local reste = Niv(ply, "portee", PORTEE)
    local pas = Niv(ply, "vitesse", VITESSE) * PAS
    local t = Vector(1, 1, 1) * Niv(ply, "rayon", RAYON)
    local nom = "ShotonCristal_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)

    Particules(ply, true)
    timer.Create(nom, PAS, 0, function()
        if not IsValid(ply) or not ply:Alive() or reste <= 0 then
            timer.Remove(nom)
            if IsValid(ply) then Particules(ply, false) end
            return
        end
        local d = math.min(pas, reste)
        local tr = util.TraceHull({
            start = pos, endpos = pos + dir * d, mins = -t, maxs = t,
            filter = ply, mask = MASK_SOLID,
        })
        reste = reste - d
        pos = tr.HitPos
        -- hitbox visible avec developer 1 (comme le projectile de vapeur)
        if GetConVar("developer"):GetInt() > 0 then
            debugoverlay.Box(pos, -t, t, 0.1, Color(255, 100, 200, 25))
        end
        if tr.Hit and not EstCible(tr.Entity, ply) and tr.HitNormal.z > 0.7 then
            -- sol : l'onde glisse dessus au lieu de s'arrêter (viser le sol / les pieds de la cible la touche quand même)
            local glisse = dir - tr.HitNormal * dir:Dot(tr.HitNormal)
            if glisse:LengthSqr() < 0.01 then glisse = ply:GetForward() glisse.z = 0 end   -- visée droit vers le bas
            dir = glisse:GetNormalized()
            pos = tr.HitPos + tr.HitNormal
        elseif tr.Hit then
            timer.Remove(nom)
            Particules(ply, false)
            if EstCible(tr.Entity, ply) then Emprisonner(ply, tr.Entity) end
        end
    end)
end

net.Receive("shoton_cristal_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

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
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "ShotonCristal_Nettoyage", function(ply) pret[ply] = nil end)
