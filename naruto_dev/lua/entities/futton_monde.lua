--========================================================
-- Futton : Monde de vapeur (entité, SERVEUR + CLIENT)
-- Grande zone de vapeur posée sur le lanceur (sv_futton_monde.lua), avec la particule monde_vapeur_pat
-- (particles/patlick_atgparticules.pcf). Les ennemis dedans subissent des dégâts à chaque tick et sont
-- ralentis (NW2Float "NA_FuttonMondeFin" / "NA_FuttonMondeRalenti", lus par le hook Move de futton_init.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Monde de vapeur"
ENT.Spawnable = false

ENT.Rayon      = 500
ENT.Hauteur    = 400
ENT.DureeVie   = 10
ENT.Degats     = 8      -- par tick
ENT.Intervalle = 0.5
ENT.Ralenti    = 0.6    -- multiplicateur de vitesse des ennemis dedans
ENT.FX         = "monde_vapeur_pat"

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self.MortA = CurTime() + self.DureeVie
        self.ProchainTick = 0
    end

    function ENT:Think()
        self:NextThink(CurTime() + 0.1)
        local owner = self:GetOwner()
        local now = CurTime()
        if now > self.MortA or not IsValid(owner) or (owner:IsPlayer() and not owner:Alive()) then
            self:Remove()
            return true
        end

        local c = self:GetPos()
        local tick = now >= self.ProchainTick
        if tick then self.ProchainTick = now + self.Intervalle end

        for _, ent in ipairs(ents.FindInSphere(c, self.Rayon + self.Hauteur)) do
            if EstCible(ent, owner) then
                local p = ent:GetPos()
                local d = Vector(p.x - c.x, p.y - c.y, 0):Length()
                if d <= self.Rayon and p.z >= c.z - 80 and p.z <= c.z + self.Hauteur then
                    if ent:IsPlayer() then
                        ent:SetNW2Float("NA_FuttonMondeFin", now + 0.3)
                        ent:SetNW2Float("NA_FuttonMondeRalenti", self.Ralenti)
                    end
                    if tick then
                        local dmg = DamageInfo()
                        dmg:SetDamage(self.Degats)
                        dmg:SetAttacker(owner)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_BURN)
                        dmg:SetDamagePosition(ent:WorldSpaceCenter())
                        ent:TakeDamageInfo(dmg)
                    end
                end
            end
        end

        if GetConVar("developer"):GetInt() > 0 then
            local prec
            for i = 0, 32 do
                local a = math.rad(i / 32 * 360)
                local q = c + Vector(math.cos(a), math.sin(a), 0) * self.Rayon
                if prec then debugoverlay.Line(prec, q, 0.15, Color(120, 200, 255), true) end
                prec = q
            end
        end
        return true
    end
end

if CLIENT then
    function ENT:Think()
        if self.Fx == nil or (self.Fx and not IsValid(self.Fx)) then
            self.Fx = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW) or false
        end
        self:SetNextClientThink(CurTime() + 0.5)
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if IsValid(self.Fx) then self.Fx:StopEmission() end
    end
end
