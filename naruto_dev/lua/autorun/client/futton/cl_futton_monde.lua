--========================================================
-- Futton : Monde de vapeur (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité futton_monde).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.futton_monde = function()
    net.Start("futton_monde_cast")
    net.SendToServer()
end
