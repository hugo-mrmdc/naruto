--========================================================
-- Futon : Grand ouragan (CLIENT)
-- Lancement depuis la barre de techniques ; l'ouragan et sa particule sont affichés par l'entité futon_grand_ouragan.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.futon_grand_ouragan = function()
    net.Start("futon_grand_ouragan_cast")
    net.SendToServer()
end
