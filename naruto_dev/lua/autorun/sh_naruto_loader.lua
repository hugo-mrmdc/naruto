-- lua/autorun/sh_naruto_loader.lua
AddCSLuaFile()
print("[NARUTO] TEST autorun OK", SERVER and "SV" or "CL")
game.AddParticles("particles/naruto_fw.pcf")
game.AddParticles("particles/atg_orugi_particle.pcf")
print(Material("tkr/particles/jump_smoke"):IsError())

if SERVER then
    util.AddNetworkString("naruto_reload_client")

    AddCSLuaFile("autorun/client/cl_main.lua")

    local function NarutoReloadServer()
        include("autorun/server/sv_main.lua")
        print("[NARUTO] Serveur reload OK")
    end

    concommand.Add("naruto_reload", function(ply)
        -- si tu veux limiter à admin :
        if IsValid(ply) and not ply:IsAdmin() then return end

        NarutoReloadServer()
        net.Start("naruto_reload_client")
        net.Broadcast()
    end)

    -- load initial
    NarutoReloadServer()
end

if CLIENT then
    local function NarutoReloadClient()
        include("autorun/client/cl_main.lua")
        print("[NARUTO] Client reload OK")
    end

    net.Receive("naruto_reload_client", function()
        NarutoReloadClient()
    end)

    -- load initial
    NarutoReloadClient()
end
