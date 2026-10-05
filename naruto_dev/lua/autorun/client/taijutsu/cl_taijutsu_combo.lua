--========================================================
-- Taijutsu : Enchaînement aérien (CLIENT)
-- Lancement depuis la barre de techniques ; les animations passent par
-- Jutsu_Anim_Play (lanceur) et NA_EtourdiAnim (cible suspendue), tout le
-- reste est côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.taijutsu_combo = function()
    net.Start("taijutsu_combo_cast")
    net.SendToServer()
end
