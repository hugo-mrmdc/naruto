--========================================================
-- Inkuton : Chien d'encre (entité projectile, SERVEUR + CLIENT)
-- Court en ligne droite au ras du sol (séquence saidogrunloop), blesse le premier ennemi touché.
-- Le serveur trace sa trajectoire à chaque tick : il ne traverse ni les murs ni les joueurs.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Chien d'encre"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true   -- sinon la séquence ne joue pas (le serveur doit faire avancer l'animation)

ENT.Model     = "models/inkuton/saidog.mdl"
ENT.Sequence  = "saidogrunloop"
ENT.PCF       = "particles/solve_inkuton_geams.pcf"
ENT.FX_HIT    = "solve_inkuton_dog_impact"
ENT.FX_SPAWN  = "solve_inkuton_spawn_dog"    -- jouée une fois à l'apparition du chien
ENT.FX_CIBLE  = "nrp_inkuton_big"             -- sur la cible touchée (dans solve_inkuton_geams.pcf)
ENT.FX_TRACE  = "solve_inkuton_dog_trace"    -- traînée attachée au chien pendant sa course

-- Valeurs par défaut ; la technique les remplace au lancement (sv_inkuton_chiens.lua)
ENT.Vitesse   = 900
ENT.Degats    = 35
ENT.DureeVie  = 1.5
ENT.Echelle   = 1
ENT.Hauteur   = 10   -- unités dont on relève le chien au-dessus du sol (l'origine du modèle est sous les pattes : sinon il s'enfonce et devient noir)

local RAYON_BASE = 25   -- demi-largeur de la zone de touche à l'échelle 1

if SERVER then
    game.AddParticles(ENT.PCF)
    PrecacheParticleSystem(ENT.FX_SPAWN)
    PrecacheParticleSystem(ENT.FX_TRACE)
    PrecacheParticleSystem(ENT.FX_HIT)
    PrecacheParticleSystem(ENT.FX_CIBLE)

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        local seq = self:LookupSequence(self.Sequence)
        if seq and seq >= 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
        end

        self:SetPos(self:GetPos() + Vector(0, 0, self.Hauteur * self.Echelle))
        self.MortA = CurTime() + self.DureeVie
        self.Direction = self.Direction or self:GetForward()
        self:SetAngles(Angle(0, self.Direction:Angle().y, 0))
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit = tr.Entity
        local owner = self:GetOwner()

        if IsValid(hit) and hit ~= owner then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(tr.HitPos)
            dmg:SetDamageForce(self.Direction * 3000)
            hit:TakeDamageInfo(dmg)
            ParticleEffectAttach(self.FX_CIBLE, PATTACH_ABSORIGIN_FOLLOW, hit, 0)   -- effet sur la cible touchée
        end

        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end
        if CurTime() > self.MortA then self:Remove() return end

        local from = self:GetPos()
        local to = from + self.Direction * self.Vitesse * FrameTime()
        local r = RAYON_BASE * self.Echelle
        local tr = util.TraceHull({
            start = from + Vector(0, 0, r), endpos = to + Vector(0, 0, r),
            mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
            filter = { self, self:GetOwner() },
            mask = MASK_SHOT,
        })

        if tr.Hit then
            self:SetPos(tr.HitPos - Vector(0, 0, r))
            self:Impact(tr)
            return
        end

        -- reste collé au sol (marches, pentes) ; au-dessus du vide ou d'un sol lointain, il tombe (gravité)
        to.z = from.z
        local sol = util.TraceLine({ start = to + Vector(0, 0, 40), endpos = to - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
        local haut = self.Hauteur * self.Echelle
        local cible = sol.Hit and sol.HitPos.z + haut or -math.huge
        if to.z - cible > 20 * self.Echelle then
            local dt = FrameTime()
            self.VZ = (self.VZ or 0) - 1500 * dt
            to.z = math.max(from.z + self.VZ * dt, cible)
            if to.z == cible then self.VZ = 0 end
        else
            to.z = cible
            self.VZ = 0
        end

        self:SetPos(to)
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        game.AddParticles(self.PCF)
        PrecacheParticleSystem(self.FX_HIT)
        PrecacheParticleSystem(self.FX_SPAWN)
        PrecacheParticleSystem(self.FX_TRACE)
        PrecacheParticleSystem(self.FX_CIBLE)
    end

    -- Les trois chiens apparaissent dans la même image : à l'Initialize du client, certains ne sont pas encore
    -- prêts et leurs particules ne se créent pas. On les crée (ou recrée) dans le Think, pour chaque chien.
    function ENT:Think()
        if not self.SpawnFX then
            self.SpawnFX = true
            ParticleEffect(self.FX_SPAWN, self:GetPos(), self:GetAngles())
        end
        if self.Trace == nil or (self.Trace and not IsValid(self.Trace)) then
            -- false = création impossible (nom de particule faux) : on n'insiste pas
            self.Trace = CreateParticleSystem(self, self.FX_TRACE, PATTACH_ABSORIGIN_FOLLOW) or false
        end
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:OnRemove()
        if IsValid(self.Trace) then self.Trace:StopEmission() end
    end
end
