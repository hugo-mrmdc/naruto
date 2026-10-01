--========================================================
-- Bakuton : Oiseaux explosifs (CLIENT) : active / désactive le mode depuis la barre de techniques.
-- Les oiseaux eux-mêmes sont l'entité bakuton_oiseau.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_oiseaux = function()
    net.Start("bakuton_oiseaux_cast")
    net.SendToServer()
end
