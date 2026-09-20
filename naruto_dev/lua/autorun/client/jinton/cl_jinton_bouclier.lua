--========================================================
-- Jinton : Bouclier (CLIENT)
-- Lancement depuis la barre de techniques. La sphère est l'entité jinton_bouclier.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_bouclier = function()
    net.Start("jinton_bouclier_cast")
    net.SendToServer()
end
