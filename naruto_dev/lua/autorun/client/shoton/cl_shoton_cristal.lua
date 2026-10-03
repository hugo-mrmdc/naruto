--========================================================
-- Shoton : Cristal (CLIENT)
-- Lancement depuis la barre de techniques. Les particules restent sur le lanceur tant que le projectile invisible
-- avance (sv_shoton_cristal.lua) ; le cristal lui-même est l'entité shoton_cristal.
--========================================================

local FX = "wind_vortex_shoton_geams_rework_emeraude"   -- version rose (particles/solve_shoton_emeraude.pcf)
local FX_TOUCHE = "solve_explosion_pink_rubis"   -- sur la personne touchée (particles/solve_shoton_emeraude.pcf)
local HAUTEUR =70  -- hauteur des particules au-dessus des pieds du lanceur

local actifs = {}   -- lanceur -> système de particules

net.Receive("shoton_cristal_fx", function()
    local ply = net.ReadEntity()
    local actif = net.ReadBool()
    if not IsValid(ply) then return end

    if IsValid(actifs[ply]) then actifs[ply]:StopEmission() end
    actifs[ply] = nil
    if actif then actifs[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, HAUTEUR)) end
end)

-- Particules sur la personne touchée, pendant le stun
net.Receive("shoton_cristal_touche", function()
    local cible = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(cible) then return end
    local fx = CreateParticleSystem(cible, FX_TOUCHE, PATTACH_ABSORIGIN_FOLLOW)
    if fx then
        timer.Simple(duree, function() if IsValid(fx) then fx:StopEmission() end end)
    end
end)

NA_Cast = NA_Cast or {}
NA_Cast.shoton_cristal = function()
    net.Start("shoton_cristal_cast")
    net.SendToServer()
end
