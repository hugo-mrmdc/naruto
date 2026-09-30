-- Chargeur des techniques Uchiha (Sharingan).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    resource.AddFile("materials/ui/icon/uchiha_sharingan.png")
    resource.AddFile("materials/ui/icon/uchiha_boule_feu_supreme.png")

    -- boule de feu (modèle et textures de l'addon Workshop 3680039595, copiés ici)
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
        resource.AddFile("models/clan/konoha/uchiha/fireball." .. ext)
    end
    for _, f in ipairs(file.Find("materials/gluk/fireballtextures/*", "GAME")) do
        resource.AddFile("materials/gluk/fireballtextures/" .. f)
    end

    AddCSLuaFile("autorun/client/uchiha/cl_uchiha_sharingan.lua")
    include("autorun/server/uchiha/sv_uchiha_sharingan.lua")
    AddCSLuaFile("autorun/client/uchiha/cl_uchiha_boule_saut.lua")
    include("autorun/server/uchiha/sv_uchiha_boule_saut.lua")
end

if CLIENT then
    include("autorun/client/uchiha/cl_uchiha_sharingan.lua")
    include("autorun/client/uchiha/cl_uchiha_boule_saut.lua")
end
