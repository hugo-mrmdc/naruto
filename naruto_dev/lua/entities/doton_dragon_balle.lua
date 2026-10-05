--========================================================
-- Doton : projectile du Dragon de terre (entité, SERVEUR + CLIENT)
--
-- Projectile de pierre (models/nature/doton/doton_bullet_01) tiré par le dragon (doton_dragon.lua). Il avance droit
-- devant lui ; au premier ennemi touché : dégâts ; il disparaît aussi sur un mur ou au bout de sa durée de vie.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Projectile du dragon de terre"
ENT.Spawnable = false

ENT.Model   = "models/nature/doton/doton_bullet_01.mdl"
ENT.Degats  = 25
ENT.Vitesse = 1600
ENT.Rayon   = 22       -- demi-largeur de la zone qui touche
ENT.Vie     = 2.5      -- secondes avant qu'il disparaisse sans rien toucher
ENT.Echelle = 1.2      -- le modèle fait ~77 de long à l'échelle 1
-- Orientation du modèle : comme le dragon (même export), son axe avant est probablement +y et non +x : on le tourne de
-- 90 degrés pour que la pointe suive la direction du tir (-90 la faisait regarder vers le lanceur). Si le projectile est de travers : essayer 0 ou 180.
ENT.DecalageYaw = 90    -- mesuré en jeu : -90 faisait regarder la pointe vers le lanceur, donc +90 (180 de plus)

if SERVER then
    local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetModelScale(self.Echelle, 0)
        self:DrawShadow(false)
        self.Mort = CurTime() + self.Vie
        self.Dir  = self.Dir or self:GetAngles():Forward()
        self:SetAngles(Angle(0, self.Dir:Angle().y + self.DecalageYaw, 0))   -- le MODÈLE est tourné ; self.Dir reste la vraie direction
    end

    function ENT:Think()
        local now = CurTime()
        local lanceur = self:GetOwner()
        if now >= self.Mort then self:Remove() return end

        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now

        local depart = self:GetPos()
        local arrivee = depart + self.Dir * self.Vitesse * dt
        local r = self.Rayon

        if GetConVar("developer"):GetInt() > 0 then
            debugoverlay.Box(arrivee, Vector(-r, -r, -r), Vector(r, r, r), 0.1, Color(200, 140, 60, 25))
        end

        local dragon = self.Dragon
        local tr = util.TraceHull({
            start = depart, endpos = arrivee,
            mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
            filter = function(e) return e ~= self and e ~= lanceur and e ~= dragon and (e:IsWorld() or EstCible(e, lanceur)) end,
            mask = MASK_SHOT_HULL,
        })

        if tr.Hit then
            if EstCible(tr.Entity, lanceur) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_CRUSH)
                dmg:SetDamagePosition(tr.HitPos)
                tr.Entity:TakeDamageInfo(dmg)
            end
            self:EmitSound("naruto_sound/jutsu/doton/earth13.wav", 75, math.random(80, 110))
            self:Remove()
            return true
        end

        self:SetPos(arrivee)
        self:NextThink(now)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        util.PrecacheModel(self.Model)
    end

    -- éclairage fixe (même raison que le dragon)
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.8, 0.8, 0.8)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
