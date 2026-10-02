--========================================================
-- Bakuton : Meute d'araignées (CLIENT) : lancement depuis la barre de techniques.
-- Les araignées elles-mêmes sont l'entité bakuton_araignee_meute.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_meute = function()
    net.Start("bakuton_meute_cast")
    net.SendToServer()
end
