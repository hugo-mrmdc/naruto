-- Chargeur des techniques Kaguya.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("models/clan/ame/kaguya/kim_armor.mdl")
    resource.AddFile("materials/ui/icon/kaguya_armure_os.png")

    resource.AddFile("particles/atg_farisv2.pcf")
    resource.AddFile("materials/ui/icon/kaguya_legion_os.png")

    AddCSLuaFile("autorun/client/kaguya/cl_kaguya_armure.lua")
    include("autorun/server/kaguya/sv_kaguya_armure.lua")

    AddCSLuaFile("autorun/client/kaguya/cl_kaguya_legion.lua")
    include("autorun/server/kaguya/sv_kaguya_legion.lua")

    resource.AddFile("materials/ui/icon/kaguya_danse_des_os.png")
    resource.AddFile("particles/1izoxsolvenr.pcf")
    AddCSLuaFile("autorun/client/kaguya/cl_kaguya_danse.lua")
    include("autorun/server/kaguya/sv_kaguya_danse.lua")
end

if CLIENT then
    include("autorun/client/kaguya/cl_kaguya_armure.lua")
    include("autorun/client/kaguya/cl_kaguya_legion.lua")
    include("autorun/client/kaguya/cl_kaguya_danse.lua")
end
