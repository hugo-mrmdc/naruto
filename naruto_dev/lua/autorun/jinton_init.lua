-- Chargeur des techniques Jinton.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Particules : chargées des deux côtés (sinon le serveur ne peut pas les lancer)
game.AddParticles("particles/solve_jinton_geams.pcf")
PrecacheParticleSystem("solve_geams_01_j")
game.AddParticles("particles/solve_jinton_02.pcf")
PrecacheParticleSystem("jinton_shield")
game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem("[7]_jinton_vortex_expl_add2")   -- bouclier Jinton
for _, nom in ipairs({ "[2]_red_large_main", "start_laser", "impact_world_geams", "hit_jinton" }) do
    PrecacheParticleSystem(nom)   -- rayon de dissolution (solve_jinton_geams.pcf)
end

if SERVER then
    resource.AddFile("particles/solve_jinton_geams.pcf")
    resource.AddFile("models/justu/jinton/cubeonoki2.mdl")
    resource.AddFile("sound/jutsu/jinton/damage_cube_start.wav")
    resource.AddFile("sound/jutsu/jinton/damage_cube_explosion.wav")
    resource.AddFile("materials/ui/icon/jinton_cube_confinement.png")
    resource.AddFile("particles/solve_jinton_02.pcf")
    resource.AddFile("particles/atg_farisv2.pcf")
    resource.AddFile("models/justu/jinton/sphereonoki.mdl")
    resource.AddFile("materials/ui/icon/jinton_bulle_poussiere.png")
    resource.AddFile("models/justu/jinton/cylindreonokisolve.mdl")
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
        resource.AddFile("models/justu/jinton/cubeonokisolve." .. ext)   -- petits cubes lancés
    end
    resource.AddFile("materials/ui/icon/jinton_rayon_dissolution.png")

    AddCSLuaFile("autorun/client/jinton/cl_jinton_cube.lua")
    include("autorun/server/jinton/sv_jinton_cube.lua")

    AddCSLuaFile("autorun/client/jinton/cl_jinton_bouclier.lua")
    include("autorun/server/jinton/sv_jinton_bouclier.lua")

    AddCSLuaFile("autorun/client/jinton/cl_jinton_cubes.lua")
    include("autorun/server/jinton/sv_jinton_cubes.lua")

    AddCSLuaFile("autorun/client/jinton/cl_jinton_cage.lua")
    include("autorun/server/jinton/sv_jinton_cage.lua")

    AddCSLuaFile("autorun/client/jinton/cl_jinton_laser.lua")
    include("autorun/server/jinton/sv_jinton_laser.lua")
end

if CLIENT then
    include("autorun/client/jinton/cl_jinton_cube.lua")
    include("autorun/client/jinton/cl_jinton_bouclier.lua")
    include("autorun/client/jinton/cl_jinton_cubes.lua")
    include("autorun/client/jinton/cl_jinton_cage.lua")
    include("autorun/client/jinton/cl_jinton_laser.lua")
end
