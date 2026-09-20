--[[
    Entité : marchand (boutique définie dans NRP.Config.Shops)
    Placement : regarder le point voulu puis « !shopnpc <boutique> » (sauvegardé par carte).
]]

AddCSLuaFile()

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Marchand"
ENT.Category = "Naruto RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ShopId")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.NPCModel or "models/Humans/Group01/male_06.mdl")
        self:SetHullType(HULL_HUMAN)
        self:SetHullSizeNormal()
        self:SetSolid(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_STEP)
        self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
        self:SetUseType(SIMPLE_USE)
        self:DropToFloor()
        if self:GetShopId() == "" then
            self:SetShopId("general")
        end
    end

    function ENT:OnTakeDamage()
        return 0
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() or not activator.NRPChar then return end
        if (activator.NRPNextShopUse or 0) > CurTime() then return end
        activator.NRPNextShopUse = CurTime() + 1

        NRP.Net.Start("OpenShop")
            net.WriteEntity(self)
            net.WriteString(self:GetShopId())
        net.Send(activator)
    end

    -- Persistance (voir modules/admin/sv_world.lua)
    function ENT:GetPersistData()
        return { shop = self:GetShopId() }
    end

    function ENT:SetPersistData(data)
        self:SetShopId(data.shop or "general")
    end
else
    function ENT:Draw()
        self:DrawModel()
        if EyePos():DistToSqr(self:GetPos()) > 500 * 500 then return end

        local shop = NRP.Inventory.Shops:Get(self:GetShopId())
        local pos = self:GetPos() + Vector(0, 0, 82)
        local ang = Angle(0, EyeAngles().y - 90, 90)

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleTextOutlined(shop and shop.name or "Marchand", "DermaLarge", 0, 0,
                Color(250, 200, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
        cam.End3D2D()
    end
end
