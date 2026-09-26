--========================================================
-- Mokuton : Golem de bois (CLIENT)
--
-- Envoie seulement l'appui au serveur (server/mokuton/mokuton_golem_sv.lua, qui décide de tout ; rappuyer
-- redonne l'apparence normale). Les animations sont dans autorun/mokuton/mokuton_golem_sh.lua.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.mokuton_golem = function()
    net.Start("mokuton_golem_cast")
    net.SendToServer()
end
