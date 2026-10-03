--========================================================
-- Futton : Cage de vapeur (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité futton_cage).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.futton_cage = function()
    net.Start("futton_cage_cast")
    net.SendToServer()
end
