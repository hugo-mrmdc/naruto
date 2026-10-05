--========================================================
-- Grosse boule de feu (entité, SERVEUR + CLIENT)
--
-- Projectile qui avance droit devant lui et explose au premier contact :
-- dégâts + brûlure à tous ceux dans le rayon d'explosion, sauf le lanceur.
-- Le feu (solve_katon_bigball_aura) suit la boule, créé par chaque client ;
-- à l'impact, le serveur prévient les clients (net "katon_grosse_boule_impact")
-- qui jouent solve_katon_bigball_impact. Valeurs : sv_katon_grosse_boule.lua.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Grosse boule de feu"
ENT.Spawnable = false

ENT.Model  = "models/hunter/misc/sphere025x025.mdl"   -- invisible, seul le feu se voit
ENT.FX     = "solve_katon_bigball_aura"               -- particles/solve_new_katon.pcf
ENT.FXHit  = "solve_katon_bigball_impact"

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse      = 900
ENT.Vie          = 3
ENT.Hitbox       = 40
ENT.Degats       = 60
ENT.RayonExplo   = 220
ENT.BrulureDuree = 4
ENT.BrulureDps   = 5

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self.Mort = CurTime() + self.Vie
        self.Dir = self.Dir or self:GetForward()
        self:EmitSound("geams/solve_jutsu/katon/solve_katon_arena_start.wav", 85, 70)
    end

    function ENT:Exploser(pos)
        local lanceur = self:GetOwner()

        for _, ent in ipairs(ents.FindInSphere(pos, self.RayonExplo)) do
            if ent == lanceur or not IsValid(ent) then continue end
            local vivant = (ent:IsPlayer() and ent:Alive())
                or ((ent:IsNPC() or ent:IsNextBot()) and ent:Health() > 0)
            if not vivant then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetDamagePosition(pos)
            ent:TakeDamageInfo(dmg)

            if self.BrulureDuree > 0 and NA_Bruler then
                NA_Bruler(ent, lanceur, self.BrulureDuree, self.BrulureDps)
            end
        end

        -- l'impact visuel est posé au sol, sous le point de contact
        local sol = util.TraceLine({
            start = pos + Vector(0, 0, 20),
            endpos = pos - Vector(0, 0, 500),
            mask = MASK_SOLID_BRUSHONLY,
        })
        net.Start("katon_grosse_boule_impact")
            net.WriteVector(sol.Hit and sol.HitPos or pos)
        net.Broadcast()
        self:EmitSound("geams/solve_jutsu/katon/solve_katon_balsamique.wav", 90, 110)
        self:Remove()
    end

    function ENT:Think()
        local now = CurTime()
        local lanceur = self:GetOwner()
        if now >= self.Mort or not IsValid(lanceur) then
            self:Remove()   -- fin de vie sans contact : pas d'explosion
            return
        end

        local dt = now - (self.Dernier or now - 0.02)
        self.Dernier = now

        local from = self:GetPos()
        local h = self.Hitbox
        local tr = util.TraceHull({
            start = from, endpos = from + self.Dir * self.Vitesse * dt,
            -- hitbox remontée : plus rien sous la ligne de visée, la boule ne racle plus le sol
            mins = Vector(-h, -h, 0), maxs = Vector(h, h, h * 2),
            filter = { lanceur, self }, mask = MASK_SHOT,
        })

        self:SetPos(tr.HitPos)
        if tr.Hit then
            self:Exploser(tr.HitPos)
            return
        end

        self:NextThink(now)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-150, -150, -150), Vector(150, 150, 150))
    end

    -- (re)créé ici plutôt qu'à l'Initialize : plus fiable
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
