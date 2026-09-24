-- Chargeur du Kami Circle.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Déplacement des ailes : partagé (serveur + client) pour la prédiction du vol
if SERVER then AddCSLuaFile("kami/sh_kami_wings_move.lua") end
include("kami/sh_kami_wings_move.lua")

if SERVER then
    game.AddParticles("particles/atg_faris.pcf")
    PrecacheParticleSystem("[2]_paper_tornado")
    PrecacheParticleSystem("[2]_paper_shield")
    PrecacheParticleSystem("[2]_paper_shuriken")
    PrecacheParticleSystem("[2]_paper_impact")

    AddCSLuaFile("autorun/client/kami/cl_kami_circle.lua")
    include("autorun/server/kami/sv_kami_circle.lua")

    AddCSLuaFile("autorun/client/kami/cl_kami_wings.lua")
    include("autorun/server/kami/sv_kami_wings.lua")

    AddCSLuaFile("autorun/client/kami/cl_kami_shield.lua")
    include("autorun/server/kami/sv_kami_shield.lua")

    AddCSLuaFile("autorun/client/kami/cl_kami_shuriken.lua")
    include("autorun/server/kami/sv_kami_shuriken.lua")

    AddCSLuaFile("autorun/client/kami/cl_kami_roue.lua")
    include("autorun/server/kami/sv_kami_roue.lua")
end

if CLIENT then
    include("autorun/client/kami/cl_kami_circle.lua")
    include("autorun/client/kami/cl_kami_wings.lua")
    include("autorun/client/kami/cl_kami_shield.lua")
    include("autorun/client/kami/cl_kami_shuriken.lua")
    include("autorun/client/kami/cl_kami_roue.lua")
end
