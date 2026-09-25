--========================================================
-- Futon : Wind Ball (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_futon_windball.lua, qui décide de tout).
-- La boule est affichée par l'entité futon_windball (lua/entities).
--========================================================

-- particule d'impact (solve_futon_bump_01), jouée par l'entité à l'impact
game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_bump_01")

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.futon_windball = function()
    net.Start("futon_windball_cast")
    net.SendToServer()
end
