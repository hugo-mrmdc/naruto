--[[
    Entité : mannequin d'entraînement
    Chaque coup (poing, jutsu, outil) rapporte un peu d'XP d'entraînement (plafonnée par heure).
    Affiche les derniers dégâts reçus : pratique pour équilibrer les jutsu.
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Mannequin d'entraînement"
ENT.Category = "Naruto RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.NRPDamageable = true

if SERVER then
    function ENT:Initialize()
        local cfg = NRP.Config.Combat.TrainingDummy
        self:SetModel(cfg.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)
        self:SetMaxHealth(cfg.Health)
        self:SetHealth(cfg.Health)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end
    end

    function ENT:OnTakeDamage(dmg)
        local attacker = dmg:GetAttacker()
        self:SetNW2Int("NRP_LastDamage", math.floor(dmg:GetDamage()))
        self:SetNW2Float("NRP_LastHit", CurTime())

        if IsValid(attacker) and attacker:IsPlayer() and attacker.NRPChar then
            if (attacker.NRPDummyNext or 0) < CurTime() then
                attacker.NRPDummyNext = CurTime() + 0.5
                NRP.Progression.AddTrainingXP(attacker, NRP.Config.Progression.XP.TrainingHit or 1)
            end
        end
        return 0
    end
else
    function ENT:Draw()
        self:DrawModel()

        local last = self:GetNW2Float("NRP_LastHit", 0)
        if CurTime() - last > 3 then return end
        if EyePos():DistToSqr(self:GetPos()) > 600 * 600 then return end

        local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 10 + (CurTime() - last) * 10)
        local ang = Angle(0, EyeAngles().y - 90, 90)
        local alpha = 255 * (1 - (CurTime() - last) / 3)

        cam.Start3D2D(pos, ang, 0.2)
            draw.SimpleTextOutlined(tostring(self:GetNW2Int("NRP_LastDamage", 0)), "DermaLarge", 0, 0,
                Color(255, 200, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, alpha))
        cam.End3D2D()
    end
end
