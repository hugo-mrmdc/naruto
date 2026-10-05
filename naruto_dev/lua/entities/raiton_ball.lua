--========================================================
-- Boule de foudre (entité projectile, SERVEUR)
--
-- Boule invisible portant la particule solve_raiton_ball_small (particles/solve_raiton.pcf) qui file
-- en ligne droite. Testée à chaque tick (TraceHull, comme une balle) : elle ne traverse ni les murs
-- ni les cibles. À l'impact : dégâts + étourdissement de la cible touchée.
-- Les valeurs viennent de la technique (sv_raiton_boule.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Boule de foudre"
ENT.Spawnable = false

ENT.FX = "solve_raiton_ball_small"   -- particles/solve_raiton.pcf (chargé par sv_ / cl_raiton_boule.lua)

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse   = 1300
ENT.Degats    = 30
ENT.Duree     = 1.5   -- étourdissement
ENT.DureeVie  = 2
ENT.Rayon     = 30    -- demi-largeur de la zone qui touche
ENT.RayonHaut = 30    -- demi-hauteur de la zone qui touche

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()
        self:SetAngles(self.Dir:Angle())

        ParticleEffectAttach(self.FX, PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit, owner = tr.Entity, self:GetOwner()
        if IsValid(hit) and hit ~= owner and (hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot()) then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetDamagePosition(tr.HitPos)
            hit:TakeDamageInfo(dmg)

            if NA_Etourdir then NA_Etourdir(hit, self.Duree) end
        end

        sound.Play("naruto_sound/jutsu/raiton/raiton10.wav", tr.HitPos, 80, math.random(95, 110), 1)
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end
        if CurTime() > self.MortA then self:Remove() return end

        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * FrameTime()
        local r, h = self.Rayon, self.RayonHaut

        local tr = util.TraceHull({
            start = from, endpos = to,
            mins = Vector(-r, -r, -h), maxs = Vector(r, r, h),
            filter = { self, self:GetOwner() },
            mask = MASK_SHOT,
        })

        if tr.Hit then
            self:SetPos(tr.HitPos)
            self:Impact(tr)
            return
        end

        self:SetPos(to)
        self:NextThink(CurTime())
        return true
    end
end
