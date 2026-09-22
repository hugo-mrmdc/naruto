--========================================================
-- Kiminari : Laser Circus (CLIENT)
-- Lancement depuis la barre de techniques, et un rayon
-- laser_circus_kiminari_pat par laser tiré ("kiminari_laser_fx",
-- sv_kiminari_laser.lua) : point de contrôle 0 = départ, 1 = arrivée.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "laser_circus_kiminari_pat"   -- particles/patlick_atgparticules.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kiminari_laser = function()
    net.Start("kiminari_laser_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)

net.Receive("kiminari_laser_fx", function()
    local depart = net.ReadVector()
    for _ = 1, net.ReadUInt(6) do
        local arrivee = net.ReadVector()
        local fx = CreateParticleSystemNoEntity(FX, depart, (arrivee - depart):Angle())
        if fx and fx:IsValid() then
            fx:SetControlPoint(0, depart)
            fx:SetControlPoint(1, arrivee)
        end
    end
end)
