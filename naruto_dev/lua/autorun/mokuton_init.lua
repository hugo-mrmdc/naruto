-- Chargeur des techniques Mokuton (arche, fleur, protection de bois, mains de bois, dragon, golem).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.
-- Fichiers : autorun/server/mokuton/, autorun/client/mokuton/, autorun/mokuton/ (partagés).
-- (les entités mokuton_hobi restent dans lua/entities : GMod ne les charge que de là)

-- partagés : chargés des deux côtés
if SERVER then AddCSLuaFile("autorun/mokuton/mokuton_fly.lua") end
include("autorun/mokuton/mokuton_fly.lua")
if SERVER then AddCSLuaFile("autorun/mokuton/sh_mokuton_protection.lua") end
include("autorun/mokuton/sh_mokuton_protection.lua")
if SERVER then AddCSLuaFile("autorun/mokuton/mokuton_golem_sh.lua") end
include("autorun/mokuton/mokuton_golem_sh.lua")

if SERVER then
    AddCSLuaFile("autorun/client/mokuton/mokuton_arche_cl.lua")
    include("autorun/server/mokuton/mokuton_arche_sv.lua")
    AddCSLuaFile("autorun/client/mokuton/mokuton_fleur_cl.lua")
    include("autorun/server/mokuton/mokuton_fleur_sv.lua")
    AddCSLuaFile("autorun/client/mokuton/mokuton_protection_cl.lua")
    include("autorun/server/mokuton/mokuton_protection_sv.lua")
    AddCSLuaFile("autorun/client/mokuton/mokuton_wood_hand_cl.lua")
    include("autorun/server/mokuton/mokuton_wood_hand_sv.lua")
    AddCSLuaFile("autorun/client/mokuton/mokuton_dragon_cl.lua")
    include("autorun/server/mokuton/mokuton_dragon_sv.lua")
    AddCSLuaFile("autorun/client/mokuton/mokuton_golem_cl.lua")
    include("autorun/server/mokuton/mokuton_golem_sv.lua")
end

if CLIENT then
    include("autorun/client/mokuton/mokuton_arche_cl.lua")
    include("autorun/client/mokuton/mokuton_fleur_cl.lua")
    include("autorun/client/mokuton/mokuton_protection_cl.lua")
    include("autorun/client/mokuton/mokuton_wood_hand_cl.lua")
    include("autorun/client/mokuton/mokuton_dragon_cl.lua")
    include("autorun/client/mokuton/mokuton_golem_cl.lua")
end
