--[[
    Entité : objet d'inventaire posé au sol (touche Utiliser pour ramasser)
]]

AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Objet"
ENT.Spawnable = false

local DEFAULT_MODEL = "models/props_junk/cardboard_box004a.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ItemId")
    self:NetworkVar("Int", 0, "Quantity")
end

if SERVER then
    function ENT:SetItem(id, qty)
        self:SetItemId(id)
        self:SetQuantity(qty)
    end

    function ENT:Initialize()
        local def = NRP.Inventory.Items:Get(self:GetItemId())
        local model = def and def.model or DEFAULT_MODEL
        self:SetModel(util.IsValidModel(model) and model or DEFAULT_MODEL)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
        self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end

    function ENT:Use(activator)
        if IsValid(activator) and activator:IsPlayer() and activator.NRPChar then
            NRP.Inventory.Pickup(activator, self)
        end
    end
else
    function ENT:Draw()
        self:DrawModel()
        if EyePos():DistToSqr(self:GetPos()) > 300 * 300 then return end

        local def = NRP.Inventory.Items:Get(self:GetItemId())
        if not def then return end

        local rarity = NRP.Inventory.GetRarity(def)
        local pos = self:GetPos() + Vector(0, 0, 18 + math.sin(CurTime() * 2) * 2)
        local ang = Angle(0, EyeAngles().y - 90, 90)

        cam.Start3D2D(pos, ang, 0.08)
            draw.SimpleTextOutlined(def.name .. " x" .. self:GetQuantity(), "DermaLarge", 0, 0,
                rarity.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
        cam.End3D2D()
    end
end
