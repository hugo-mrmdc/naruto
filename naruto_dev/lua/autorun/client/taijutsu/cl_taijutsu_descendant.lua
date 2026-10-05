--========================================================
-- Taijutsu : Coup de pied descendant (CLIENT)
-- Lancement depuis la barre de techniques ; l'animation passe par
-- Jutsu_Anim_Play (jutsu_anim_cl.lua), tout le reste est côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.taijutsu_descendant = function()
    net.Start("taijutsu_descendant_cast")
    net.SendToServer()
end
