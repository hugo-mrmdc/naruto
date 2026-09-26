--========================================================
-- Mokuton : Mains de bois (CLIENT)
--
-- Envoie seulement l'appui au serveur (server/mokuton/mokuton_wood_hand_sv.lua, qui décide de tout).
-- Les mains sont affichées par l'entité mokuton_wood_hand (lua/entities).
--========================================================

game.AddParticles("particles/solve_doton.pcf")   -- solve_doton_spike_spawn_add1 : jouée par les mains
PrecacheParticleSystem("solve_doton_spike_spawn_add1")

NA_Cast = NA_Cast or {}
NA_Cast.mokuton_wood_hand = function()
    net.Start("mokuton_wood_hand_cast")
    net.SendToServer()
end
