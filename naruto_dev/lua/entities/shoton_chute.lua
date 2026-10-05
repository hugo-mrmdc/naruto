--========================================================
-- Shoton : Chute de cristal (entité, SERVEUR + CLIENT)
-- Lancée par sv_shoton_chute.lua : un gros cristal (solve_crystal02_kg_geams) tombe du ciel, accélère, et à l'impact
-- (sol, mur ou ennemi) fait des dégâts de zone avec les mêmes particules que l'impact des roquettes Shoton
-- (réseau "shoton_rocket_boom", cl_shoton_rockets.lua). Il reste planté 1 s puis disparaît en rapetissant.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Chute de cristal"
ENT.Spawnable = false

ENT.Degats    = 120
ENT.Rayon     = 40      -- demi-largeur de la zone qui touche en tombant
ENT.Explosion = 150     -- rayon des dégâts de zone
ENT.Stun      = 0.8     -- léger étourdissement des ennemis touchés (secondes, 0 = aucun)
ENT.Vitesse   = 900     -- vitesse de départ (unités/s)
ENT.Gravite   = 2500    -- accélération (unités/s²)
ENT.Suivi_Vitesse = 700  -- vitesse horizontale à laquelle il suit l'ennemi visé pendant la chute (unités/s)
ENT.Echelle   = 0.8     -- le modèle fait ~360 unités de haut à l'échelle 1 : ajuster si trop gros / petit
-- Le modèle est dressé : Angle(180, 0, 0) met sa pointe vers le bas (si c'est l'inverse, mettre Angle(0, 0, 0))
ENT.Rotation  = Angle(180, 0, 0)

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/shoton/solve_crystal02_kg_geams.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self:SetAngles(self.Rotation + Angle(0, math.random(0, 359), 0))
        self.V = self.Vitesse
    end

    function ENT:Impact(pos)
        local owner = self:GetOwner()
        for _, e in ipairs(ents.FindInSphere(pos, self.Explosion)) do
            if EstCible(e, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_CRUSH)
                dmg:SetDamagePosition(pos)
                e:TakeDamageInfo(dmg)
                if self.Stun > 0 and NA_Etourdir then NA_Etourdir(e, self.Stun) end
            end
        end
        -- mêmes particules que l'impact des roquettes, posées sur le sol
        local sol = util.TraceLine({ start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
        net.Start("shoton_rocket_boom")
            net.WriteVector(sol.Hit and sol.HitPos or pos)
        net.Broadcast()
        sound.Play("geams/solve_jutsu/shoton/solve_shoton_dragon_start.wav", pos, 90, 80)
        util.ScreenShake(pos, 6, 10, 0.6, 600)

        -- planté dans le sol, puis il rapetisse et disparaît
        self.Plante = true
        self:SetPos(pos)
        timer.Simple(1, function()
            if not IsValid(self) then return end
            self:SetModelScale(0.05, 0.3)
            timer.Simple(0.3, function() if IsValid(self) then self:Remove() end end)
        end)
    end

    function ENT:Think()
        if self.Plante then return end
        local now = CurTime()
        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now
        self:NextThink(now)

        local owner, from = self:GetOwner(), self:GetPos()
        self.V = self.V + self.Gravite * dt
        local to = from - Vector(0, 0, self.V * dt)

        -- le cristal suit l'ennemi visé pendant la chute (il bouge : sans ça il tombait derrière lui)
        local suivi = self.Suivi
        if IsValid(suivi) and EstCible(suivi, owner) then
            local cible = suivi:GetPos()
            local dx, dy = cible.x - to.x, cible.y - to.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist > 1 then
                local pas = math.min(dist, self.Suivi_Vitesse * dt)
                to.x, to.y = to.x + dx / dist * pas, to.y + dy / dist * pas
            end
        end
        local r = self.Rayon
        local tr = util.TraceHull({
            start = from, endpos = to, mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
            filter = function(ent) return ent ~= self and ent ~= owner and (ent:IsWorld() or EstCible(ent, owner)) end,
            mask = MASK_SHOT_HULL,
        })
        if tr.Hit then self:Impact(tr.HitPos) return true end

        self:SetPos(to)
        return true
    end
end
