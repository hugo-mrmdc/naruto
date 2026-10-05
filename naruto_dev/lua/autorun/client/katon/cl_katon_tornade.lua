--========================================================
-- Tornade de feu (CLIENT)
--
-- Le client ne fait qu'envoyer l'appui : incantation, tornade, attraction,
-- dégâts et recharge sont décidés par le serveur (sv_katon_tornade.lua).
-- Le feu est affiché par l'entité katon_tornade (lua/entities).
--========================================================

game.AddParticles("particles/solve_new_katon.pcf")
PrecacheParticleSystem("solve_katon_tornado_floor")

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.katon_tornade = function()
    net.Start("katon_tornade")
    net.SendToServer()
end
