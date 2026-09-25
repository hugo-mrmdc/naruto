--========================================================
-- Futon : Tornade (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_futon_tornade.lua, qui décide de tout).
-- La tornade est affichée par l'entité futon_tornade (lua/entities).
--========================================================

-- particule de la tornade (solve_futon_tornado_move_s), créée par l'entité
game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_tornado_move_s")

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.futon_tornade = function()
    net.Start("futon_tornade_cast")
    net.SendToServer()
end
