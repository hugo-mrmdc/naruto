--========================================================
-- Suiton : Océan (CLIENT)
-- Lancement depuis la barre de techniques ; la zone, son modèle (lv_zone_eau) et sa particule ([23]_suiton_ocean) sont
-- affichés par l'entité suiton_ocean.
--========================================================

util.PrecacheModel("models/nature/suiton/lv_zone_eau.mdl")

NA_Cast = NA_Cast or {}
NA_Cast.suiton_ocean = function()
    net.Start("suiton_ocean_cast")
    net.SendToServer()
end
