--========================================================
-- Raiton : Kirin (entité, SERVEUR + CLIENT)
--
-- Le Kirin (models/raiton/kirin) sort du nuage et fonce en ligne droite vers le point visé, au sol. Une traînée de foudre
-- le suit (affichée par le client). À l'arrivée au sol : particule d'impact, dégâts + étourdissement autour du point.
-- Réglages : sv_raiton_kirin.lua (valeurs par niveau : _na_niveaux_techniques.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Kirin"
ENT.Spawnable = false

ENT.Model       = "models/raiton/lv_kirin.mdl"
ENT.Cible       = Vector(0, 0, 0)   -- point d'impact (au sol)
ENT.Vitesse     = 1800
ENT.Echelle     = 1                 -- taille du modèle (1 = taille d'origine)
ENT.Degats      = 150
ENT.Rayon       = 350
ENT.Stun        = 2
-- Orientation du modèle, relative à la direction du vol (Angle(pitch, yaw, roll)) : réglée dans _na_niveaux_techniques.lua
-- (angle_pitch / angle_yaw / angle_roll). Le modèle est un dragon DEBOUT : tête du côté +Y, dos du côté +Z, bras en X.
-- Angle(0,-90,0) = sa tête (+Y) suit le vol : il pique tête la première vers le sol.
ENT.Orientation = Angle(0, -90, 0)
-- Face au lanceur : le Kirin pivote sur son axe de vol pour montrer son ventre (-Z) au lanceur, son dos (+Z) à l'opposé.
-- Si tu vois son dos : Face = 180 ; de profil : 90 ou -90.
ENT.FaceMoi     = true
ENT.Face        = 0
ENT.Centrer     = true   -- true : le centre du maillage du modèle (pas son origine) est placé au point de départ
-- Mesuré sur la pose figée (animation lv_anims1 à AnimCycle = 0.5, image 37, échelle 1) en calculant la position des
-- sommets avec les os : le centre du dragon est à ~(-110, 19, -15) de l'origine du modèle. Tete = distance origine -> bout
-- du museau (+Y). Si tu changes AnimCycle, ces deux valeurs ne sont plus exactes (la pose bouge beaucoup).
ENT.CentreModele = Vector(-110, 19, -15)
ENT.Tete         = 380
-- lv_kirin a UNE animation (lv_anims1, 74 images, 2,5 s) dont les os se déplacent (la boîte de la séquence est bien plus
-- grande que le maillage de base) : jouée telle quelle, le dragon dérive de côté. AnimCycle = pose figée (0 à 1 ; -1 = animation jouée).
ENT.AnimCycle    = 0.5
-- Mode debug (stat "debug" = 1) : le Kirin reste immobile en l'air à son point de départ, sans impact, pour régler les angles.
ENT.Debug        = false

local TRAINEE = "solve_raiton_kirin_trail"

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetModelScale(self.Echelle, 0)
        self:DrawShadow(false)
        if self.AnimCycle >= 0 then
            self:ResetSequence(0)
            self:SetCycle(self.AnimCycle)
            self:SetPlaybackRate(0)
        else
            self:ResetSequence(0)   -- lv_anims1 jouée normalement
            self:SetPlaybackRate(1)
        end

        self.Dir = Vector(0, 0, -1)   -- toujours droit vers le bas
        local _, ang = LocalToWorld(vector_origin, self.Orientation, vector_origin, self.Dir:Angle())

        local lanceur = self:GetOwner()
        if self.FaceMoi and IsValid(lanceur) then
            local vers = lanceur:GetPos() - self:GetPos()
            vers.z = 0
            local dos = ang:Up()   -- le dos du modèle, à tourner à l'opposé du lanceur
            dos.z = 0
            if vers:LengthSqr() > 1 and dos:LengthSqr() > 0.01 then
                local delta = math.AngleDifference((-vers):Angle().y, dos:Angle().y)
                ang:RotateAroundAxis(self.Dir, (self.Dir.z <= 0 and -delta or delta) + self.Face)   -- rotation autour de l'axe de vol
            end
        end
        self:SetAngles(ang)

        -- l'origine du modèle est à une extrémité (côté tête) : on décale pour que son CENTRE soit au centre du nuage
        if self.Centrer then self:SetPos(self:GetPos() - (self:LocalToWorld(self.CentreModele * self.Echelle) - self:GetPos())) end

        -- descente DROITE : il garde son x / y de départ et s'arrête quand le bout de son museau touche le sol
        local pos = self:GetPos()
        self.Dir   = Vector(0, 0, -1)
        -- Tete x Echelle peut dépasser la hauteur de départ (Echelle 2 : 760) : il serait alors déjà « arrivé » et
        -- s'écraserait instantanément. On garde donc au moins la moitié de la hauteur à parcourir.
        local reste = math.min(self.Tete * self.Echelle, (pos.z - self.Cible.z) * 0.5)
        self.Arret = Vector(pos.x, pos.y, self.Cible.z + reste)
        self:EmitSound("ambient/energy/zap9.wav", 90, 80)
    end

    function ENT:Think()
        -- une entité "anim" n'avance pas son animation toute seule : FrameAdvance à chaque tick (sinon lv_anims1 reste figée)
        if self.AnimCycle < 0 then self:FrameAdvance() end

        if self.Debug then
            self.Mort = self.Mort or CurTime() + 120   -- disparaît seul au bout de 2 minutes (ou au prochain lancement)
            if CurTime() > self.Mort then self:Remove() return end
            if self.AnimCycle < 0 and self:GetCycle() >= 0.98 then self:ResetSequence(0) end   -- animation en boucle
            self:NextThink(CurTime())
            return true
        end
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now

        local pos = self:GetPos()
        local pas = self.Vitesse * dt
        if pos.z - pas <= self.Arret.z then
            self:Impact()
            return true
        end

        self:SetPos(pos + self.Dir * pas)
        self:NextThink(now)
        return true
    end

    function ENT:Impact()
        local lanceur = self:GetOwner()
        local point = self.Cible

        net.Start("raiton_kirin_fx")
            net.WriteBool(false)   -- false = impact au sol, true = nuage
            net.WriteVector(point)
        net.Broadcast()
        sound.Play("ambient/explosions/explode_" .. math.random(1, 5) .. ".wav", point, 95, 110, 1)

        for _, ent in ipairs(ents.FindInSphere(point, self.Rayon)) do
            if ent == lanceur or not (NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur)) then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SHOCK)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            if self.Stun > 0 and NA_Etourdir then NA_Etourdir(ent, self.Stun) end
        end

        self:Remove()
    end
else
    game.AddParticles("particles/solve_raiton.pcf")
    PrecacheParticleSystem(TRAINEE)

    function ENT:Initialize()
        ParticleEffectAttach(TRAINEE, PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end

    function ENT:OnRemove()
        self:StopParticles()
    end
end
