--========================================================
-- Shoton : Roquette de cristal (entité, SERVEUR + CLIENT)
-- Lancée par sv_shoton_rockets.lua : avance tout droit, explose au premier ennemi / mur touché (dégâts de zone)
-- ou au bout de sa durée de vie.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Roquette de cristal"
ENT.Spawnable = false

ENT.Degats    = 60
ENT.Rayon     = 25     -- demi-largeur de la zone qui touche
ENT.Explosion = 120    -- rayon des dégâts de zone
ENT.Vitesse   = 1600
ENT.DureeVie  = 2
-- Le modèle est dressé (long de 195 unités sur son axe Z) : Angle(-90, 0, 0) met cet axe dans le sens du tir, pointe devant.
-- Si la pointe est à l'envers, mettre Angle(90, 0, 0).
ENT.Rotation  = Angle(-90, 0, 0)
ENT.Echelle   = 1

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/shoton/pg_crystal_rocket.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetAngles():Forward()
        self:SetAngles(self.Dir:Angle() + self.Rotation)
    end

    function ENT:Exploser(pos)
        local owner = self:GetOwner()
        for _, e in ipairs(ents.FindInSphere(pos, self.Explosion)) do
            if EstCible(e, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                e:TakeDamageInfo(dmg)
            end
        end
        -- particules posées sur le sol sous l'impact (et pas en l'air)
        local sol = util.TraceLine({ start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
        net.Start("shoton_rocket_boom")
            net.WriteVector(sol.Hit and sol.HitPos or pos)
        net.Broadcast()
        sound.Play("geams/solve_jutsu/shoton/solve_shoton_dragon_start.wav", pos, 80, 120)
        self:Remove()
    end

    function ENT:Think()
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)
        if now > self.MortA then self:Exploser(self:GetPos()) return true end

        local owner, from = self:GetOwner(), self:GetPos()
        local to = from + self.Dir * self.Vitesse * dt
        local r = self.Rayon
        local tr = util.TraceHull({
            start = from, endpos = to, mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
            filter = function(ent) return ent ~= self and ent ~= owner and (ent:IsWorld() or EstCible(ent, owner)) end,
            mask = MASK_SHOT_HULL,
        })
        if tr.Hit then self:Exploser(tr.HitPos) return true end

        self:SetPos(to)
        return true
    end
end
