-- Chargeur de la Permutation (Kawarimi).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx", "sw.vtx" }) do
        resource.AddFile("models/justu/permut_log." .. ext)
    end

    AddCSLuaFile("autorun/client/permutation/cl_permutation.lua")
    include("autorun/server/permutation/sv_permutation.lua")
end

if CLIENT then
    include("autorun/client/permutation/cl_permutation.lua")
end
