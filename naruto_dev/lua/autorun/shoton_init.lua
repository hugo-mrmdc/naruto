-- Chargeur des techniques Shoton (cristal).
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- solve_shoton_emeraude.pcf : toutes les couleurs vertes / rouges ont été passées en rose
game.AddParticles("particles/solve_shoton_emeraude.pcf")
-- tourbillon du lanceur (Cristal) : wind_vortex_shoton_geams_v2 (textures : naruto_content + cruel/ytr)
game.AddParticles("particles/solve_futon_rework_geams.pcf")
for _, nom in ipairs({ "wind_vortex_shoton_geams_v2", "[18]_wind_vortex_add_geams", "[18]_wind_vortex_add_2_geams" }) do
    PrecacheParticleSystem(nom)
end
PrecacheParticleSystem("wind_vortex_shoton_geams_rework_emeraude")
PrecacheParticleSystem("solve_explosion_pink_rubis")
PrecacheParticleSystem("solve_custom_bone_pink_emeraude")
PrecacheParticleSystem("solve_custom_explo_pink_emeraude")
PrecacheParticleSystem("solve_custom_explo_pink_pikes_emeraude")
-- Roquettes : anneau de poussière aux pieds avant le décollage (textures dans l'addon naruto_content)
game.AddParticles("particles/solve_impact_autoattack.pcf")
for _, nom in ipairs({ "auraburst_sharp", "auraburst_settle", "dust_sharp_ring_upper", "dust_sharp_ring", "dust_sharp_shockwave", "dust_sharp_shock" }) do
    PrecacheParticleSystem(nom)
end

if SERVER then
    resource.AddFile("particles/solve_impact_autoattack.pcf")
    resource.AddFile("particles/solve_shoton_emeraude.pcf")
    resource.AddFile("particles/solve_futon_rework_geams.pcf")
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx90.vtx" }) do resource.AddFile("models/shoton/solve_crystal01_kg_geams." .. ext) end
    AddCSLuaFile("autorun/client/shoton/cl_shoton_pics.lua")
    include("autorun/server/shoton/sv_shoton_pics.lua")
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx90.vtx" }) do resource.AddFile("models/shoton/solve_crystal02_kg_geams." .. ext) end
    AddCSLuaFile("autorun/client/shoton/cl_shoton_chute.lua")
    include("autorun/server/shoton/sv_shoton_chute.lua")
    AddCSLuaFile("autorun/client/shoton/cl_shoton_cristal.lua")
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx90.vtx" }) do resource.AddFile("models/shoton/pg_crystal_rocket." .. ext) end
    AddCSLuaFile("autorun/client/shoton/cl_shoton_rockets.lua")
    include("autorun/server/shoton/sv_shoton_rockets.lua")
    AddCSLuaFile("autorun/client/shoton/cl_shoton_armure.lua")
    include("autorun/server/shoton/sv_shoton_armure.lua")
    include("autorun/server/shoton/sv_shoton_cristal.lua")
end

if CLIENT then
    include("autorun/client/shoton/cl_shoton_cristal.lua")
    include("autorun/client/shoton/cl_shoton_chute.lua")
    include("autorun/client/shoton/cl_shoton_pics.lua")
    include("autorun/client/shoton/cl_shoton_armure.lua")
    include("autorun/client/shoton/cl_shoton_rockets.lua")
end

-- Roquettes : le lanceur monte puis reste suspendu (NW2Float posés par sv_shoton_rockets.lua).
-- Dans le hook "Move" (serveur + prédiction client) pour rester fluide.
hook.Add("Move", "ShotonRockets_Vol", function(ply, mv)
    local now = CurTime()
    if ply:GetNW2Float("NA_RocketsFin", 0) <= now then return end
    local montant = now < ply:GetNW2Float("NA_RocketsDebut", 0) + ply:GetNW2Float("NA_RocketsMontee", 0)
    mv:SetVelocity(Vector(0, 0, montant and ply:GetNW2Float("NA_RocketsVitesse", 0) or 0))
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
end)
