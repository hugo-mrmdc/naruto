--========================================================
-- Senju : Coup de pied céleste (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_senju_pied.lua, qui décide de tout).
-- Les particules et la roche sont lancées par le serveur.
--========================================================

game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_pics_floor")

NA_Cast = NA_Cast or {}
NA_Cast.senju_pied = function()
    net.Start("senju_pied_cast")
    net.SendToServer()
end
