--========================================================
-- Boule de roche (entité projectile, SERVEUR + CLIENT)
--
-- Une boule de roche (models/nature/doton/izoxdoton_ball.mdl) qui file en ligne droite.
-- Le serveur teste sa trajectoire à chaque tick (TraceHull, comme une balle) : elle ne
-- traverse ni les murs ni les cibles. À l'impact : dégâts + projection de la cible touchée.
-- L'affichage est le modèle lui-même, vu par tout le monde.
--
-- Les valeurs viennent de la technique (sv_doton_pierre.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Boule de roche"
ENT.Spawnable = false

ENT.Model = "models/nature/doton/izoxdoton_ball.mdl"
ENT.Centre = Vector(1, 17, 132)   -- centre du modèle par rapport à son origine (l'origine est 130 unités sous la boule)
ENT.FX_IMPACT = "atg_boule_roche_explo"   -- particles/atg_particules3.pcf (chargé par sv_ / cl_doton_pierre.lua)

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse   = 1300
ENT.Degats    = 40
ENT.DureeVie  = 2
ENT.Rayon     = 22    -- demi-largeur de la zone qui touche (à l'horizontale)
ENT.RayonHaut = 22    -- demi-hauteur de la zone qui touche
ENT.Echelle   = 0.45  -- taille du modèle (1 = boule de ~94 unités de large)
ENT.Recul     = 500   -- projection de la cible touchée, dans le sens du tir
ENT.Souleve   = 200   -- projection vers le haut

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        self.Nee = CurTime()
        self.MortA = self.Nee + self.DureeVie
        self.Dir = self.Direction or self:GetForward()
        self:SetAngles(angle_zero)   -- la boule ne tourne pas : orientation fixe dès le spawn
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit, owner = tr.Entity, self:GetOwner()
        if IsValid(hit) and hit ~= owner and (hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot()) then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            dmg:SetDamagePosition(tr.HitPos)
            hit:TakeDamageInfo(dmg)

            local vel = self.Dir * self.Recul + Vector(0, 0, self.Souleve)
            if hit.loco then
                hit.loco:SetVelocity(hit.loco:GetVelocity() + vel)   -- NextBot
            else
                hit:SetVelocity(vel)
            end
        end

        -- la particule se joue AU SOL, sous le point d'impact (300 unités au plus)
        local sol = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 10), endpos = tr.HitPos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        ParticleEffect(self.FX_IMPACT, sol.Hit and sol.HitPos or tr.HitPos, angle_zero)
        sound.Play("physics/concrete/concrete_break" .. math.random(2, 3) .. ".wav", tr.HitPos, 80, math.random(90, 110), 1)
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end
        if CurTime() > self.MortA then self:Remove() return end

        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * FrameTime()
        local r, h = self.Rayon, self.RayonHaut

        local tr = util.TraceHull({
            start = from, endpos = to,
            mins = Vector(-r, -r, -h), maxs = Vector(r, r, h),
            filter = { self, self:GetOwner() },
            mask = MASK_SHOT,
        })

        if tr.Hit then
            self:SetPos(tr.HitPos)
            self:Impact(tr)
            return
        end

        self:SetPos(to)
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    -- l'origine du modèle est loin sous la boule : on le dessine décalé pour que SON CENTRE tombe sur
    -- la position de l'entité (= la hitbox), même quand il roule
    -- + éclairage fixe : sinon la boule devient noire dans les zones sombres (ou près d'un mur)
    function ENT:Draw()
        local decalage = LocalToWorld(self.Centre * self:GetModelScale(), angle_zero, vector_origin, self:GetAngles())
        self:SetRenderOrigin(self:GetPos() - decalage)
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.55, 0.55, 0.55)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        self:DrawModel()
        render.SuppressEngineLighting(false)
        self:SetRenderOrigin()
    end
end
