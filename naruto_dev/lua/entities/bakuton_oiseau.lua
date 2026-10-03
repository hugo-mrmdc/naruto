--========================================================
-- Bakuton : Oiseau explosif (entité, SERVEUR + CLIENT)
-- Au repos il flotte derrière le lanceur à gauche (Slot). Tiré, il vole droit (anim Fly) et explose
-- au contact d'un ennemi ou d'un mur (particules de Shibuki). Contrôlé par sv_bakuton_oiseaux.lua.
--========================================================

AddCSLuaFile()

game.AddParticles("particles/bigboom.pcf")
PrecacheParticleSystem("ExplosionCore_MidAir")

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Oiseau explosif"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true

ENT.Slot, ENT.Nb = 1, 1
ENT.Degats      = 40
ENT.Rayon       = 130
ENT.Vitesse     = 1000
ENT.DureeVie    = 4
ENT.RayonTouche = 40
ENT.Echelle     = 0.4        -- ajuster si l'oiseau est trop gros / petit
ENT.DecalageYaw = 0        -- si le modèle ne vole pas par son avant : essayer 90, -90 ou 180
ENT.Son         = "bakuton/solve_bakuton_explosion.wav"

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/bakuton/bid_deidara_solve.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        local id = self:LookupSequence("Fly")
        if id >= 0 then self:ResetSequence(id) end
    end

    function ENT:Tirer(dir)
        self.Tire = true
        self.Dir = dir
        self.MortA = CurTime() + self.DureeVie
        self:SetAngles(dir:Angle() + Angle(0, self.DecalageYaw, 0))
    end

    function ENT:Exploser()
        local pos, owner = self:GetPos(), self:GetOwner()
        ParticleEffect("ExplosionCore_MidAir", pos, angle_zero)
        sound.Play(self.Son, pos, 85, 100, 1)
        for _, ent in ipairs(ents.FindInSphere(pos, self.Rayon)) do
            if EstCible(ent, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
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
        local owner = self:GetOwner()

        if self.Tire then
            if CurTime() > self.MortA then self:Exploser() return true end
            local from = self:GetPos()
            local to = from + self.Dir * self.Vitesse * FrameTime()
            if util.TraceLine({ start = from, endpos = to, mask = MASK_SOLID_BRUSHONLY }).Hit then self:Exploser() return true end
            -- 20 fois par seconde suffit : FindInSphere à chaque tick coûte cher
            if CurTime() >= (self.ProchainContact or 0) then
                self.ProchainContact = CurTime() + 0.05
                for _, ent in ipairs(ents.FindInSphere(to, self.RayonTouche)) do
                    if EstCible(ent, owner) then self:Exploser() return true end
                end
            end
            self:SetPos(to)
            return true
        end

        if not IsValid(owner) or not owner:Alive() then self:Remove() return true end
        -- derrière à gauche, étagés en hauteur, avec un léger balancement
        local ang = Angle(0, owner:EyeAngles().y, 0)
        local cible = owner:GetPos() + ang:Forward() * -45 - ang:Right() * (45 + (self.Slot - 1) * 15)
            + Vector(0, 0, 70 + (self.Slot - 1) * 18 + math.sin(CurTime() * 3 + self.Slot) * 4)
        self:SetPos(LerpVector(math.min(FrameTime() * 10, 1), self:GetPos(), cible))
        self:SetAngles(ang + Angle(0, self.DecalageYaw, 0))
        return true
    end
end

if CLIENT then
    -- éclairage fixe : sinon le modèle devient noir à l'ombre
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.8, 0.8, 0.8)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
