--========================================================
-- Jinton : Cage de cube (CLIENT)
-- Lancement depuis la barre de techniques. Le cube est l'entité jinton_cage.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_cage = function()
    net.Start("jinton_cage_cast")
    net.SendToServer()
end
