--========================================================
-- Bakuton : Bombe d'argile géante (entité, SERVEUR + CLIENT)
-- Tombe du ciel (lâchée par sv_bakuton_bombe.lua) et explose à l'impact : mêmes particules que les autres
-- Bakuton (ExplosionCore_MidAir), mais lancées en grappe pour couvrir tout le rayon.
--========================================================

AddCSLuaFile()

game.AddParticles("particles/bigboom.pcf")
PrecacheParticleSystem("ExplosionCore_MidAir")

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Bombe d'argile"
ENT.Spawnable = false

ENT.Degats       = 150
ENT.Rayon        = 700
ENT.Echelle      = 20       -- le modèle fait ~40 unités : ajuster si la bombe est trop grosse / petite
ENT.VitesseDepart = 800
ENT.Gravite      = 2200     -- accélération de chute (unités/s²)
ENT.VitesseMax   = 3500
ENT.DureeVie     = 12
ENT.Son          = "bakuton/solve_bakuton_explosion.wav"

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/bakuton/bomb_bakuton_solve_custom.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle * self.Rayon / 700, 0)   -- la taille suit le rayon
        self:SetAngles(Angle(0, math.random(0, 359), 0))
        self.Vitesse = self.VitesseDepart
        self.MortA = CurTime() + self.DureeVie
        self:EmitSound("geams/solve_jutsu/bakuton/solve_bakuton_bigexplosion.wav", 90, 70, 1)
    end

    -- grappe de particules : centre, anneau au sol, colonne qui monte (décalées dans le temps)
    local function Particules(pos, rayon)
        local function Boum(p, delai)
            timer.Simple(delai, function() ParticleEffect("ExplosionCore_MidAir", p, angle_zero) end)
        end
        Boum(pos, 0)
        for i = 0, 7 do
            local a = math.rad(i * 45)
            Boum(pos + Vector(math.cos(a), math.sin(a), 0) * rayon * 0.55, 0.05)
        end
        for i = 0, 11 do
            local a = math.rad(i * 30 + 15)
            Boum(pos + Vector(math.cos(a), math.sin(a), 0) * rayon * 0.95, 0.12)
        end
        for i = 0, 15 do
            local a = math.rad(i * 22.5)
            Boum(pos + Vector(math.cos(a), math.sin(a), 0) * rayon * 0.3, 0.03)
            Boum(pos + Vector(math.cos(a), math.sin(a), 0) * rayon * 0.75, 0.09)
        end
        for h = 1, 8 do
            Boum(pos + Vector(math.Rand(-100, 100), math.Rand(-100, 100), h * rayon * 0.3), 0.06 * h)
            Boum(pos + Vector(math.Rand(-200, 200), math.Rand(-200, 200), h * rayon * 0.22), 0.08 * h)
        end
    end

    function ENT:Exploser(pos)
        pos = pos or self:GetPos()
        local owner = self:GetOwner()
        self:StopSound("geams/solve_jutsu/bakuton/solve_bakuton_bigexplosion.wav")

        Particules(pos, self.Rayon)
        sound.Play(self.Son, pos, 140, 70, 1)
        sound.Play(self.Son, pos, 140, 90, 1)
        util.ScreenShake(pos, 25, 40, 2.5, self.Rayon * 6)

        for _, ent in ipairs(ents.FindInSphere(pos, self.Rayon)) do
            if EstCible(ent, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                dmg:SetDamageForce((ent:WorldSpaceCenter() - pos):GetNormalized() * 30000 + Vector(0, 0, 8000))
                ent:TakeDamageInfo(dmg)
            end
        end
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if CurTime() > self.MortA then self:Exploser() return true end

        local dt = FrameTime()
        self.Vitesse = math.min(self.Vitesse + self.Gravite * dt, self.VitesseMax)
        local from = self:GetPos()
        local to = from - Vector(0, 0, self.Vitesse * dt)

        -- impact : sol, mur, ou un joueur / PNJ en travers (le lanceur est ignoré)
        local tr = util.TraceHull({
            start = from, endpos = to - Vector(0, 0, 40),
            mins = Vector(-100, -100, -20), maxs = Vector(100, 100, 20),
            filter = { self, self:GetOwner() }, mask = MASK_SOLID,
        })
        if tr.Hit then self:Exploser(tr.HitPos) return true end

        self:SetPos(to)
        self:SetAngles(self:GetAngles() + Angle(0, 90 * dt, 0))
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
