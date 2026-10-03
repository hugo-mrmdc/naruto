--========================================================
-- Futton : Projectile de vapeur (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité futton_projectile).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.futton_projectile = function()
    net.Start("futton_projectile_cast")
    net.SendToServer()
end
