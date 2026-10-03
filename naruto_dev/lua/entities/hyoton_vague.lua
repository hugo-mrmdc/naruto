--========================================================
-- Hyoton : Vague de glace (entité, SERVEUR + CLIENT)
-- Un bouquet de pics (models/hyoton/spike_floor_geams.mdl) qui avance tout droit au ras du sol, comme un projectile
-- (lancé par sv_hyoton_vague.lua). Au premier ennemi touché : dégâts + court étourdissement, puis il disparaît.
-- S'arrête aussi sur un mur ou au bout de sa durée de vie. La particule izox_hyoton_hit est jouée régulièrement
-- (message "hyoton_pics_touche", cl_hyoton_pics.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Vague de glace"
ENT.Spawnable = false

ENT.Degats   = 50
ENT.Stun     = 1
ENT.Rayon    = 60     -- demi-largeur de la zone qui touche
ENT.Vitesse  = 900
ENT.DureeVie = 1.5
ENT.Echelle  = 0.5    -- le modèle fait ~280 unités de large à l'échelle 1
ENT.DecalageYaw = 135  -- le modèle est en diagonale : ce décalage le met face à l'avant (testé : -45 = face au lanceur)
ENT.Enfonce  = 52     -- 72 = le bas du modèle (à l'échelle 1) pile sur le sol ; plus petit = plus enfoncé dans le sol
ENT.DecalageFX = 60   -- unités dont la particule est descendue sous le sol pour qu'elle cache moins les pics

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/hyoton/spike_floor_geams.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetAngles():Forward()
        self.Dir.z = 0
        self.Dir:Normalize()
        self:SetAngles(Angle(0, self.Dir:Angle().y + self.DecalageYaw, 0))
        self.Sol = self:GetPos()   -- point au sol
    end

    function ENT:Think()
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)
        if now > self.MortA then self:Remove() return true end

        local owner = self:GetOwner()
        local r = self.Rayon
        local from = self.Sol
        local to = from + self.Dir * self.Vitesse * dt
        local h = Vector(r, r, 30)

        local tr = util.TraceHull({
            start = from + Vector(0, 0, 40), endpos = to + Vector(0, 0, 40), mins = -h, maxs = h,
            filter = function(ent) return ent ~= self and ent ~= owner and (ent:IsWorld() or EstCible(ent, owner)) end,
            mask = MASK_SHOT_HULL,
        })

        if now >= (self.ProchainFx or 0) or tr.Hit then
            self.ProchainFx = now + 0.15
            net.Start("hyoton_pics_touche")
            net.WriteVector((tr.Hit and tr.HitPos or to) - Vector(0, 0, self.DecalageFX))
            net.Broadcast()
        end

        if tr.Hit then
            if EstCible(tr.Entity, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_GENERIC)
                dmg:SetDamagePosition(tr.HitPos)
                tr.Entity:TakeDamageInfo(dmg)
                if self.Stun > 0 and NA_Etourdir then NA_Etourdir(tr.Entity, self.Stun) end
            end
            self:Remove()
            return true
        end

        -- suit le relief
        local sol = util.TraceLine({ start = to + Vector(0, 0, 100), endpos = to - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if not sol.Hit then self:Remove() return true end   -- plus de sol (vide)
        self.Sol = sol.HitPos
        self:SetPos(sol.HitPos + Vector(0, 0, self.Enfonce * self.Echelle))
        return true
    end
end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end
