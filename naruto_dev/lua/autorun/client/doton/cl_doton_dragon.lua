--========================================================
-- Doton : Dragon de terre (CLIENT)
-- Lancement depuis la barre de techniques. Le dragon et ses projectiles sont affichés par les entités doton_dragon et
-- doton_dragon_balle (lua/entities) ; les modèles sont préchargés ici, au démarrage (pas de micro freeze au premier dragon).
--========================================================

util.PrecacheModel("models/nature/doton/doton_dragon_01.mdl")
util.PrecacheModel("models/nature/doton/doton_bullet_01.mdl")

NA_Cast = NA_Cast or {}
NA_Cast.doton_dragon = function()
    net.Start("doton_dragon_cast")
    net.SendToServer()
end
