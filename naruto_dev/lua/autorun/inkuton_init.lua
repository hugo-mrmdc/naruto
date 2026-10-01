-- Chargeur des techniques Inkuton (encre).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

if SERVER then
    -- tous les fichiers client sont envoyés AVANT les includes serveur : une erreur dans un
    -- fichier serveur ne doit pas empêcher les clients de recevoir les autres
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_chiens.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_singes.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_serpents.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_moine.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_dieux.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_dragon.lua")
    AddCSLuaFile("autorun/client/inkuton/cl_inkuton_editeur.lua")
    include("autorun/server/inkuton/sv_inkuton_chiens.lua")
    include("autorun/server/inkuton/sv_inkuton_singes.lua")
    include("autorun/server/inkuton/sv_inkuton_serpents.lua")   -- après les singes : réutilise leur visée
    include("autorun/server/inkuton/sv_inkuton_dieux.lua")      -- après les singes : réutilise NA_InkutonEstCible
    include("autorun/server/inkuton/sv_inkuton_dragon.lua")
    include("autorun/server/inkuton/sv_inkuton_moine.lua")      -- après les singes : réutilise NA_InkutonChercher
end

if CLIENT then
    include("autorun/client/inkuton/cl_inkuton_chiens.lua")
    include("autorun/client/inkuton/cl_inkuton_singes.lua")
    include("autorun/client/inkuton/cl_inkuton_serpents.lua")
    include("autorun/client/inkuton/cl_inkuton_moine.lua")
    include("autorun/client/inkuton/cl_inkuton_dieux.lua")
    include("autorun/client/inkuton/cl_inkuton_dragon.lua")
    include("autorun/client/inkuton/cl_inkuton_editeur.lua")
end
