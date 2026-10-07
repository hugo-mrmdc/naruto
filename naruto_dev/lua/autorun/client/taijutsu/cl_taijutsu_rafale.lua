--========================================================
-- Taijutsu : Rafale aérienne (CLIENT) - lancement depuis la barre de techniques
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.taijutsu_rafale = function()
    net.Start("taijutsu_rafale_cast")
    net.SendToServer()
end
