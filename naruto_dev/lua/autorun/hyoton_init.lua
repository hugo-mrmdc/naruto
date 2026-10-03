-- Chargeur des techniques Hyoton (glace).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

game.AddParticles("particles/solve_hyoton_geams_give.pcf")
PrecacheParticleSystem("[9]_snowarea")
game.AddParticles("particles/solve_ice.pcf")
for _, nom in ipairs({ "[4]_ice_judgmentcut", "[4]_ice_judgmentcut_sphere_main", "[4]_ice_judgmentcut_sphere_rework", "[4]_ice_slide_testt" }) do
    PrecacheParticleSystem(nom)
end

if SERVER then
    resource.AddFile("particles/solve_hyoton_geams_give.pcf")
    resource.AddFile("particles/solve_ice.pcf")
    AddCSLuaFile("autorun/client/hyoton/cl_hyoton_dome.lua")
    AddCSLuaFile("autorun/client/hyoton/cl_hyoton_loup.lua")
    AddCSLuaFile("autorun/client/hyoton/cl_hyoton_prison.lua")
    AddCSLuaFile("autorun/client/hyoton/cl_hyoton_pics.lua")
    AddCSLuaFile("autorun/client/hyoton/cl_hyoton_vague.lua")
    include("autorun/server/hyoton/sv_hyoton_dome.lua")
    include("autorun/server/hyoton/sv_hyoton_loup.lua")
    include("autorun/server/hyoton/sv_hyoton_prison.lua")
    include("autorun/server/hyoton/sv_hyoton_pics.lua")
    include("autorun/server/hyoton/sv_hyoton_vague.lua")
end

if CLIENT then
    include("autorun/client/hyoton/cl_hyoton_dome.lua")
    include("autorun/client/hyoton/cl_hyoton_loup.lua")
    include("autorun/client/hyoton/cl_hyoton_prison.lua")
    include("autorun/client/hyoton/cl_hyoton_pics.lua")
    include("autorun/client/hyoton/cl_hyoton_vague.lua")
end
