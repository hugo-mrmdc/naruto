-- Chargeur des techniques Senju.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("particles/slyzz_particles.pcf")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("materials/ui/icon/senju_renfo.png")
    resource.AddFile("materials/ui/icon/senju_soin.png")
    resource.AddFile("materials/ui/icon/senju_frappe_terrestre.png")
    resource.AddFile("materials/ui/icon/senju_choc_sismique.png")
    resource.AddFile("materials/ui/icon/senju_ermite_naturel.png")

    AddCSLuaFile("autorun/client/senju/cl_senju_renfo.lua")
    include("autorun/server/senju/sv_senju_renfo.lua")

    AddCSLuaFile("autorun/client/senju/cl_senju_soin.lua")
    include("autorun/server/senju/sv_senju_soin.lua")

    AddCSLuaFile("autorun/client/senju/cl_senju_frappe.lua")
    include("autorun/server/senju/sv_senju_frappe.lua")

    AddCSLuaFile("autorun/client/senju/cl_senju_pied.lua")
    include("autorun/server/senju/sv_senju_pied.lua")

    AddCSLuaFile("autorun/client/senju/cl_senju_ermite.lua")
    include("autorun/server/senju/sv_senju_ermite.lua")
end

if CLIENT then
    include("autorun/client/senju/cl_senju_renfo.lua")
    include("autorun/client/senju/cl_senju_soin.lua")
    include("autorun/client/senju/cl_senju_frappe.lua")
    include("autorun/client/senju/cl_senju_pied.lua")
    include("autorun/client/senju/cl_senju_ermite.lua")
end
