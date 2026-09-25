if SERVER then

    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
    AddCSLuaFile("autorun/client/suiton/cl_suiton_shark.lua")
    include("autorun/server/suiton/sv_suiton_shark.lua")
    AddCSLuaFile("autorun/client/suiton/cl_suiton_prison.lua")
    include("autorun/server/suiton/sv_suiton_prison.lua")
end

if CLIENT then
    include("autorun/client/suiton/cl_suiton_shark.lua")
    include("autorun/client/suiton/cl_suiton_prison.lua")
end
