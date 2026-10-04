--========================================================
-- Shoton : Cristal (CLIENT)
-- Lancement depuis la barre de techniques. Les particules restent sur le lanceur tant que le projectile invisible
-- avance (sv_shoton_cristal.lua) ; le cristal lui-même est l'entité shoton_cristal.
--========================================================

local FX = "wind_vortex_shoton_geams_v2"   -- sur le lanceur (particles/solve_futon_rework_geams.pcf, chargé par shoton_init.lua)
local FX_TOUCHE = "solve_explosion_pink_rubis"   -- sur la personne touchée (particles/solve_shoton_emeraude.pcf)
local HAUTEUR =70  -- hauteur des particules au-dessus des pieds du lanceur

local actifs = {}   -- lanceur -> système de particules

net.Receive("shoton_cristal_fx", function()
    local ply = net.ReadEntity()
    local actif = net.ReadBool()
    if not IsValid(ply) then return end

    if IsValid(actifs[ply]) then actifs[ply]:StopEmission() end
    actifs[ply] = nil
    -- posée au lancement : elle ne suit pas le lanceur. Les particules s'étalent d'elles-mêmes sur 700 unités le long de
    -- l'axe X du point de contrôle (solve_futon_rework_geams.pcf) : on l'oriente vers là où le lanceur regarde (à l'horizontale)
    if actif then
        local depart = ply:GetPos() + Vector(0, 0, HAUTEUR)
        local ang = Angle(0, ply:EyeAngles().y, 0)
        local fx = CreateParticleSystemNoEntity(FX, depart)
        if fx then
            fx:SetControlPoint(0, depart)
            fx:SetControlPointOrientation(0, ang:Forward(), ang:Right(), ang:Up())
        end
        actifs[ply] = fx
    end
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

-- Le cristal se brise : les mêmes particules qu'à sa création
net.Receive("shoton_cristal_brise", function()
    ParticleEffect(FX_TOUCHE, net.ReadVector(), angle_zero)
end)

NA_Cast = NA_Cast or {}
NA_Cast.shoton_cristal = function()
    net.Start("shoton_cristal_cast")
    net.SendToServer()
end
