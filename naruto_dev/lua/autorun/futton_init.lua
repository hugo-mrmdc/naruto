-- Chargeur des techniques Futton (vapeur).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("emanation_vapeur_pat")
PrecacheParticleSystem("tornade_vapeur_pat")
PrecacheParticleSystem("monde_vapeur_pat")
PrecacheParticleSystem("cage_vapeur_pat")
game.AddParticles("particles/futtontornade.pcf")
PrecacheParticleSystem("futtontornade")
PrecacheParticleSystem("futtontornade_2")
game.AddParticles("particles/futtontornade_grand.pcf")
PrecacheParticleSystem("futtonxornade")
-- Projectile de vapeur : copie assombrie de futon_projectile_geams (solve_futon_rework_geams.pcf), en 3 sous-effets
-- à précharger tous, sinon ils restent invisibles
game.AddParticles("particles/futton_projectile_vapeur.pcf")
for _, nom in ipairs({ "futon_projectile_geams_vap", "[10]_fire_tiger_projectile_add_meiton_geams_new_vap", "[10]_fire_tiger_projectile_add_2_meiton_geams_new_vap", "[10]_fire_tiger_projectile_add_3_meiton_geams_new_vap" }) do
    PrecacheParticleSystem(nom)
end

-- Émanation de vapeur : bonus de vitesse. NW2Bool "NA_FuttonVapeur" + NW2Float "NA_FuttonVitesse" (multiplicateur),
-- posés par sv_futton_vapeur.lua. Dans le hook "Move" (serveur + prédiction client) pour rester fluide.
hook.Add("Move", "FuttonVapeur_Vitesse", function(ply, mv)
    if not ply:GetNW2Bool("NA_FuttonVapeur", false) then return end
    local v = ply:GetNW2Float("NA_FuttonVitesse", 1)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * v)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * v)
end)

-- Monde de vapeur : ralenti des ennemis dans la zone. NW2Float "NA_FuttonMondeFin" = moment où il s'arrête,
-- "NA_FuttonMondeRalenti" = multiplicateur de vitesse (posés par l'entité futton_monde à chaque tick).
hook.Add("Move", "FuttonMonde_Ralenti", function(ply, mv)
    if ply:GetNW2Float("NA_FuttonMondeFin", 0) <= CurTime() then return end
    local r = ply:GetNW2Float("NA_FuttonMondeRalenti", 1)
    mv:SetMaxSpeed(mv:GetMaxSpeed() * r)
    mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * r)
end)

if SERVER then
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("particles/futtontornade.pcf")
    resource.AddFile("particles/futtontornade_grand.pcf")
    resource.AddFile("particles/futton_projectile_vapeur.pcf")
    AddCSLuaFile("autorun/client/futton/cl_futton_projectile.lua")
    include("autorun/server/futton/sv_futton_projectile.lua")
    AddCSLuaFile("autorun/client/futton/cl_futton_vapeur.lua")
    AddCSLuaFile("autorun/client/futton/cl_futton_tornade.lua")
    AddCSLuaFile("autorun/client/futton/cl_futton_cage.lua")
    AddCSLuaFile("autorun/client/futton/cl_futton_monde.lua")
    AddCSLuaFile("autorun/client/futton/cl_futton_prison.lua")
    include("autorun/server/futton/sv_futton_vapeur.lua")
    include("autorun/server/futton/sv_futton_tornade.lua")
    include("autorun/server/futton/sv_futton_cage.lua")
    include("autorun/server/futton/sv_futton_monde.lua")
    include("autorun/server/futton/sv_futton_prison.lua")
end

if CLIENT then
    include("autorun/client/futton/cl_futton_projectile.lua")
    include("autorun/client/futton/cl_futton_vapeur.lua")
    include("autorun/client/futton/cl_futton_tornade.lua")
    include("autorun/client/futton/cl_futton_cage.lua")
    include("autorun/client/futton/cl_futton_monde.lua")
    include("autorun/client/futton/cl_futton_prison.lua")
end
