--========================================================
-- Futon : Wind Slash (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_futon_windslash.lua, qui décide de
-- tout). La lame est affichée par l'entité futon_windslash (lua/entities).
--========================================================

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.futon_windslash = function()
    net.Start("futon_windslash_cast")
    net.SendToServer()
end
