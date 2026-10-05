--========================================================
-- Wind Ball (entité projectile, SERVEUR + CLIENT)
--
-- Une boule de vent (models/nature/futon/windball.mdl) qui file en ligne droite. Le serveur teste
-- sa trajectoire à chaque tick (TraceHull, comme une balle) : elle ne traverse ni les murs ni les
-- cibles. À l'impact : dégâts, PROJECTION de la cible touchée et particule solve_futon_bump_01.
-- L'affichage est le modèle lui-même, vu par tout le monde.
--
-- Les valeurs viennent de la technique (sv_futon_windball.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Wind Ball"
ENT.Spawnable = false

ENT.Model     = "models/nature/futon/windball.mdl"
ENT.FX_IMPACT = "solve_futon_bump_01"   -- particles/solve_futon.pcf (chargé par sv_ / cl_futon_windball.lua)

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse  = 1500
ENT.Degats   = 25
ENT.DureeVie = 2
ENT.Rayon    = 30     -- demi-largeur de la zone qui touche (à l'horizontale)
ENT.RayonHaut = 30    -- demi-hauteur de la zone qui touche : baisse-la pour une hitbox plus basse
ENT.Echelle  = 0.5    -- taille du modèle (1 = boule de 116 unités de large, queue comprise ~195)
ENT.Recul    = 600    -- projection de la cible touchée, dans le sens du tir
ENT.Souleve  = 250    -- projection vers le haut

if SERVER then
    local DEBUG_CVAR = CreateConVar("na_windball_hitbox", "0", FCVAR_NONE, "1 = affiche la hitbox du Wind Ball")

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()

        -- la queue du modèle est du côté +X : la boule avance vers son -X, on retourne donc le modèle de 180°
        local ang = self.Dir:Angle()
        ang:RotateAroundAxis(ang:Up(), 180)
        self:SetAngles(ang)
    end

    local function EstVivant(ent)
        return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit = tr.Entity
        local owner = self:GetOwner()
        local pos = tr.HitPos

        local touche = EstVivant(hit) and hit ~= owner
        if touche then
            pos = hit:GetPos()   -- centré sur la personne touchée (son origine = le milieu de ses pieds)

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetDamagePosition(tr.HitPos)
            hit:TakeDamageInfo(dmg)

            -- bump : projeté dans le sens du tir et vers le haut
            local vel = self.Dir * self.Recul + Vector(0, 0, self.Souleve)
            if hit.loco then
                hit.loco:SetVelocity(hit.loco:GetVelocity() + vel)   -- NextBot
            else
                hit:SetVelocity(vel)
            end
        end

        -- le bump se joue AU SOL, au milieu de la personne touchée : on descend jusqu'au sol (300 unités au plus)
        local sol = util.TraceLine({
            start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 300),
            mask = MASK_SOLID_BRUSHONLY,
        })
        if sol.Hit then pos = sol.HitPos end
        ParticleEffect(self.FX_IMPACT, pos, angle_zero)
        self:EmitSound("naruto_sound/jutsu/futon/futon3.wav", 80, math.random(90, 110))
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end

        if CurTime() > self.MortA then
            self:Remove()
            return
        end

        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * FrameTime()
        local r, h = self.Rayon, self.RayonHaut
        local mins, maxs = Vector(-r, -r, -h), Vector(r, r, h)

        if DEBUG_CVAR:GetBool() then   -- na_windball_hitbox 1 : boîte de collision (cyan = trajet, rouge = impact)
            debugoverlay.Box(from, mins, maxs, 0.15, Color(0, 200, 255, 30))
        end

        local tr = util.TraceHull({
            start = from,
            endpos = to,
            mins = mins,
            maxs = maxs,
            filter = { self, self:GetOwner() },
            mask = MASK_SHOT,
        })

        if tr.Hit then
            if DEBUG_CVAR:GetBool() then
                debugoverlay.Box(tr.HitPos, mins, maxs, 2, Color(255, 60, 60, 60))
            end
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
    -- la boule et sa queue sont plus grandes que le petit modèle de base : zone d'affichage à leur taille
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-200, -200, -200), Vector(200, 200, 200))
    end
end
