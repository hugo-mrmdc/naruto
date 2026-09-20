--[[
    Entité : bûche laissée par la substitution (Kawarimi). Supprimée automatiquement.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Bûche de substitution"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        self:SetModel(NRP.Config.Combat.Substitution.LogModel)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end

        SafeRemoveEntityDelayed(self, self.Lifetime or 3)
    end
end
