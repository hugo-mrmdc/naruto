-- Chargeur des techniques Jiton (sable).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Particules : chargées des deux côtés (sinon le serveur ne peut pas les lancer)
game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem("[1]_sand_sarcophag")
PrecacheParticleSystem("[1]_sand_emergence")

-- Émergence de sable : ralenti des joueurs qui se tiennent dans la zone.
-- NW2Float "NA_JitonEmergenceFin" = moment où le ralenti s'arrête, "NA_JitonEmergenceRalenti" =
-- multiplicateur de vitesse (posés par sv_jiton_emergence.lua à chaque tick de la zone).
-- Dans le hook "Move" (serveur + prédiction client) pour rester fluide.
hook.Add("Move", "JitonEmergence_Ralenti", function(ply, mv)
    if ply:GetNW2Float("NA_JitonEmergenceFin", 0) <= CurTime() then return end
    local ralenti = ply:GetNW2Float("NA_JitonEmergenceRalenti", 1)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * ralenti)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * ralenti)
end)

if SERVER then
    resource.AddFile("particles/atg_faris.pcf")
    resource.AddFile("materials/ui/icon/jiton_sarcophage_de_sable.png")
    resource.AddFile("materials/ui/icon/jiton_emergence_de_sable.png")

    AddCSLuaFile("autorun/client/jiton/cl_jiton_sarcophage.lua")
    include("autorun/server/jiton/sv_jiton_sarcophage.lua")

    AddCSLuaFile("autorun/client/jiton/cl_jiton_emergence.lua")
    include("autorun/server/jiton/sv_jiton_emergence.lua")
end

if CLIENT then
    include("autorun/client/jiton/cl_jiton_sarcophage.lua")
    include("autorun/client/jiton/cl_jiton_emergence.lua")
end
