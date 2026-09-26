--========================================================
-- Mokuton : Protection de bois (CLIENT)
--
-- Envoie seulement l'appui au serveur (mokuton_protection_sv.lua, qui décide de tout).
-- Le cocon est affiché par l'entité mokuton_hobi (lua/entities).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.mokuton_protection = function()
    net.Start("mokuton_protection_cast")
    net.SendToServer()
end
