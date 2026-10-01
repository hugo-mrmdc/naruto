--========================================================
-- Inkuton : Dieux d'encre (CLIENT) : lancement depuis la barre de techniques.
-- Les dieux eux-mêmes sont l'entité inkuton_dieu.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.inkuton_dieux = function()
    net.Start("inkuton_dieux_cast")
    net.SendToServer()
end
