--========================================================
-- Futton : Projectile de vapeur (entité, SERVEUR + CLIENT)
-- Avance tout droit (lancée par sv_futton_projectile.lua). Au premier ennemi touché : dégâts, puis elle disparaît.
-- S'arrête aussi sur un mur ou au bout de sa durée de vie. Aucun autre effet (pas de projection, pas de stun).
-- Particule futon_projectile_geams_vap (particles/futton_projectile_vapeur.pcf, chargée par futton_init.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Projectile de vapeur"
ENT.Spawnable = false

ENT.Degats   = 80
ENT.Rayon    = 30     -- demi-largeur de la zone qui touche
ENT.Vitesse  = 1800
ENT.DureeVie = 2
ENT.FX       = "futon_projectile_geams_vap"   -- copie assombrie

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetAngles():Forward()
    end

    function ENT:Think()
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)
        if now > self.MortA then self:Remove() return true end

        local owner = self:GetOwner()
        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * dt
        local r = self.Rayon

        -- hitbox visible avec developer 1
        if now >= (self.ProchainDebug or 0) and GetConVar("developer"):GetInt() > 0 then
            self.ProchainDebug = now + 0.1
            debugoverlay.Box(to, Vector(-r, -r, 0), Vector(r, r, r * 2), 0.1, Color(120, 255, 200, 25))
        end

        -- un seul test par tick (TraceHull) : ne traverse ni mur ni cible, même à grande vitesse
        local tr = util.TraceHull({
            -- hitbox remontée : plus rien sous la ligne de visée, le projectile ne racle plus le sol
            start = from, endpos = to, mins = Vector(-r, -r, 0), maxs = Vector(r, r, r * 2),
            filter = function(ent) return ent ~= self and ent ~= owner and (ent:IsWorld() or EstCible(ent, owner)) end,
            mask = MASK_SHOT_HULL,
        })
        if tr.Hit then
            if EstCible(tr.Entity, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BURN)
                dmg:SetDamagePosition(tr.HitPos)
                tr.Entity:TakeDamageInfo(dmg)
            end
            self:Remove()
            return true
        end

        self:SetPos(to)
        return true
    end
end

if CLIENT then
    function ENT:Think()
        if self.Fx == nil or (self.Fx and not IsValid(self.Fx)) then
            self.Fx = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW) or false
        end
        self:SetNextClientThink(CurTime() + 0.5)   -- la particule est créée une fois
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if IsValid(self.Fx) then self.Fx:StopEmission() end
    end
end
