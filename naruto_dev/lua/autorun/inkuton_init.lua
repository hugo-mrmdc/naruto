-- Chargeur des techniques Inkuton (encre).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_chiens.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_editeur.lua")
    include("autorun/server/inkuton/sv_inkuton_chiens.lua")
end

if CLIENT then
    include("autorun/client/inkuton/cl_inkuton_chiens.lua")
    include("autorun/client/inkuton/cl_inkuton_editeur.lua")
end
