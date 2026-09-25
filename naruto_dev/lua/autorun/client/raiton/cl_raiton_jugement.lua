--========================================================
-- Raiton : Jugement de l'éclair (CLIENT)
-- Lancement depuis la barre de techniques, et particule de la foudre sur le point frappé
-- (message "raiton_jugement_fx", sv_raiton_jugement.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "execution_eclair_pat"   -- particles/patlick_atgparticules.pcf
local HAUTEUR = 5                  -- la particule est posée 5 unités plus haut que le point frappé
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.raiton_jugement = function()
    net.Start("raiton_jugement_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)

net.Receive("raiton_jugement_fx", function()
    local pos   = net.ReadVector()
    local duree = net.ReadFloat()

    local fx = CreateParticleSystemNoEntity(FX, pos + Vector(0, 0, HAUTEUR), angle_zero)
    if not fx then return end
    timer.Simple(duree, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end
    end)
end)
