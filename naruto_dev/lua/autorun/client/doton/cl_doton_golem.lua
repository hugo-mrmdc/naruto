--========================================================
-- Doton : Golem de roche (CLIENT)
-- Envoie seulement l'appui au serveur (server/doton/sv_doton_golem.lua, qui décide de tout ; rappuyer détruit le golem).
-- Les animations, la boîte de collision et le clic d'attaque sont dans autorun/mokuton/mokuton_golem_sh.lua (type "doton").
--========================================================

util.PrecacheModel("models/nature/doton/lv_golem_dot.mdl")

NA_Cast = NA_Cast or {}
NA_Cast.doton_golem = function()
    net.Start("doton_golem_cast")
    net.SendToServer()
end
