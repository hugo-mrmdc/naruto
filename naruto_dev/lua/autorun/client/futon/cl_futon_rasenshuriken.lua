--========================================================
-- Futon : Rasenshuriken (CLIENT)
-- Lancement depuis la barre de techniques ; particule rasenshuri_pat dans la MAIN DROITE du lanceur tant que NW2Float
-- "NA_RasenFin" est dans le futur (posé par sv_futon_rasenshuriken.lua) ; explosion jouée à l'impact (message "futon_rasen_fx").
-- Le projectile et sa particule sont affichés par l'entité futon_rasenshuriken.
--========================================================

local FX_BOULE     = "rasenshuri_pat"
local FX_EXPLOSION = "[1]Rasenshuriken_Explosion_event_test"
local ATTACHE_MAIN = "anim_attachment_RH"   -- main DROITE
local DUREE_EXPLO  = 1.5                      -- secondes avant d'arrêter la particule d'explosion

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_BOULE)
PrecacheParticleSystem(FX_EXPLOSION)

NA_Cast = NA_Cast or {}
NA_Cast.futon_rasenshuriken = function()
    net.Start("futon_rasen_cast")
    net.SendToServer()
end

-- explosion
net.Receive("futon_rasen_fx", function()
    local pos = net.ReadVector()
    local normale = net.ReadVector()
    -- l'axe "haut" de la particule = la normale de la surface touchée (sol : droite vers le haut ; mur : à plat contre le mur)
    local ang = normale:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)
    local fx = CreateParticleSystemNoEntity(FX_EXPLOSION, pos + normale * 5, ang)
    if not fx then return end
    timer.Simple(DUREE_EXPLO, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end
    end)
end)

-- boule dans la main : joueur -> particule
-- Placée à la main droite puis DÉCALÉE dans le repère du regard (devant / à droite / en haut) et orientée comme le regard,
-- pour qu'on la voie bien (collée à la main, elle disparaît dans le corps ou dans la caméra). Réglages :
local DEVANT = 25            -- unités devant la main (dans le sens du regard)
local COTE   = 0             -- unités vers la droite (négatif : vers la gauche)
local HAUT   = 12            -- unités vers le haut
local ORIENTATION = Angle(90, 90, 0)   -- rotation de la particule par rapport au regard (pitch, yaw, roll) : essaie 90 / -90 si elle est de travers

local mains = {}

local function Couper(ply)
    local fx = mains[ply]
    if fx and fx:IsValid() then fx:StopEmission(false, true) end
    mains[ply] = nil
end

local function PosMain(ply)
    local att = ply:LookupAttachment(ATTACHE_MAIN)
    if att and att > 0 then
        local a = ply:GetAttachment(att)
        if a then return a.Pos end
    end
    return ply:WorldSpaceCenter() + ply:GetRight() * 12   -- repli : pas de point d'attache sur ce modèle
end

hook.Add("Think", "FutonRasen_Main", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Float("NA_RasenFin", 0) > now
        if actif then
            local ang = ply:EyeAngles()
            local pos = PosMain(ply) + ang:Forward() * DEVANT + ang:Right() * COTE + ang:Up() * HAUT
            local _, ori = LocalToWorld(vector_origin, ORIENTATION, vector_origin, ang)

            local fx = mains[ply]
            if not (fx and fx:IsValid()) then
                fx = CreateParticleSystemNoEntity(FX_BOULE, pos, ori)
                mains[ply] = fx
            end
            if fx then
                fx:SetControlPoint(0, pos)
                fx:SetControlPointOrientation(0, ori:Forward(), ori:Right(), ori:Up())
            end
        elseif mains[ply] then
            Couper(ply)
        end
    end
    for ply in pairs(mains) do
        if not IsValid(ply) then mains[ply] = nil end   -- joueurs partis
    end
end)
