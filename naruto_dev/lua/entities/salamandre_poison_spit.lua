--========================================================
-- Crachat de poison de la salamandre (entité projectile, SERVEUR + CLIENT)
--
-- Le serveur trace sa trajectoire à chaque tick (TraceLine sur les hitbox,
-- comme une balle) : il ne traverse ni les murs ni les cibles, même rapide.
-- À l'impact : dégâts + empoisonnement (SalamandrePoison, sv_poison_projectile.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Crachat de poison"
ENT.Spawnable = false

ENT.Model     = "models/props_junk/PopCan01a.mdl"   -- invisible, seul l'effet se voit
ENT.FX_TRAIL  = "godio_crachat_sala"                -- particles/godio_salamandre.pcf
ENT.FX_IMPACT = "godio_impact_sala"

-- Valeurs par défaut ; la technique les remplace au lancement (sv_poison_projectile.lua)
ENT.Vitesse   = 1500
ENT.Degats    = 50
ENT.DureeVie  = 3
ENT.Gravite   = 0      -- chute par seconde² (0 = ligne droite)
ENT.Rayon     = 6      -- demi-largeur de la zone de touche

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self.MortA = CurTime() + self.DureeVie
        self.Vel = (self.Direction or self:GetForward()) * self.Vitesse
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
            dmg:SetDamageType(DMG_ACID)
            dmg:SetDamagePosition(tr.HitPos)
            hit:TakeDamageInfo(dmg)

            if SalamandrePoison and SalamandrePoison.Apply then
                SalamandrePoison.Apply(hit, owner)
            end

            hit:EmitSound("physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav", 70, 110)
        else
            self:EmitSound("physics/flesh/flesh_bloody_impact_hard1.wav", 65, 130)
        end

        ParticleEffect(self.FX_IMPACT, tr.HitPos, tr.HitNormal:Angle())
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end

        if CurTime() > self.MortA then
            self:Remove()
            return
        end

        local dt = FrameTime()
        if self.Gravite ~= 0 then
            self.Vel.z = self.Vel.z - self.Gravite * dt
        end

        local from = self:GetPos()
        local step = self.Vel * dt
        local to = from + step
        local owner = self:GetOwner()

        -- 5 couloirs de trace : centre + haut/bas/gauche/droite (TraceLine = hitbox)
        local a = self.Vel:Angle()
        local r, u = a:Right() * self.Rayon, a:Up() * self.Rayon

        local best
        for _, off in ipairs({ vector_origin, r, -r, u, -u }) do
            local tr = util.TraceLine({
                start = from + off,
                endpos = to + off,
                filter = { self, owner },
                mask = MASK_SHOT,
            })
            if tr.Hit then
                local vivant = EstVivant(tr.Entity)
                if not best
                    or tr.Fraction < best.tr.Fraction - 0.001
                    or (vivant and not best.vivant and tr.Fraction <= best.tr.Fraction + 0.001) then
                    best = { tr = tr, vivant = vivant }
                end
            end
        end

        if best then
            self:SetPos(from + step * best.tr.Fraction)
            self:Impact(best.tr)
            return
        end

        self:SetPos(to)
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- chaque client crée la traînée en recevant l'entité : tout le monde la voit
        ParticleEffectAttach(self.FX_TRAIL, PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end

    function ENT:Draw()
        -- rien : seul le crachat (particules) est visible
    end

    function ENT:OnRemove()
        self:StopParticles()
    end
end
