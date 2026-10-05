--========================================================
-- Futon : Ouragan de vent (entité, SERVEUR + CLIENT)
-- Une grosse tornade qui avance tout droit (lancée par sv_futon_ouragan.lua), collée au sol.
-- Chaque ennemi dans son rayon est touché UNE fois par ouragan : dégâts + petit bump (poussé
-- dans le sens de l'ouragan et un peu vers le haut). S'arrête sur un mur ou au bout de sa durée de vie.
-- Particule atg_projection1 (particles/patlick_atgparticules.pcf, chargée ici).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Ouragan de vent"
ENT.Spawnable = false

ENT.Degats    = 60
ENT.Rayon     = 110
ENT.Vitesse   = 500
ENT.DureeVie  = 3
ENT.Pousse    = 450      -- vitesse horizontale donnée à la cible (bump)
ENT.Soulevee  = 250      -- vitesse verticale donnée à la cible
ENT.FX        = "atg_projection1"

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self.MortA = CurTime() + self.DureeVie
        self.Touches = {}   -- [cible] = true une fois touchée
        self.Dir = self:GetAngles():Forward()
    end

    function ENT:Bump(ent)
        local v = self.Dir * self.Pousse
        v.z = self.Soulevee
        -- un joueur au sol ne décolle pas toujours : on le décolle d'abord
        if ent:IsPlayer() then ent:SetGroundEntity(NULL) end
        ent:SetVelocity(v)
    end

    function ENT:Think()
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)
        if now > self.MortA then self:Remove() return true end

        local owner = self:GetOwner()
        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * dt

        -- mur : l'ouragan s'arrête
        if util.TraceHull({
            start = from + Vector(0, 0, 30), endpos = to + Vector(0, 0, 30),
            mins = Vector(-10, -10, -10), maxs = Vector(10, 10, 10), mask = MASK_SOLID_BRUSHONLY,
        }).Hit then self:Remove() return true end

        -- reste collé au sol
        local sol = util.TraceLine({ start = to + Vector(0, 0, 60), endpos = to - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if sol.Hit then to.z = sol.HitPos.z end
        self:SetPos(to)

        local touches = self.Touches
        for _, ent in ipairs(ents.FindInSphere(to + Vector(0, 0, 40), self.Rayon + 20)) do
            if not touches[ent] and EstCible(ent, owner) then
                touches[ent] = true
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BURN)
                dmg:SetDamagePosition(ent:WorldSpaceCenter())
                ent:TakeDamageInfo(dmg)
                self:Bump(ent)
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
