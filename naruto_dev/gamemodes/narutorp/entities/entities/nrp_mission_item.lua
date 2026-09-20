--[[
    Entité : objet de mission à récupérer (touche Utiliser)
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Objet de mission"
ENT.Spawnable = false

if SERVER then
    function ENT:Initialize()
        if self:GetModel() == "" or not util.IsValidModel(self:GetModel()) then
            self:SetModel("models/props_junk/cardboard_box003a.mdl")
        end
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator)
        if IsValid(activator) and activator:IsPlayer() and activator.NRPChar then
            NRP.Missions.OnItemUsed(activator, self)
        end
    end
else
    local MAT_GLOW = Material("sprites/light_glow02_add")

    function ENT:Draw()
        self:DrawModel()
        local pulse = 40 + math.sin(CurTime() * 4) * 10
        render.SetMaterial(MAT_GLOW)
        render.DrawSprite(self:WorldSpaceCenter(), pulse, pulse, Color(255, 200, 60, 120))
    end
end
