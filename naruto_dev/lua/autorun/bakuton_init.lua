-- Chargeur des techniques Bakuton (explosion).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_oiseaux.lua")
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_mignons.lua")
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_araignees.lua")
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_meute.lua")
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_dragon.lua")
    AddCSLuaFile("autorun/client/bakuton/cl_bakuton_bombe.lua")
    include("autorun/server/bakuton/sv_bakuton_oiseaux.lua")
    include("autorun/server/bakuton/sv_bakuton_mignons.lua")     -- mignons et araignées réutilisent la visée des singes
    include("autorun/server/bakuton/sv_bakuton_araignees.lua")   -- (inkuton, appelée à l'exécution)
    include("autorun/server/bakuton/sv_bakuton_meute.lua")
    include("autorun/server/bakuton/sv_bakuton_dragon.lua")
    include("autorun/server/bakuton/sv_bakuton_bombe.lua")
end

if CLIENT then
    include("autorun/client/bakuton/cl_bakuton_oiseaux.lua")
    include("autorun/client/bakuton/cl_bakuton_mignons.lua")
    include("autorun/client/bakuton/cl_bakuton_araignees.lua")
    include("autorun/client/bakuton/cl_bakuton_meute.lua")
    include("autorun/client/bakuton/cl_bakuton_dragon.lua")
    include("autorun/client/bakuton/cl_bakuton_bombe.lua")
end
