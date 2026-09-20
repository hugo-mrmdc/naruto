--[[
    Entité : mur défensif (Doton : Doryūheki)
    Bloque les projectiles (même perforants), possède des points de vie et disparaît après
    sa durée de vie. Créé par l'archetype "wall" (modules/jutsu/archetypes/sv_wall.lua).
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Mur de jutsu"
ENT.Spawnable = false
ENT.NRPDamageable = true
ENT.NRPBlocksProjectiles = true

local RISE_TIME = 0.4

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.WallModel or "models/props_wasteland/rockcliff01b.mdl")
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        self:SetMaxHealth(self.WallHealth or 300)
        self:SetHealth(self.WallHealth or 300)
        self:SetNW2Float("NRP_RiseStart", CurTime())
        SafeRemoveEntityDelayed(self, self.Lifetime or 10)
    end

    function ENT:OnTakeDamage(dmg)
        self:SetHealth(self:Health() - dmg:GetDamage())
        if self:Health() <= 0 and not self.NRPBroken then
            self.NRPBroken = true
            self:EmitSound("physics/concrete/concrete_break" .. math.random(2, 3) .. ".wav")
            NRP.Combat.PlayFX("earth", self:GetPos(), { scale = 1.5 })
            self:Remove()
        end
        return 0
    end

    function ENT:OnRemove()
        local owner = self:GetOwner()
        if IsValid(owner) and owner.NRPWalls then
            table.RemoveByValue(owner.NRPWalls, self)
        end
    end
else
    function ENT:Draw()
        local frac = math.Clamp((CurTime() - self:GetNW2Float("NRP_RiseStart", 0)) / RISE_TIME, 0, 1)
        if frac >= 1 then
            self:DrawModel()
            return
        end

        local height = self:OBBMaxs().z - self:OBBMins().z
        self:SetRenderOrigin(self:GetPos() - Vector(0, 0, height * (1 - frac)))
        self:SetupBones()
        self:DrawModel()
        self:SetRenderOrigin(nil)
    end
end
