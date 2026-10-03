--========================================================
-- Futton : Tornade de vapeur (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité futton_tornade).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.futton_tornade = function()
    net.Start("futton_tornade_cast")
    net.SendToServer()
end
