--========================================================
-- Fuma : Jugement des Quatre Lames (CLIENT)
-- Lancement depuis la barre de techniques (sv_fumajugement.lua).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.fuma_jugement = function()
    net.Start("fuma_jugement_cast")
    net.SendToServer()
end
