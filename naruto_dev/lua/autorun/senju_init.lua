-- Chargeur des techniques Senju.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("particles/slyzz_particles.pcf")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("materials/ui/icon/senju_renfo.png")
    resource.AddFile("materials/ui/icon/senju_soin.png")

    AddCSLuaFile("autorun/client/senju/cl_senju_renfo.lua")
    include("autorun/server/senju/sv_senju_renfo.lua")

    AddCSLuaFile("autorun/client/senju/cl_senju_soin.lua")
    include("autorun/server/senju/sv_senju_soin.lua")
end

if CLIENT then
    include("autorun/client/senju/cl_senju_renfo.lua")
    include("autorun/client/senju/cl_senju_soin.lua")
end
