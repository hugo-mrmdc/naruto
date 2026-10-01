-- Inkuton : Moine d'encre (CLIENT) : lancement depuis la barre de techniques.
NA_Cast = NA_Cast or {}
NA_Cast.inkuton_moine = function()
    net.Start("inkuton_moine_cast")
    net.SendToServer()
end
