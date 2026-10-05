--========================================================
-- Raiton : Zone de foudre (CLIENT)
-- Lancement depuis la barre de techniques. La zone et les arcs sont affichés par l'entité raiton_zone (lua/entities).
--========================================================

game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_area")
PrecacheParticleSystem("solve_raiton_ball_link_vplayer")

NA_Cast = NA_Cast or {}
NA_Cast.raiton_zone = function()
    net.Start("raiton_zone_cast")
    net.SendToServer()
end
