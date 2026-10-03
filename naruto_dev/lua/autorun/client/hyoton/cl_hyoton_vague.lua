--========================================================
-- Hyoton : Vague de glace (CLIENT)
-- Lancement depuis la barre de techniques (les pics sont créés par le serveur).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_vague = function()
    net.Start("hyoton_vague_cast")
    net.SendToServer()
end
