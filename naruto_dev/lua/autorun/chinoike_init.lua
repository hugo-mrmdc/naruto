-- Chargeur des techniques Chinoike.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("particles/1atgyoltix.pcf")
    resource.AddFile("materials/ui/icon/chinoike_zone_de_sang.png")

    AddCSLuaFile("autorun/client/chinoike/cl_chinoike_pluie.lua")
    include("autorun/server/chinoike/sv_chinoike_pluie.lua")
end

if CLIENT then
    include("autorun/client/chinoike/cl_chinoike_pluie.lua")
end
