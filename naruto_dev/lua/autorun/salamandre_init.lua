if SERVER then
    -- crachat du projectile poison
    game.AddParticles("particles/godio_salamandre.pcf")
    PrecacheParticleSystem("godio_crachat_sala")
    PrecacheParticleSystem("godio_impact_sala")
    PrecacheParticleSystem("godio_fumee_sala")   -- dôme de brume
    PrecacheParticleSystem("godio_aura_sala")    -- corps de poison
    PrecacheParticleSystem("godio_petite_zone_sala") -- typhon de poison

    AddCSLuaFile("autorun/client/salamandre/cl_dome_salamandre.lua")
    AddCSLuaFile("autorun/client/salamandre/cl_tornadopoison.lua")
    AddCSLuaFile("autorun/client/salamandre/cl_poison_projectile.lua")
    include("autorun/server/salamandre/sv_poison_projectile.lua")
    include("autorun/server/salamandre/sv_tornadopoison.lua")

    include("autorun/server/salamandre/sv_dome_salamandre.lua")
    include("autorun/server/salamandre/sv_salamandre.lua")

    AddCSLuaFile("autorun/client/salamandre/cl_corps_poison.lua")
    include("autorun/server/salamandre/sv_corps_poison.lua")
end

if CLIENT then
    -- le client doit connaître le .pcf pour afficher le crachat et son impact
    game.AddParticles("particles/godio_salamandre.pcf")
    PrecacheParticleSystem("godio_crachat_sala")
    PrecacheParticleSystem("godio_impact_sala")
    PrecacheParticleSystem("godio_fumee_sala")   -- dôme de brume
    PrecacheParticleSystem("godio_aura_sala")    -- corps de poison
    PrecacheParticleSystem("godio_petite_zone_sala") -- typhon de poison
    include("autorun/client/salamandre/cl_tornadopoison.lua")
    include("autorun/client/salamandre/cl_poison_projectile.lua")
    include("autorun/client/salamandre/cl_dome_salamandre.lua")
    include("autorun/client/salamandre/cl_corps_poison.lua")
end
