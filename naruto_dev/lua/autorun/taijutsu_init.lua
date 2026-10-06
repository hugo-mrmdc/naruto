-- Chargeur des techniques de Taijutsu (Arts Ninja).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("materials/ui/icon/taijutsu_pied_ardent.png")
    resource.AddFile("materials/ui/icon/taijutsu_fureur_dragon.png")
    resource.AddFile("materials/ui/icon/taijutsu_tornade_jade.png")

    AddCSLuaFile("autorun/client/taijutsu/cl_taijutsu_hitfx.lua")
    AddCSLuaFile("autorun/client/taijutsu/cl_taijutsu_pied.lua")
    include("autorun/server/taijutsu/sv_taijutsu_pied.lua")
    AddCSLuaFile("autorun/client/taijutsu/cl_taijutsu_descendant.lua")
    include("autorun/server/taijutsu/sv_taijutsu_descendant.lua")
    AddCSLuaFile("autorun/client/taijutsu/cl_taijutsu_combo.lua")
    include("autorun/server/taijutsu/sv_taijutsu_combo.lua")
    AddCSLuaFile("autorun/client/taijutsu/cl_taijutsu_releve.lua")
    include("autorun/server/taijutsu/sv_taijutsu_releve.lua")
end

if CLIENT then
    include("autorun/client/taijutsu/cl_taijutsu_hitfx.lua")
    include("autorun/client/taijutsu/cl_taijutsu_pied.lua")
    include("autorun/client/taijutsu/cl_taijutsu_descendant.lua")
    include("autorun/client/taijutsu/cl_taijutsu_combo.lua")
    include("autorun/client/taijutsu/cl_taijutsu_releve.lua")
end
