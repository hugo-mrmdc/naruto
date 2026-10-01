--========================================================
-- Bakuton : Araignées explosives (CLIENT) : lancement depuis la barre de techniques.
-- Les araignées elles-mêmes sont l'entité bakuton_araignee.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_araignees = function()
    net.Start("bakuton_araignees_cast")
    net.SendToServer()
end
