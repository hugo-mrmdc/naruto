--========================================================
-- Raiton : Boule de foudre (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_raiton_boule.lua, qui décide de tout).
-- La particule est attachée à l'entité raiton_ball par le serveur.
--========================================================

game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_ball_small")

NA_Cast = NA_Cast or {}
NA_Cast.raiton_boule = function()
    net.Start("raiton_boule_cast")
    net.SendToServer()
end
