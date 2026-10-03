--========================================================
-- Hyoton : Loups de glace (CLIENT) : lancement depuis la barre de techniques.
-- Le loup lui-même est l'entité hyoton_loup.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_loup = function()
    net.Start("hyoton_loup_cast")
    net.SendToServer()
end
