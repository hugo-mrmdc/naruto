-- Chargeur des techniques Hyuga (Byakugan, Paume du Hakke, 32 Points du Hakke, Tourbillon Divin).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("materials/ui/icon/hyuga_byakugan.png")
    resource.AddFile("materials/ui/icon/hyuga_128_poing_hakke.png")
    resource.AddFile("materials/ui/icon/hyuga_64_poing_hakke.png")
    resource.AddFile("materials/ui/icon/hyuga_poing_chakra.png")
    resource.AddFile("materials/ui/icon/hyuga_tourbillion_divin_hakke.png")
    resource.AddFile("materials/hyuga/tenketsu_dot.png")
    resource.AddFile("sound/genjutsu/byakugan_deploy.wav")
    resource.AddFile("particles/patlick_atgparticules.pcf")

    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_byakugan.lua")
    include("autorun/server/hyuga/sv_hyuga_byakugan.lua")
    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_paume.lua")
    include("autorun/server/hyuga/sv_hyuga_paume.lua")
    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_32points.lua")
    include("autorun/server/hyuga/sv_hyuga_32points.lua")
    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_64points.lua")
    include("autorun/server/hyuga/sv_hyuga_64points.lua")
    AddCSLuaFile("autorun/client/hyuga/cl_hyuga_tourbillon.lua")
    include("autorun/server/hyuga/sv_hyuga_tourbillon.lua")
end

if CLIENT then
    include("autorun/client/hyuga/cl_hyuga_byakugan.lua")
    include("autorun/client/hyuga/cl_hyuga_paume.lua")
    include("autorun/client/hyuga/cl_hyuga_32points.lua")
    include("autorun/client/hyuga/cl_hyuga_64points.lua")
    include("autorun/client/hyuga/cl_hyuga_tourbillon.lua")
end
