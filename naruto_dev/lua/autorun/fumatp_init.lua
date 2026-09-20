-- fumée de l'impact du Shuriken Céleste
game.AddParticles("particles/bigfumee.pcf")
PrecacheParticleSystem("big_smoke_base")

-- fumée des shurikens du Jugement des Quatre Lames et de la téléportation
-- (chargée des deux côtés pour être vue par tout le monde)
game.AddParticles("particles/atg_orugi_particle.pcf")
PrecacheParticleSystem("smoke_orugi2")

-- fumée de l'invisibilité (chargée des deux côtés pour être vue par tout le monde)
game.AddParticles("particles/solve_ayatsuri_geams.pcf")
PrecacheParticleSystem("solve_smoke_ayatsuri_geams")

if SERVER then
    resource.AddFile("particles/solve_ayatsuri_geams.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")
    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
    PrecacheParticleSystem("smoke_orugi2")
    PrecacheParticleSystem("hit_2_arche")
    PrecacheParticleSystem("mokuton_flower")
    AddCSLuaFile("autorun/client/fumaSpell/cl_fumatp.lua")
    include("autorun/server/fumaSpell/sv_fumatp.lua")
    AddCSLuaFile("autorun/client/fumaSpell/cl_fumainvi.lua")
    include("autorun/server/fumaSpell/sv_fumainv.lua")
    AddCSLuaFile("autorun/client/fumaSpell/cl_fumajugement.lua")
    include("autorun/server/fumaSpell/sv_fumajugement.lua")
    AddCSLuaFile("autorun/client/fumaSpell/cl_fumaaura.lua")
    include("autorun/server/fumaSpell/sv_fumaaura.lua")
    resource.AddFile("materials/ui/icon/fuma_morsure_sanglante.png")
    resource.AddFile("particles/fuma.pcf")
    resource.AddFile("particles/bigfumee.pcf")
    -- textures de la fumée, absentes des addons : ajoutées dans cet addon
    resource.AddFile("materials/izox/smoke.vmt")
    resource.AddFile("materials/izox/smoke.vtf")
    resource.AddFile("materials/bloom1.vmt")
    resource.AddFile("materials/ui/icon/fuma_shuriken_acier.png")

    AddCSLuaFile("autorun/client/fumaSpell/cl_fumaciel.lua")
    include("autorun/server/fumaSpell/sv_fumaciel.lua")
    resource.AddFile("materials/ui/icon/fuma_jugement_shuriken.png")
end

if CLIENT then
    include("autorun/client/fumaSpell/cl_fumatp.lua")
    include("autorun/client/fumaSpell/cl_fumainvi.lua")
    include("autorun/client/fumaSpell/cl_fumajugement.lua")
    include("autorun/client/fumaSpell/cl_fumaaura.lua")
    include("autorun/client/fumaSpell/cl_fumaciel.lua")
end
