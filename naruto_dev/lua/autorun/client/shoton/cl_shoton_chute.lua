--========================================================
-- Shoton : Chute de cristal (CLIENT) : lancement depuis la barre de techniques
-- (le cristal est l'entité shoton_chute ; l'impact joue les particules de cl_shoton_rockets.lua)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.shoton_chute = function()
    net.Start("shoton_chute_cast")
    net.SendToServer()
end
