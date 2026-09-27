-- Chargeur des techniques Hyuga (Byakugan, Paume du Hakke).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("materials/ui/icon/hyuga_byakugan.png")
    resource.AddFile("materials/ui/icon/hyuga_128_poing_hakke.png")
    resource.AddFile("materials/ui/icon/hyuga_64_poing_hakke.png")
    resource.AddFile("sound/genjutsu/byakugan_deploy.wav")
    resource.AddFile("particles/patlick_atgparticules.pcf")

    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_byakugan.lua")
    include("autorun/server/hyuga/sv_hyuga_byakugan.lua")
    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_paume.lua")
    include("autorun/server/hyuga/sv_hyuga_paume.lua")
end

if CLIENT then
    include("autorun/client/hyuga/cl_hyuga_byakugan.lua")
    include("autorun/client/hyuga/cl_hyuga_paume.lua")
end
