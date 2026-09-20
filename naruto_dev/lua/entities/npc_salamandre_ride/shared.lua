-- shared.lua
-- Place dans garrysmod/lua/entities/npc_salamandre_ride/shared.lua

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Salamandre Montable"
ENT.Author = "Ton Nom"
ENT.Category = "Mounts"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Rider")
end