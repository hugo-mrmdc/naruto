--========================================================
-- Bakuton : Mignon d'argile (entité, SERVEUR + CLIENT)
-- Court au sol (anim mignon_run_base_c) vers la cible, comme les serpents d'encre : virage à vitesse
-- limitée (ROTATION), un mur l'arrête. Au contact il explose (particules de Shibuki).
--========================================================

AddCSLuaFile()

game.AddParticles("particles/bigboom.pcf")
PrecacheParticleSystem("ExplosionCore_MidAir")

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Mignon d'argile"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

-- Valeurs par défaut ; la technique les remplace au lancement (sv_bakuton_mignons.lua)
ENT.Vitesse     = 450
ENT.Rotation    = 220    -- degrés par seconde
ENT.Degats      = 50
ENT.Rayon       = 130
ENT.DureeVie    = 4
ENT.Echelle     = 1      -- ajuster si le mignon est trop gros / petit
ENT.RayonTouche = 45
ENT.Detection   = 500    -- rayon dans lequel il repère un ennemi quand il n'a pas de cible
ENT.DecalageYaw = 0      -- si le modèle ne court pas par son avant : essayer 90, -90 ou 180
ENT.Anim        = "mignon_run_base_c"
ENT.Son         = "bakuton/solve_bakuton_explosion.wav"

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/bakuton/atg_mignon_argile.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.MortA = CurTime() + self.DureeVie
        self.Cap = self:GetAngles().y
        local id = self:LookupSequence(self.Anim)
        if id >= 0 then self:ResetSequence(id) end
    end

    function ENT:Exploser()
        if self.Fini then return end
        self.Fini = true
        local pos, owner = self:GetPos() + Vector(0, 0, 20), self:GetOwner()
        ParticleEffect("ExplosionCore_MidAir", pos, angle_zero)
        sound.Play(self.Son, pos, 85, 100, 1)
        for _, ent in ipairs(ents.FindInSphere(pos, self.Rayon)) do
            if EstCible(ent, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats * (1 - math.Clamp(ent:WorldSpaceCenter():Distance(pos) / self.Rayon, 0, 1) * 0.5))
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)
            end
        end
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Fini then return true end
        if CurTime() > self.MortA then self:Exploser() return true end

        local dt = FrameTime()
        local from = self:GetPos()
        local owner = self:GetOwner()

        -- plus de cible : il avance tout droit et en cherche une toutes les 0,1 s
        if not EstCible(self.Cible, owner) then
            self.Cible = nil
            if CurTime() >= (self.ProchaineRecherche or 0) then
                self.ProchaineRecherche = CurTime() + 0.1
                self.Cible = NA_InkutonChercher and NA_InkutonChercher(from, owner, self.Detection)
            end
        end

        local cible = self.Cible
        if cible then
            local vers = cible:GetPos() - from
            local plat = Vector(vers.x, vers.y, 0):Length()
            if plat < self.RayonTouche * self.Echelle and math.abs(cible:WorldSpaceCenter().z - from.z) < 90 then
                self:Exploser()
                return true
            end
            local voulu = vers:Angle().y
            -- de près : virage immédiat, sinon son rayon de virage (vitesse / rotation) dépasse la distance
            -- de contact et il tourne en rond autour de la cible
            if plat < self.Vitesse * 0.3 then
                self.Cap = voulu
            else
                self.Cap = self.Cap + math.Clamp(math.AngleDifference(voulu, self.Cap), -self.Rotation * dt, self.Rotation * dt)
            end
        end

        local to = from + Angle(0, self.Cap, 0):Forward() * self.Vitesse * dt
        if util.TraceHull({
            start = from + Vector(0, 0, 20), endpos = to + Vector(0, 0, 20),
            mins = Vector(-8, -8, -8), maxs = Vector(8, 8, 8), mask = MASK_SOLID_BRUSHONLY, filter = self,
        }).Hit then self:Exploser() return true end

        -- reste collé au sol, tombe s'il n'y en a pas
        to.z = from.z
        local sol = util.TraceLine({ start = to + Vector(0, 0, 40), endpos = to - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
        local solZ = sol.Hit and sol.HitPos.z or -math.huge
        if to.z - solZ > 20 then
            self.VZ = (self.VZ or 0) - 1500 * dt
            to.z = math.max(from.z + self.VZ * dt, solZ)
            if to.z == solZ then self.VZ = 0 end
        else
            to.z = solZ
            self.VZ = 0
        end

        self:SetPos(to)
        self:SetAngles(Angle(0, self.Cap + self.DecalageYaw, 0))
        return true
    end
end

if CLIENT then
    function ENT:Draw()
        self:DrawModel()
    end
end
