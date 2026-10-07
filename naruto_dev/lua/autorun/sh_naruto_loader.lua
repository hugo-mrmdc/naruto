-- lua/autorun/sh_naruto_loader.lua
AddCSLuaFile()
print("[NARUTO] TEST autorun OK", SERVER and "SV" or "CL")
game.AddParticles("particles/naruto_fw.pcf")
game.AddParticles("particles/atg_orugi_particle.pcf")
print(Material("tkr/particles/jump_smoke"):IsError())

--========================================================
-- naruto_reload : recharge TOUT l'addon sans relancer la map
--
--   * autorun/*.lua          (partagés)  : exécutés côté serveur ET côté client
--   * autorun/server/*.lua   (serveur)
--   * autorun/client/*.lua   (client)
-- Ces fichiers rechargent à leur tour les sous-dossiers (jinton, taijutsu...) via leurs *_init.lua.
-- Les entités (lua/entities) et armes (lua/weapons) se rechargent d'elles-mêmes quand leur fichier change.
--
-- Usage : naruto_reload (console, admin). Les erreurs de chaque fichier s'affichent sans bloquer les autres.
--========================================================
local SELF = "sh_naruto_loader.lua"

-- Exécute un fichier sans que son erreur arrête le rechargement des autres
local function Charger(chemin)
    local ok, err = pcall(include, chemin)
    if not ok then MsgC(Color(255, 90, 90), "[NARUTO] Erreur dans " .. chemin .. " : " .. tostring(err) .. "\n") end
    return ok
end

local function Lister(dossier)
    local liste = {}
    for _, f in ipairs((file.Find(dossier .. "/*.lua", "LUA"))) do
        if f ~= SELF then liste[#liste + 1] = dossier .. "/" .. f end
    end
    return liste
end

if SERVER then
    util.AddNetworkString("naruto_reload_client")

    AddCSLuaFile("autorun/client/cl_main.lua")

    local function ToutRecharger()
        local partages = Lister("autorun")
        local serveur  = Lister("autorun/server")
        local client   = Lister("autorun/client")

        -- sv_main en premier : il retire les hooks / timers de l'ancienne version (TONADDON:Shutdown)
        local ok, total = 0, 0
        local function Fichier(chemin)
            total = total + 1
            if Charger(chemin) then ok = ok + 1 end
        end

        Fichier("autorun/server/sv_main.lua")
        for _, f in ipairs(partages) do AddCSLuaFile(f) Fichier(f) end
        for _, f in ipairs(serveur) do
            if f ~= "autorun/server/sv_main.lua" then Fichier(f) end
        end
        for _, f in ipairs(client) do AddCSLuaFile(f) end   -- envoyés aux clients, exécutés chez eux

        print(string.format("[NARUTO] Serveur reload : %d / %d fichiers OK", ok, total))

        -- les clients exécutent les mêmes fichiers partagés + leurs fichiers client
        local pour_client = { "autorun/client/cl_main.lua" }
        for _, f in ipairs(partages) do pour_client[#pour_client + 1] = f end
        for _, f in ipairs(client) do
            if f ~= "autorun/client/cl_main.lua" then pour_client[#pour_client + 1] = f end
        end
        net.Start("naruto_reload_client")
            net.WriteUInt(#pour_client, 16)
            for _, f in ipairs(pour_client) do net.WriteString(f) end
        net.Broadcast()
    end

    concommand.Add("naruto_reload", function(ply)
        -- si tu veux limiter à admin :
        if IsValid(ply) and not ply:IsAdmin() then return end
        ToutRecharger()
    end)

    -- load initial (sv_main seulement : le reste est chargé par GMod au démarrage)
    Charger("autorun/server/sv_main.lua")
    print("[NARUTO] Serveur reload OK")
end

if CLIENT then
    net.Receive("naruto_reload_client", function()
        local ok, total = 0, 0
        for _ = 1, net.ReadUInt(16) do
            total = total + 1
            if Charger(net.ReadString()) then ok = ok + 1 end
        end
        print(string.format("[NARUTO] Client reload : %d / %d fichiers OK", ok, total))
    end)

    -- load initial
    Charger("autorun/client/cl_main.lua")
    print("[NARUTO] Client reload OK")
end
