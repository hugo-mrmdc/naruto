--========================================================
-- Inkuton : Serpents d'encre (CLIENT) : lancement depuis la barre de techniques.
-- Le serpent lui-même est l'entité inkuton_serpent.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.inkuton_serpents = function()
    net.Start("inkuton_serpents_cast")
    net.SendToServer()
end
