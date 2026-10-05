--========================================================
-- Futon : Expulsion de vent (CLIENT)
-- Lancement depuis la barre de techniques ; joue la particule d'explosion envoyée par le serveur.
-- (particles/solve_futon.pcf, chargé ici)
--========================================================

game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_repulsion")

NA_Cast = NA_Cast or {}
NA_Cast.futon_expulsion = function()
    net.Start("futon_expulsion_cast")
    net.SendToServer()
end

-- Une seule particule, posee au sol sous le lanceur (ParticleEffect : pas attachee a lui).
net.Receive("futon_expulsion_fx", function()
    local ply = net.ReadEntity()
    net.ReadFloat()   -- rayon (non utilise : un seul effet)
    if not IsValid(ply) then return end
    ParticleEffect("solve_futon_repulsion", ply:GetPos(), angle_zero)
end)
