--========================================================
-- Raiton : Cercle de foudre (CLIENT)
-- Lancement depuis la barre de techniques, et particule du cercle à chaque impulsion
-- (message "raiton_cercle_fx", sv_raiton_cercle.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "izox_raiton_circle_deux"   -- particles/1izoxsolvenr.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.raiton_cercle = function()
    net.Start("raiton_cercle_cast")
    net.SendToServer()
end

game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem(FX)

net.Receive("raiton_cercle_fx", function()
    local ply   = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    -- accrochée au joueur : le cercle le suit partout
    local fx = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0)
    if not fx then return end
    timer.Simple(duree, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end
    end)
end)
