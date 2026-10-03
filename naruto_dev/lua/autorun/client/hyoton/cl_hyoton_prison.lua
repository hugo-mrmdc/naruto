--========================================================
-- Hyoton : Prison de glace (CLIENT)
-- Lancement depuis la barre de techniques (l'arène et la particule sont gérées par l'entité hyoton_prison).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_prison = function()
    net.Start("hyoton_prison_cast")
    net.SendToServer()
end
