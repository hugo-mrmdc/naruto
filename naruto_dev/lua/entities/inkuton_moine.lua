--========================================================
-- Inkuton : Moine d'encre (entité, SERVEUR)
-- Suit son lanceur (marche de près, court de loin) et frappe l'ennemi le plus proche à portée.
-- Le bouclier (self.Bouclier, en PV) est consommé par sv_inkuton_moine.lua : à 0, le moine disparaît.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Moine d'encre"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

ENT.Model   = "models/inkuton/inkutonmonk.mdl"
ENT.SeqIdle = "Idle"
ENT.SeqWalk = "Walk"
ENT.SeqRun  = "Run"
ENT.SeqAtt  = { "CustomMan_Attack_SSp_Brushscroll_cmb_06_Monk", "CustomMan_Attack_SSp_Brushscroll_cmb_04_Monk" }

ENT.Bouclier = 0
ENT.Degats   = 20
ENT.Portee   = 200    -- rayon (autour du moine) où il repère un ennemi
ENT.DureeVie = 20
ENT.VitMarche, ENT.VitCourse = 200, 550
ENT.SeuilCourse = 250  -- au-delà de cette vitesse (unités/s) il passe de l'anim marche à course
ENT.Suivi = Vector(-40, 60, 0)   -- place voulue par rapport au lanceur (arrière, droite)
ENT.PauseCoups  = 0.3
ENT.InstantCoup = 0.4  -- part de l'animation où le coup touche

if CLIENT then
    local PCF, FX, FX_SPAWN = "particles/solve_inkuton_geams.pcf", "solve_inkuton_dispawn_moine", "solve_inkuton_moine_spawn_trap"
    local FX_RUSH, DUREE_SPAWN = "solve_inkuton_moine_rush", 1   -- l'effet d'apparition reste 1 s collé au moine
    local PCF_IMPACT, FX_IMPACT = "particles/patlick_atgparticules.pcf", "golem_encre_impact_pat"

    function ENT:Initialize()
        game.AddParticles(PCF)
        PrecacheParticleSystem(FX)
        PrecacheParticleSystem(FX_SPAWN)
        PrecacheParticleSystem(FX_RUSH)
        game.AddParticles(PCF_IMPACT)
        PrecacheParticleSystem(FX_IMPACT)
    end

    -- au premier tick (la position est alors à jour, contrairement à Initialize)
    function ENT:Think()
        if not self.SpawnFX then
            self.SpawnFX = true
            self.FinSpawn = CurTime() + DUREE_SPAWN
            self.FxSpawn = CreateParticleSystem(self, FX_SPAWN, PATTACH_ABSORIGIN_FOLLOW)
        end
        if self.FxSpawn and CurTime() > self.FinSpawn then
            if IsValid(self.FxSpawn) then self.FxSpawn:StopEmission() end
            self.FxSpawn = nil
        end
        -- traînée derrière lui tant qu'il court
        if self:GetNW2Bool("Court", false) then
            if not IsValid(self.Rush) then self.Rush = CreateParticleSystem(self, FX_RUSH, PATTACH_ABSORIGIN_FOLLOW) end
        elseif IsValid(self.Rush) then
            self.Rush:StopEmission()
            self.Rush = nil
        end
        -- le serveur incrémente "Impact" à chaque coup et donne l'endroit touché
        local n = self:GetNW2Int("Impact", 0)
        if n ~= self.Impact then
            if self.Impact then ParticleEffect(FX_IMPACT, self:GetNW2Vector("ImpactPos"), angle_zero) end
            self.Impact = n
        end
    end

    -- éclairage fixe : sinon le modèle (VertexlitGeneric + lightwarp) devient noir à l'ombre ou contre le sol
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.8, 0.8, 0.8)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end

    -- fullUpdate : le moine sort juste du champ de vision, il n'a pas disparu
    function ENT:OnRemove(fullUpdate)
        if IsValid(self.FxSpawn) then self.FxSpawn:StopEmission() end
        if IsValid(self.Rush) then self.Rush:StopEmission() end
        if not fullUpdate then ParticleEffect(FX, self:GetPos(), self:GetAngles()) end
    end
end

if SERVER then
    -- force = false : un changement de déplacement (idle/marche/course) attend 0,4 s après le précédent,
    -- sinon l'animation repart de zéro à chaque va-et-vient autour d'un seuil
    local function Joue(self, nom, force)
        if self.Anim == nom then return end
        if not force and CurTime() < (self.VerrouAnim or 0) then return end
        self.VerrouAnim = CurTime() + 0.4
        local seq = self:LookupSequence(nom)
        if seq and seq >= 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
            self.Anim = nom
        end
    end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(true)
        self.MortA = CurTime() + self.DureeVie
        self.Yaw = self:GetAngles().y
        self.Coup = 0
        Joue(self, self.SeqIdle, true)
    end

    function ENT:Think()
        self:NextThink(CurTime())
        local ply, now, dt = self:GetOwner(), CurTime(), FrameTime()
        if not IsValid(ply) or not ply:Alive() or now > self.MortA or self.Bouclier <= 0 then self:Remove() return true end

        -- le coup part au milieu de l'animation
        if self.Frappe and now >= self.Frappe then
            self.Frappe = nil
            local c = self.Visee
            if IsValid(c) and c:GetPos():DistToSqr(self:GetPos()) < (self.Portee * 1.5) ^ 2 then
                local d = DamageInfo()
                d:SetDamage(self.Degats)
                d:SetAttacker(ply)
                d:SetInflictor(self)
                d:SetDamageType(DMG_SLASH)
                c:TakeDamageInfo(d)
                local p = c:GetPos()   -- l'effet se joue au sol, sous l'ennemi
                self:SetNW2Vector("ImpactPos", util.TraceLine({ start = p + Vector(0, 0, 20), endpos = p - Vector(0, 0, 500), mask = MASK_SOLID_BRUSHONLY }).HitPos)
                self:SetNW2Int("Impact", self:GetNW2Int("Impact", 0) + 1)
            end
        end
        if self.FinAttaque then
            if now < self.FinAttaque then return true end
            self.FinAttaque = nil
        end

        local pos = self:GetPos()

        -- ennemi à portée : on le frappe
        if now >= self.Coup and NA_InkutonChercher then
            local c = NA_InkutonChercher(pos, ply, self.Portee)
            if c then
                self.NumAtt = (self.NumAtt or 0) % #self.SeqAtt + 1   -- alterne cmb_06 / cmb_05
                local seq = self.SeqAtt[self.NumAtt]
                self.Anim = nil
                self.Court = false
                self:SetNW2Bool("Court", false)
                Joue(self, seq, true)
                local dur = self:SequenceDuration()
                self.Visee, self.Frappe = c, now + dur * self.InstantCoup
                self.FinAttaque = now + dur
                self.Coup = self.FinAttaque + self.PauseCoups
                self.Yaw = (c:GetPos() - pos):Angle().y
                self:SetAngles(Angle(0, self.Yaw, 0))
                return true
            end
        end

        -- sinon on reste à côté du lanceur
        local but = ply:GetPos() + Angle(0, ply:EyeAngles().y, 0):Forward() * self.Suivi.x + Angle(0, ply:EyeAngles().y, 0):Right() * self.Suivi.y
        local v = but - pos
        v.z = 0
        local dist = v:Length()
        if dist > 1000 or math.abs(ply:GetPos().z - pos.z) > 250 then
            -- ponytail: téléport si trop loin ou à une autre hauteur (saut d'un toit), pas de pathfinding
            self:SetPos(but)
            pos = self:GetPos()
            self.Vz = 0
        elseif dist > (self.Bouge and 15 or 40) then
            -- hystérésis : sinon l'animation change à chaque tick autour des seuils (arrêt/marche, marche/course)
            self.Bouge = true
            -- vitesse proportionnelle à l'écart : il suit le rythme du lanceur au lieu d'alterner marche/course
            local vit = math.Clamp(dist * 4, 60, self.VitCourse)
            self.Court = vit > self.SeuilCourse
            pos = pos + v:GetNormalized() * math.min(vit * dt, dist)
            self.Yaw = math.ApproachAngle(self.Yaw, v:Angle().y, 720 * dt)
            Joue(self, self.Court and self.SeqRun or self.SeqWalk)
        else
            self.Bouge, self.Court = false, false
            self.Yaw = math.ApproachAngle(self.Yaw, ply:EyeAngles().y, 360 * dt)
            Joue(self, self.SeqIdle)
        end

        -- gravité : monte vite les marches, mais tombe en accélérant dans le vide (pas de vol stationnaire)
        local sol = util.TraceLine({ start = pos + Vector(0, 0, 40), endpos = pos - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
        if sol.Hit then
            local z, gz = self:GetPos().z, sol.HitPos.z
            if gz >= z then
                z, self.Vz = math.Approach(z, gz, 600 * dt), 0
            else
                self.Vz = (self.Vz or 0) + 800 * dt
                z = math.max(gz, z - self.Vz * dt)
                if z == gz then self.Vz = 0 end
            end
            pos.z = z
        end
        self:SetPos(pos)
        self:SetAngles(Angle(0, self.Yaw, 0))
        self:SetNW2Bool("Court", self.Court == true)
        return true
    end
end
