--========================================================
-- Dôme de feu (CLIENT)
--
-- Le client ne fait qu'envoyer l'appui : incantation, zone, dégâts et
-- recharge sont décidés par le serveur (sv_katon_dome.lua).
-- Le feu est affiché par l'entité katon_zone (lua/entities).
--========================================================

game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem("fire_dome_charge")

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.katon_dome = function()
    net.Start("katon_dome")
    net.SendToServer()
end
