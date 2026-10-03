--========================================================
-- Futton : Tornade de vapeur (entité, SERVEUR + CLIENT)
-- Avance tout droit (lancée par sv_futton_tornade.lua), collée au sol. Les ennemis dans son rayon
-- subissent des dégâts UNE fois par tornade. S'arrête sur un mur ou au bout de sa durée de vie.
-- Particule tornade_vapeur_pat (particles/patlick_atgparticules.pcf).
--========================================================

AddCSLuaFile()

-- particules chargées une seule fois par futton_init.lua (le pcf fait 2,8 Mo : le recharger à chaque tornade fait laguer)

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Tornade de vapeur"
ENT.Spawnable = false

ENT.Degats      = 8
ENT.Rayon       = 90
ENT.Vitesse     = 450
ENT.DureeVie    = 3
ENT.Intervalle  = 0.3    -- secondes entre deux ticks de dégâts
ENT.FX          = "tornade_vapeur_pat"

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

    function ENT:Think()
        -- un mouvement par tick serveur : fluide (en dessous, la tornade saccade)
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)
        if now > self.MortA then self:Remove() return true end

        local owner = self:GetOwner()
        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * dt

        -- mur : la tornade s'arrête
        if util.TraceHull({
            start = from + Vector(0, 0, 30), endpos = to + Vector(0, 0, 30),
            mins = Vector(-10, -10, -10), maxs = Vector(10, 10, 10), mask = MASK_SOLID_BRUSHONLY,
        }).Hit then self:Remove() return true end

        -- reste collée au sol
        local sol = util.TraceLine({ start = to + Vector(0, 0, 60), endpos = to - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if sol.Hit then to.z = sol.HitPos.z end
        self:SetPos(to)

        -- hitbox visible avec developer 1 (sphère de dégâts)
        if now >= (self.ProchainDebug or 0) and GetConVar("developer"):GetInt() > 0 then
            self.ProchainDebug = now + 0.1
            debugoverlay.Sphere(to + Vector(0, 0, 40), self.Rayon + 20, 0.1, Color(255, 120, 60, 25), true)
        end

        -- détection à chaque tick (une tornade rapide traverse une cible entre deux vérifications) ;
        -- chaque tornade ne touche une même cible qu'UNE seule fois
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
        self:SetNextClientThink(CurTime() + 0.5)   -- la particule est créée une fois : inutile de vérifier à chaque frame
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if IsValid(self.Fx) then self.Fx:StopEmission() end
    end
end
