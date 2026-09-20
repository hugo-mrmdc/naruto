--========================================================
-- Jinton : sphère du bouclier (entité, SERVEUR + CLIENT)
--
-- Attachée au lanceur (son Owner) : elle suit son centre, avec la particule
-- jinton_shield (particles/solve_jinton_02.pcf) à ses pieds.
-- Créée et retirée par sv_jinton_bouclier.lua.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Bouclier Jinton"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model   = "models/justu/jinton/sphereonoki.mdl"   -- sphère de ~68 unités, centrée
ENT.FX      = "jinton_shield"   -- particles/solve_jinton_02.pcf
ENT.FX_REPETER = 0     -- 0 = particule continue (jinton_shield) ; > 0 = relancée toutes les N secondes
                       -- (utile pour une particule qui ne dure qu'un instant)
ENT.Echelle = 1.35
ENT.Hauteur = 36   -- centre de la sphère au-dessus des pieds du joueur

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        local owner = self:GetOwner()
        if IsValid(owner) then
            self:SetPos(owner:GetPos() + Vector(0, 0, self.Hauteur))
            self:SetAngles(angle_zero)
            self:SetParent(owner)   -- suit le joueur sans décalage réseau
        end
    end

    function ENT:Think()
        if not IsValid(self:GetOwner()) then self:Remove() return end
        self:NextThink(CurTime() + 0.5)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-60, -60, -60), Vector(60, 60, 60))
        self.NA_Debut = CurTime()
    end

    -- Particule posée aux PIEDS du joueur, avec une orientation fixe : elle ne
    -- tourne pas avec la caméra (le joueur, et donc la sphère, tournent avec elle).
    local function PositionPieds(self)
        local owner = self:GetOwner()
        return IsValid(owner) and owner:GetPos() or (self:GetPos() - Vector(0, 0, self.Hauteur))
    end

    local function PlacerParticule(self)
        local p = self.Particule
        if not (p and p:IsValid()) then return end
        p:SetControlPoint(0, PositionPieds(self))
        p:SetControlPointOrientation(0, Vector(1, 0, 0), Vector(0, -1, 0), Vector(0, 0, 1))
    end

    -- (re)créée ici : plus fiable qu'à l'Initialize, et relancée si l'entité sort
    -- puis revient dans le champ du joueur
    function ENT:Think()
        if self.FX_REPETER > 0 then
            -- nouvelle bouffée à intervalle régulier (les anciennes finissent seules)
            if CurTime() >= (self.ProchainFX or 0) then
                self.ProchainFX = CurTime() + self.FX_REPETER
                self.Particule = CreateParticleSystem(self, self.FX, PATTACH_CUSTOMORIGIN, 0, PositionPieds(self))
                PlacerParticule(self)
            end
            self:SetNextClientThink(CurTime() + 0.05)
        else
            if not (self.Particule and self.Particule:IsValid()) then
                self.Particule = CreateParticleSystem(self, self.FX, PATTACH_CUSTOMORIGIN, 0, PositionPieds(self))
                PlacerParticule(self)
            end
            self:SetNextClientThink(CurTime() + 0.25)
        end
        return true
    end

    function ENT:Draw()
        PlacerParticule(self)   -- suit les pieds à chaque image

        -- apparition : la sphère grossit en 0,2 s
        local s = math.min((CurTime() - (self.NA_Debut or 0)) / 0.2, 1)
        local m = Matrix()
        m:Scale(Vector(1, 1, 1) * (0.3 + 0.7 * s))
        self:EnableMatrix("RenderMultiply", m)
        self:DrawModel()
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
