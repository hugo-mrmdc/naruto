--========================================================
-- Taijutsu : Coup de pied relevé (CLIENT)
-- Lancement depuis la barre de techniques ; tout le reste est côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.taijutsu_releve = function()
    net.Start("taijutsu_releve_cast")
    net.SendToServer()
end
