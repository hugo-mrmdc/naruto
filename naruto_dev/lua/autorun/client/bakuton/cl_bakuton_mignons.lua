--========================================================
-- Bakuton : Mignons d'argile (CLIENT) : lancement depuis la barre de techniques.
-- Les mignons eux-mêmes sont l'entité bakuton_mignon.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_mignons = function()
    net.Start("bakuton_mignons_cast")
    net.SendToServer()
end
