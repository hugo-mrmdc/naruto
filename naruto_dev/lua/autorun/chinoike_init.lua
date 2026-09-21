-- Chargeur des techniques Chinoike.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("particles/1atgyoltix.pcf")
    resource.AddFile("particles/atg_particules2.pcf")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("particles/ctg_chinoike_nael.pcf")
    resource.AddFile("materials/ui/icon/chinoike_zone_de_sang.png")
    resource.AddFile("materials/ui/icon/chinoike_ketsuryugan.png")
    resource.AddFile("sound/genjutsu/ketsuryugan_fort.wav")
    resource.AddFile("sound/genjutsu/ketsuryugan_fin.wav")

    AddCSLuaFile("autorun/client/chinoike/cl_chinoike_pluie.lua")
    AddCSLuaFile("autorun/client/chinoike/cl_chinoike_vortex.lua")
    include("autorun/server/chinoike/sv_chinoike_pluie.lua")
    include("autorun/server/chinoike/sv_chinoike_vortex.lua")
    AddCSLuaFile("autorun/client/chinoike/cl_chinoike_genjutsu.lua")
    include("autorun/server/chinoike/sv_chinoike_genjutsu.lua")
    AddCSLuaFile("autorun/client/chinoike/cl_chinoike_ketsuryugan.lua")
    include("autorun/server/chinoike/sv_chinoike_ketsuryugan.lua")
end

if CLIENT then
    include("autorun/client/chinoike/cl_chinoike_pluie.lua")
    include("autorun/client/chinoike/cl_chinoike_vortex.lua")
    include("autorun/client/chinoike/cl_chinoike_genjutsu.lua")
    include("autorun/client/chinoike/cl_chinoike_ketsuryugan.lua")
end
