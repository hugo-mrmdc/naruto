--========================================================
-- Hyoton : Prison de glace (entité, SERVEUR + CLIENT)
-- Posée sur la cible étourdie (sv_hyoton_prison.lua) : arène de miroirs (models/hyoton/mirror_arena_geams.mdl) et
-- particule [4]_ice_judgmentcut (particles/solve_ice.pcf). La cible subit des dégâts à chaque tick tant que la
-- prison tient ; elle disparaît au bout de DureeVie, ou si la cible ou le lanceur meurt.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Prison de glace"
ENT.Spawnable = false

ENT.DureeVie   = 2.5
ENT.Degats     = 5      -- par tick
ENT.Intervalle = 0.5
ENT.Echelle    = 0.8  -- le modèle fait ~470 unités de large à l'échelle 1 : ajuster si trop gros / petit
ENT.Enfonce    = 148    -- le bas du modèle est à -148 de l'origine (à l'échelle 1) : sert à le poser sur le sol
ENT.FX         = "[4]_ice_judgmentcut"

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/hyoton/mirror_arena_geams.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self:SetPos(self:GetPos() + Vector(0, 0, self.Enfonce * self.Echelle))
        self.MortA = CurTime() + self.DureeVie
        self.ProchainTick = CurTime() + self.Intervalle
    end

    function ENT:Think()
        self:NextThink(CurTime())
        local owner, cible = self:GetOwner(), self.Cible
        if CurTime() > self.MortA or not IsValid(cible) or cible:Health() <= 0
            or not IsValid(owner) or (owner:IsPlayer() and not owner:Alive()) then
            self:Remove()
            return true
        end
        if CurTime() >= self.ProchainTick then
            self.ProchainTick = CurTime() + self.Intervalle
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetDamagePosition(cible:WorldSpaceCenter())
            cible:TakeDamageInfo(dmg)
        end
        return true
    end
end

if CLIENT then
    function ENT:Think()
        if self.Fx == nil or (self.Fx and not IsValid(self.Fx)) then
            self.Fx = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, -self.Enfonce * self.Echelle)) or false   -- descendue au niveau du sol (l'origine du modèle est relevée)
        end
        self:SetNextClientThink(CurTime() + 0.5)   -- la particule est créée une fois
        return true
    end

    function ENT:Draw() self:DrawModel() end

    function ENT:OnRemove()
        if IsValid(self.Fx) then self.Fx:StopEmission() end
    end
end
