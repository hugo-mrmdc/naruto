--========================================================
-- Doton : Pics de pierre (CLIENT)
-- Lancement depuis la barre de techniques ; joue la particule au sol sous chaque cible touchée (envoyée par le serveur).
--========================================================

game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_pics_floor")

NA_Cast = NA_Cast or {}
NA_Cast.doton_pics = function()
    net.Start("doton_pics_cast")
    net.SendToServer()
end

net.Receive("doton_pics_fx", function()
    ParticleEffect("solve_doton_pics_floor", net.ReadVector(), angle_zero)
end)
