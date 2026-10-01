--========================================================
-- Bakuton : Araignée explosive (entité, SERVEUR + CLIENT)
-- Sort du lanceur, court au sol vers la cible, s'y accroche (la première arrivée l'étourdit, comme le cube
-- Jinton), puis explose quand l'étourdissement se termine (particules de Shibuki).
--========================================================

AddCSLuaFile()

game.AddParticles("particles/bigboom.pcf")
PrecacheParticleSystem("ExplosionCore_MidAir")

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Araignée explosive"
ENT.Spawnable = false

-- Valeurs par défaut ; la technique les remplace au lancement (sv_bakuton_araignees.lua)
ENT.Vitesse     = 600
ENT.Degats      = 15     -- à l'explosion, sur la cible seulement
ENT.Duree       = 2      -- durée du stun
ENT.Echelle     = 1      -- ajuster si l'araignée est trop grosse / petite
ENT.RayonTouche = 40
ENT.DureeVie    = 4      -- temps max pour atteindre la cible
ENT.Index, ENT.Total = 1, 1   -- place de l'araignée parmi celles lancées (répartition sur le corps)
ENT.Inclinaison = 0      -- bascule des pattes vers le corps (si elles flottent : essayer 60 ou -60)
ENT.DecalageYaw = 0      -- si le modèle n'avance pas par son avant : essayer 90, -90 ou 180
ENT.Son         = "bakuton/solve_bakuton_explosion.wav"

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/bakuton/atg_araignee_bakuton.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.MortA = CurTime() + self.DureeVie
        -- place sur le corps de la cible : réparties en spirale (angle d'or) du bas vers le haut
        local cible = self.Cible
        local mins, maxs = vector_origin, Vector(0, 0, 72)
        if IsValid(cible) then mins, maxs = cible:OBBMins(), cible:OBBMaxs() end
        local rayon = math.max(maxs.x, maxs.y) * 0.9
        local yaw = self.Index * 137.5
        self.Decalage = Angle(0, yaw, 0):Forward() * rayon
        self.Decalage.z = mins.z + (maxs.z - mins.z) * (0.1 + 0.8 * (self.Index - 0.5) / self.Total)
        local id = self:LookupSequence("idle")
        if id >= 0 then self:ResetSequence(id) end
    end

    function ENT:Exploser()
        if self.Fini then return end
        self.Fini = true
        local cible, owner = self.Cible, self:GetOwner()
        local pos = self:GetPos()
        ParticleEffect("ExplosionCore_MidAir", pos, angle_zero)
        sound.Play(self.Son, pos, 75, math.random(95, 110), 1)
        if IsValid(cible) then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(pos)
            cible:TakeDamageInfo(dmg)
        end
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Fini then return true end
        local cible = self.Cible
        if not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) or (cible:IsNPC() and cible:Health() <= 0) then
            self:Remove() return true
        end

        -- accrochée : suit la cible jusqu'à la fin du stun, puis explose
        if self.Accrochee then
            if CurTime() >= (cible.BakutonStunFin or 0) then self:Exploser() return true end
            -- glisse vers sa place puis reste collée au corps, avec un léger frétillement
            local but = cible:GetPos() + self.Decalage + Vector(0, 0, math.sin(CurTime() * 8 + self.Index) * 1.5)
            self:SetPos(LerpVector(math.min(FrameTime() * 15, 1), self:GetPos(), but))
            self:SetAngles(Angle(self.Inclinaison, self.Decalage:Angle().y + self.DecalageYaw, 0))
            return true
        end

        if CurTime() > self.MortA then self:Remove() return true end

        local dt = FrameTime()
        local from = self:GetPos()
        local vers = cible:GetPos() - from
        if Vector(vers.x, vers.y, 0):Length() < self.RayonTouche and math.abs(cible:WorldSpaceCenter().z - from.z) < 90 then
            self.Accrochee = true
            -- la première arrivée étourdit ; les suivantes s'accrochent jusqu'à la même fin
            if (cible.BakutonStunFin or 0) <= CurTime() then
                cible.BakutonStunFin = CurTime() + self.Duree
                if NA_Etourdir then NA_Etourdir(cible, self.Duree) end   -- sv_etourdissement.lua
            end
            return true
        end

        local cap = vers:Angle().y
        local to = from + Angle(0, cap, 0):Forward() * self.Vitesse * dt
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
        self:SetAngles(Angle(0, cap + self.DecalageYaw, 0))
        return true
    end
end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end
