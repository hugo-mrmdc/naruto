--========================================================
-- Boule d'eau (entité projectile, SERVEUR + CLIENT)
--
-- Le serveur fait avancer la boule en ligne droite et teste sa trajectoire à
-- chaque tick (TraceHull, comme une balle) : elle ne traverse ni les murs ni les
-- cibles. À l'impact : dégâts + projection, puis elle disparaît.
-- L'affichage est le modèle waterball lui-même, vu par tout le monde.
--
-- Les valeurs viennent de la technique (sv_suiton_waterball.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Boule d'eau"
ENT.Spawnable = false

ENT.Model     = "models/suiton/waterball.mdl"
ENT.FX_IMPACT = "jet_eau_hit_pat"   -- particles/atg_particules2.pcf (chargé par sv_ / cl_suiton_waterball.lua)

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse  = 1400
ENT.Degats   = 30
ENT.DureeVie = 2
ENT.Rayon    = 22     -- demi-taille de la zone qui touche
ENT.Echelle  = 0.5    -- taille du modèle (1 = rayon d'environ 65 unités)
ENT.Recul    = 350    -- projection de la cible touchée

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()
    end

    local function EstVivant(ent)
        return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit = tr.Entity
        local owner = self:GetOwner()

        if EstVivant(hit) and hit ~= owner then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetDamagePosition(tr.HitPos)
            hit:TakeDamageInfo(dmg)

            -- projection : dans le sens de la boule, un peu vers le haut
            if self.Recul > 0 then
                hit:SetVelocity(self.Dir * self.Recul + Vector(0, 0, self.Recul * 0.35))
            end
        end

        ParticleEffect(self.FX_IMPACT, tr.HitPos, tr.HitNormal:Angle())
        self:EmitSound("naruto_sound/jutsu/senju/senju2.wav", 80, 100)
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end

        if CurTime() > self.MortA then
            self:Remove()
            return
        end

        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * FrameTime()
        local r = self.Rayon

        local tr = util.TraceHull({
            start = from,
            endpos = to,
            mins = Vector(-r, -r, -r),
            maxs = Vector(r, r, r),
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
