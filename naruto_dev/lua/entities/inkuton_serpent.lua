--========================================================
-- Inkuton : Serpent d'encre (entité, SERVEUR + CLIENT)
-- Rampe au sol vers la cible visée. Il ne s'accroche pas : un contact = des dégâts, puis il disparaît.
-- Il tourne à vitesse limitée (ROTATION) : il essaie de l'atteindre, une cible qui change vite de
-- direction peut lui échapper. Un mur l'arrête. Le modèle n'a aucune animation : il ondule côté client
-- (os "body ..." / "head neck").
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Serpent d'encre"
ENT.Spawnable = false

ENT.Model     = "models/inkuton/serpentsai.mdl"
ENT.PCF       = "particles/solve_inkuton_geams.pcf"
ENT.FX_SPAWN  = "solve_inkuton_spawn_dog"
ENT.FX_TRACE  = "solve_inkuton_dog_trace"
ENT.FX_HIT    = "solve_inkuton_dog_impact"
ENT.FX_CIBLE  = "nrp_inkuton_big"

-- Valeurs par défaut ; la technique les remplace au lancement (sv_inkuton_serpents.lua)
ENT.Vitesse   = 700
ENT.Rotation  = 220    -- degrés par seconde
ENT.Degats    = 40
ENT.DureeVie  = 3
ENT.Echelle   = 1
ENT.Hauteur   = 4      -- relevé au-dessus du sol
ENT.RayonTouche = 45   -- distance de contact avec la cible
ENT.DecalageYaw = 0    -- si le modèle n'avance pas par son avant : essayer 90, -90 ou 180
ENT.Detection   = 500  -- rayon dans lequel il repère un ennemi quand il n'a pas de cible

local function EstCible(ent, lanceur) return NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

if SERVER then
    game.AddParticles(ENT.PCF)
    for _, fx in ipairs({ ENT.FX_SPAWN, ENT.FX_TRACE, ENT.FX_HIT, ENT.FX_CIBLE }) do PrecacheParticleSystem(fx) end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self:SetPos(self:GetPos() + Vector(0, 0, self.Hauteur))
        self.MortA = CurTime() + self.DureeVie
        self.Cap = self:GetAngles().y
    end

    -- ennemi le plus proche dans le rayon de détection (pas derrière un mur)
    function ENT:ChercherCible()
        return NA_InkutonChercher(self:GetPos(), self:GetOwner(), self.Detection)
    end

    function ENT:Fin(touche)
        if self.Fini then return end
        self.Fini = true
        local owner = self:GetOwner()
        local cible = self.Cible
        if touche and IsValid(cible) then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(cible:WorldSpaceCenter())
            cible:TakeDamageInfo(dmg)
            ParticleEffectAttach(self.FX_CIBLE, PATTACH_ABSORIGIN_FOLLOW, cible, 0)
        end
        ParticleEffect(self.FX_HIT, self:GetPos(), self:GetAngles())
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Fini then return true end

        if CurTime() > self.MortA then self:Fin(false) return true end

        local dt = FrameTime()
        local from = self:GetPos()

        -- pas (ou plus) de cible : il avance tout droit et en cherche une toutes les 0,1 s
        if not EstCible(self.Cible, self:GetOwner()) then
            self.Cible = nil
            if CurTime() >= (self.ProchaineRecherche or 0) then
                self.ProchaineRecherche = CurTime() + 0.1
                self.Cible = self:ChercherCible()
            end
        end

        local cible = self.Cible
        if cible then
            local vers = cible:GetPos() - from

            -- contact avec la cible (à plat, avec une tolérance en hauteur)
            local plat = Vector(vers.x, vers.y, 0):Length()
            if plat < self.RayonTouche * self.Echelle and math.abs(cible:WorldSpaceCenter().z - from.z) < 90 then
                self:Fin(true)
                return true
            end

            -- virage à vitesse limitée vers la cible
            local voulu = vers:Angle().y
            -- de près : virage immédiat, sinon son rayon de virage (vitesse / rotation) est plus grand que la
            -- distance de contact et il tourne en rond autour de la cible
            if plat < self.Vitesse * 0.3 then
                self.Cap = voulu
            else
                self.Cap = self.Cap + math.Clamp(math.AngleDifference(voulu, self.Cap), -self.Rotation * dt, self.Rotation * dt)
            end
        end
        local avant = Angle(0, self.Cap, 0):Forward()
        local to = from + avant * self.Vitesse * dt

        -- un mur l'arrête
        local mur = util.TraceHull({
            start = from + Vector(0, 0, 20), endpos = to + Vector(0, 0, 20),
            mins = Vector(-8, -8, -8), maxs = Vector(8, 8, 8), mask = MASK_SOLID_BRUSHONLY, filter = self,
        })
        if mur.Hit then self:Fin(false) return true end

        -- reste collé au sol, tombe s'il n'y en a pas (même principe que les chiens)
        to.z = from.z
        local sol = util.TraceLine({ start = to + Vector(0, 0, 40), endpos = to - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
        local cibleZ = sol.Hit and sol.HitPos.z + self.Hauteur or -math.huge
        if to.z - cibleZ > 20 then
            self.VZ = (self.VZ or 0) - 1500 * dt
            to.z = math.max(from.z + self.VZ * dt, cibleZ)
            if to.z == cibleZ then self.VZ = 0 end
        else
            to.z = cibleZ
            self.VZ = 0
        end

        self:SetPos(to)
        self:SetAngles(Angle(0, self.Cap + self.DecalageYaw, 0))
        return true
    end
end

if CLIENT then
    -- une seule fois pour le fichier (avant : à chaque apparition, le .pcf était rechargé = micro-freeze)
    game.AddParticles(ENT.PCF)
    for _, fx in ipairs({ ENT.FX_SPAWN, ENT.FX_TRACE }) do PrecacheParticleSystem(fx) end

    function ENT:Initialize() end

    -- ondulation : une onde qui parcourt les os du corps, de la queue à la tête
    function ENT:Ondule()
        local t = CurTime() * 10
        for i = 0, self:GetBoneCount() - 1 do
            local nom = self:GetBoneName(i) or ""
            if nom:find("body", 1, true) or nom:find("head neck", 1, true) then
                self:ManipulateBoneAngles(i, Angle(0, math.sin(t - i * 0.9) * 18, 0))
            end
        end
    end

    function ENT:Think()
        if not self.SpawnFX then
            self.SpawnFX = true
            ParticleEffect(self.FX_SPAWN, self:GetPos(), self:GetAngles())
        end
        self:Ondule()
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        self:DrawModel()
    end
end
