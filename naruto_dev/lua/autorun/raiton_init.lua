-- Chargeur des techniques Raiton.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    AddCSLuaFile("autorun/client/raiton/cl_raiton_jugement.lua")
    include("autorun/server/raiton/sv_raiton_jugement.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_cercle.lua")
    include("autorun/server/raiton/sv_raiton_cercle.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_boule.lua")
    include("autorun/server/raiton/sv_raiton_boule.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_zone.lua")
    include("autorun/server/raiton/sv_raiton_zone.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_poing.lua")
    include("autorun/server/raiton/sv_raiton_poing.lua")
    AddCSLuaFile("autorun/client/raiton/cl_raiton_chidori.lua")
    include("autorun/server/raiton/sv_raiton_chidori.lua")   -- après le Poing : réutilise son message d'impact
end

if CLIENT then
    include("autorun/client/raiton/cl_raiton_jugement.lua")
    include("autorun/client/raiton/cl_raiton_cercle.lua")
    include("autorun/client/raiton/cl_raiton_boule.lua")
    include("autorun/client/raiton/cl_raiton_zone.lua")
    include("autorun/client/raiton/cl_raiton_poing.lua")
    include("autorun/client/raiton/cl_raiton_chidori.lua")
end
