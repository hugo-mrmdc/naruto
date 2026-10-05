if SERVER then
    game.AddParticles("particles/orugi_atg_particle.pcf")
    PrecacheParticleSystem("[1]_katon_boule_feu_orugi")
    PrecacheParticleSystem("[1]_katon_boule_feu_orugi_big")
    AddCSLuaFile("autorun/client/katon/cl_bouledefeut.lua")
    include("autorun/server/katon/sv_bouledefeut.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_dome.lua")
    include("autorun/server/katon/sv_katon_dome.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_souffle.lua")
    include("autorun/server/katon/sv_katon_souffle.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_tornade.lua")
    include("autorun/server/katon/sv_katon_tornade.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_grosse_boule.lua")
    include("autorun/server/katon/sv_katon_grosse_boule.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_nuee.lua")
    include("autorun/server/katon/sv_katon_nuee.lua")
    AddCSLuaFile("autorun/client/katon/cl_katon_meteore.lua")
    include("autorun/server/katon/sv_katon_meteore.lua")
end

if CLIENT then
    include("autorun/client/katon/cl_bouledefeut.lua")
    include("autorun/client/katon/cl_katon_dome.lua")
    include("autorun/client/katon/cl_katon_souffle.lua")
    include("autorun/client/katon/cl_katon_tornade.lua")
    include("autorun/client/katon/cl_katon_grosse_boule.lua")
    include("autorun/client/katon/cl_katon_nuee.lua")
    include("autorun/client/katon/cl_katon_meteore.lua")
end
