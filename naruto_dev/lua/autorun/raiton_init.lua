-- Chargeur des techniques Raiton.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    AddCSLuaFile("autorun/client/raiton/cl_raiton_jugement.lua")
    include("autorun/server/raiton/sv_raiton_jugement.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_cercle.lua")
    include("autorun/server/raiton/sv_raiton_cercle.lua")
end

if CLIENT then
    include("autorun/client/raiton/cl_raiton_jugement.lua")
    include("autorun/client/raiton/cl_raiton_cercle.lua")
end
