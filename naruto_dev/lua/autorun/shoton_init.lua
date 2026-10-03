-- Chargeur des techniques Shoton (cristal).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- solve_shoton_emeraude.pcf : toutes les couleurs vertes / rouges ont été passées en rose
game.AddParticles("particles/solve_shoton_emeraude.pcf")
PrecacheParticleSystem("wind_vortex_shoton_geams_rework_emeraude")
PrecacheParticleSystem("solve_explosion_pink_rubis")

if SERVER then
    resource.AddFile("particles/solve_shoton_emeraude.pcf")
    AddCSLuaFile("autorun/client/shoton/cl_shoton_cristal.lua")
    include("autorun/server/shoton/sv_shoton_cristal.lua")
end

if CLIENT then
    include("autorun/client/shoton/cl_shoton_cristal.lua")
end
