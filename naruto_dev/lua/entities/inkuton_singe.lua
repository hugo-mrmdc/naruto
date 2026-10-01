--========================================================
-- Inkuton : Singe d'encre (entité, SERVEUR + CLIENT)
-- Court vers la cible visée et la rattrape TOUJOURS (il suit sa position à chaque tick, aucun mur ne
-- l'arrête). Au contact il grimpe sur elle (sequence Ride) : l'effet est géré par sv_inkuton_singes.lua
-- (NA_SingeAccrocher). Même modèle d'effet de course que les chiens (traînée solve_inkuton_dog_trace).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Singe d'encre"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

ENT.Model     = "models/inkuton/inkutonmonkey.mdl"
ENT.SeqCourse = "CustomMan_Attack_SSp_Brushscroll_Dash_Loop_Monkey_v01"
ENT.SeqGrimpe = "CustomMan_Attack_SSp_Brushscroll_Ride_Loop_Monkey"
ENT.PCF       = "particles/solve_inkuton_geams.pcf"
ENT.FX_SPAWN  = "solve_inkuton_spawn_dog"
ENT.FX_TRACE  = "solve_inkuton_dog_trace"

ENT.Vitesse   = 420  -- lent : on voit les singes décrire leur arc
ENT.Echelle   = 1
ENT.Hauteur   = 10
ENT.DureeVie  = 6    -- sécurité : au bout de ce temps, il est téléporté sur la cible (il ne la rate jamais)
ENT.RayonAccroche = 12   -- distance à l'axe du corps de la cible une fois accroché (à régler selon le modèle)
ENT.ArcFraction = 0.15   -- hauteur de l'arc = cette part de la distance...
ENT.ArcMax      = 90     -- ...au plus ce nombre d'unités

if SERVER then
    game.AddParticles(ENT.PCF)
    PrecacheParticleSystem(ENT.FX_SPAWN)
    PrecacheParticleSystem(ENT.FX_TRACE)

    local function Joue(self, nom)
        local seq = self:LookupSequence(nom)
        if seq and seq >= 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
        end
    end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        Joue(self, self.SeqCourse)
        self:SetPos(self:GetPos() + Vector(0, 0, self.Hauteur * self.Echelle))
        self.MortA = CurTime() + self.DureeVie
    end

    function ENT:Accrocher(cible)
        self.Fini = true
        self.Cible = nil
        Joue(self, self.SeqGrimpe)
        self:SetNW2Bool("Accroche", true)   -- le client coupe la traînée
        if NA_SingeAccrocher then NA_SingeAccrocher(self, cible) else self:Remove() end
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Fini then return true end

        local cible = self.Cible
        if not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) then self:Remove() return end

        -- Trajectoire en arc : départ -> position ACTUELLE de la cible (elle peut bouger, il la suit),
        -- avec un bombement vers le haut qui vaut 0 au départ et à l'arrivée.
        -- il vise directement l'endroit où il va se poser sur la cible : pas de saut à l'accrochage
        -- les singes se répartissent autour du torse (un tous les 360/N degrés), à des hauteurs différentes,
        -- tournés vers le corps : AngAccroche est l'orientation LOCALE à la cible une fois accroché
        if not self.Offset then
            local i, n = self.Index or 1, self.Total or 1
            local a = math.rad(i * 360 / n + 30)
            self.Offset = Vector(math.cos(a) * self.RayonAccroche, math.sin(a) * self.RayonAccroche, 25 + (i % 3) * 12)
            self.AngAccroche = Angle(0, math.deg(a) + 180, 0)
        end
        local centre = cible:LocalToWorld(self.Offset)
        self.Depart = self.Depart or self:GetPos()
        self.Dist0  = self.Dist0 or math.max(self.Depart:Distance(centre), 1)
        self.T = (self.T or 0) + FrameTime() * self.Vitesse / self.Dist0

        if self.T >= 1 or CurTime() > self.MortA then
            self:SetPos(centre)
            self:Accrocher(cible)
            return true
        end

        local from = self:GetPos()
        local arc = math.sin(self.T * math.pi) * math.min(self.Dist0 * self.ArcFraction, self.ArcMax)
        local to = LerpVector(self.T, self.Depart, centre) + Vector(0, 0, arc)

        -- jamais sous le sol
        local sol = util.TraceLine({ start = to + Vector(0, 0, 40), endpos = to - Vector(0, 0, 200), mask = MASK_SOLID_BRUSHONLY })
        if sol.Hit then to.z = math.max(to.z, sol.HitPos.z + self.Hauteur * self.Echelle) end

        self:SetPos(to)
        -- orientation lissée : le museau suit la montée puis la descente sans à-coups
        local dir = to - from
        if dir:LengthSqr() > 0.01 then
            self.Ang = LerpAngle(math.min(FrameTime() * 12, 1), self.Ang or dir:Angle(), dir:Angle())
            self:SetAngles(self.Ang)
        end
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        game.AddParticles(self.PCF)
        PrecacheParticleSystem(self.FX_SPAWN)
        PrecacheParticleSystem(self.FX_TRACE)
    end

    function ENT:Think()
        if not self.SpawnFX then
            self.SpawnFX = true
            ParticleEffect(self.FX_SPAWN, self:GetPos(), self:GetAngles())
        end
        if self:GetNW2Bool("Accroche", false) then
            if IsValid(self.Trace) then self.Trace:StopEmission() end
            self.Trace = false
        elseif self.Trace == nil or (self.Trace and not IsValid(self.Trace)) then
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
