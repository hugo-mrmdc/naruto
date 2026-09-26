--========================================================
-- Doton : Boule de roche (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_doton_pierre.lua, qui décide de tout).
-- La boule est affichée par l'entité doton_pierre (lua/entities).
--========================================================

game.AddParticles("particles/atg_particules3.pcf")
PrecacheParticleSystem("atg_boule_roche_explo")

NA_Cast = NA_Cast or {}
NA_Cast.doton_pierre = function()
    net.Start("doton_pierre_cast")
    net.SendToServer()
end
