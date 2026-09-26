--========================================================
-- Doton : Séisme (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_doton_seisme.lua, qui décide de tout).
-- La particule est créée par l'entité doton_seisme (lua/entities).
--========================================================

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("doton_seisme_pat")

NA_Cast = NA_Cast or {}
NA_Cast.doton_seisme = function()
    net.Start("doton_seisme_cast")
    net.SendToServer()
end
