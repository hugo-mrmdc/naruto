--========================================================
-- Hyoton : Dôme de glace (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité hyoton_dome).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_dome = function()
    net.Start("hyoton_dome_cast")
    net.SendToServer()
end
