-- Chargeur des techniques de Kenjutsu (art du sabre).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("materials/ui/icon/kenjutsu_estoc_fulminant.png")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("particles/solve_kenjutsu_expert.pcf")
    AddCSLuaFile("autorun/client/kenjutsu/cl_kenjutsu_perforant.lua")
    AddCSLuaFile("autorun/client/kenjutsu/cl_kenjutsu_tourbillon.lua")
    AddCSLuaFile("autorun/client/kenjutsu/cl_kenjutsu_triple.lua")
    AddCSLuaFile("autorun/client/kenjutsu/cl_kenjutsu_allerretour.lua")
    AddCSLuaFile("autorun/client/kenjutsu/cl_kenjutsu_tornade.lua")
    resource.AddFile("materials/ui/icon/kenjutsu_kesa_giri.png")
    resource.AddFile("materials/ui/icon/kenjutsu_coupe_eclair.png")
    resource.AddFile("materials/ui/icon/kenjutsu_tourbillon_fendeur.png")
    resource.AddFile("materials/ui/icon/kenjutsu_barrage_rasant.png")
    resource.AddFile("particles/julio.pcf")
    include("autorun/server/kenjutsu/sv_kenjutsu_perforant.lua")
    include("autorun/server/kenjutsu/sv_kenjutsu_tourbillon.lua")
    include("autorun/server/kenjutsu/sv_kenjutsu_triple.lua")
    include("autorun/server/kenjutsu/sv_kenjutsu_allerretour.lua")
    include("autorun/server/kenjutsu/sv_kenjutsu_tornade.lua")
end

if CLIENT then
    include("autorun/client/kenjutsu/cl_kenjutsu_perforant.lua")
    include("autorun/client/kenjutsu/cl_kenjutsu_tourbillon.lua")
    include("autorun/client/kenjutsu/cl_kenjutsu_triple.lua")
    include("autorun/client/kenjutsu/cl_kenjutsu_allerretour.lua")
    include("autorun/client/kenjutsu/cl_kenjutsu_tornade.lua")
end
