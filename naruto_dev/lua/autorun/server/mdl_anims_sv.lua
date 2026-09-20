-- Active l'exécution Lua client sur serveur local (utile pour tes tests)
-- (Si un addon le force à 0, ça peut être écrasé, mais sur un serveur local ça marche souvent.)
hook.Add("Initialize", "MDL_Anims_EnableCSLua", function()
    RunConsoleCommand("sv_allowcslua", "1")
end)

-- Envoie le script client
AddCSLuaFile("autorun/client/mdl_anims_cl.lua")
