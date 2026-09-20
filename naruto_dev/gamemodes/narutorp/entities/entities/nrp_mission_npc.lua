--[[
    Entité : donneur de mission (tableau de missions d'un village)
    Placement : « !missionnpc <village|all> » (sauvegardé pour la carte).
]]

AddCSLuaFile()

ENT.Type = "ai"
ENT.Base = "base_ai"
ENT.PrintName = "Donneur de mission"
ENT.Category = "Naruto RP"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.AutomaticFrameAdvance = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Village")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(NRP.Config.MissionSettings.NPCModel)
        self:SetHullType(HULL_HUMAN)
        self:SetHullSizeNormal()
        self:SetSolid(SOLID_BBOX)
        self:SetMoveType(MOVETYPE_STEP)
        self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
        self:SetUseType(SIMPLE_USE)
        self:DropToFloor()
    end

    function ENT:OnTakeDamage()
        return 0
    end

    function ENT:Use(activator)
        if not IsValid(activator) or not activator:IsPlayer() or not activator.NRPChar then return end
        if (activator.NRPNextBoardUse or 0) > CurTime() then return end
        activator.NRPNextBoardUse = CurTime() + 1
        NRP.Missions.OnNPCUse(activator, self)
    end

    function ENT:GetPersistData()
        return { village = self:GetVillage() }
    end

    function ENT:SetPersistData(data)
        self:SetVillage(data.village or "")
    end
else
    function ENT:Draw()
        self:DrawModel()
        if EyePos():DistToSqr(self:GetPos()) > 600 * 600 then return end

        local village = NRP.Villages:Get(self:GetVillage())
        local pos = self:GetPos() + Vector(0, 0, 84)
        local ang = Angle(0, EyeAngles().y - 90, 90)

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleTextOutlined("Missions", "DermaLarge", 0, 0, Color(255, 200, 60),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
            draw.SimpleTextOutlined(village and village.name or "Tous villages", "DermaDefaultBold", 0, 26,
                village and village.color or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        cam.End3D2D()
    end
end
