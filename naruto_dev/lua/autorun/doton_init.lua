-- Chargeur des techniques Doton.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    AddCSLuaFile("autorun/client/doton/cl_doton_pierre.lua")
    include("autorun/server/doton/sv_doton_pierre.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_seisme.lua")
    include("autorun/server/doton/sv_doton_seisme.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_taupe.lua")
    include("autorun/server/doton/sv_doton_taupe.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_pics.lua")
    include("autorun/server/doton/sv_doton_pics.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_eruption.lua")
    include("autorun/server/doton/sv_doton_eruption.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_dragon.lua")
    include("autorun/server/doton/sv_doton_dragon.lua")
    AddCSLuaFile("autorun/client/doton/cl_doton_golem.lua")
    include("autorun/server/doton/sv_doton_golem.lua")
end

if CLIENT then
    include("autorun/client/doton/cl_doton_pierre.lua")
    include("autorun/client/doton/cl_doton_seisme.lua")
    include("autorun/client/doton/cl_doton_taupe.lua")
    include("autorun/client/doton/cl_doton_pics.lua")
    include("autorun/client/doton/cl_doton_eruption.lua")
    include("autorun/client/doton/cl_doton_dragon.lua")
    include("autorun/client/doton/cl_doton_golem.lua")
end

-- Voyage souterrain : pas de saut (retiré des DEUX côtés pour que le client le prédise aussi)
hook.Add("StartCommand", "DotonTaupe_PasDeSaut", function(ply, cmd)
    if ply:GetNW2Bool("NA_Souterrain", false) then cmd:RemoveKey(IN_JUMP) end
end)
