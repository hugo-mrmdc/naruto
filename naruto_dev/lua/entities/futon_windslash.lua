--========================================================
-- Wind Slash (entité projectile, SERVEUR + CLIENT)
--
-- Lame de vent : un croissant plat (models/nature/futon/windslash3.mdl) qui file en ligne droite.
-- Le serveur teste sa trajectoire à chaque tick (TraceHull, comme une balle) : elle ne traverse
-- ni les murs ni les cibles. À l'impact : dégâts, puis elle disparaît.
-- L'affichage est le modèle lui-même, vu par tout le monde.
--
-- Les valeurs viennent de la technique (sv_futon_windslash.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Wind Slash"
ENT.Spawnable = false

ENT.Model = "models/nature/futon/windslash3.mdl"

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse  = 1800
ENT.Degats   = 35
ENT.DureeVie = 1.5
ENT.Rayon    = 40     -- demi-largeur de la zone qui touche (à l'horizontale)
ENT.RayonHaut = 15    -- demi-hauteur de la zone qui touche : la lame est plate, donc basse
ENT.Echelle  = 0.6    -- taille du modèle (1 = 187 unités de large)
ENT.Roulis   = 0      -- rotation autour de l'axe de tir, en degrés (0 = lame à plat, 90 = lame debout)

if SERVER then
    local DEBUG_CVAR = CreateConVar("na_windslash_hitbox", "0", FCVAR_NONE, "1 = affiche la hitbox du Wind Slash")

    -- Réglage de l'orientation du modèle EN JEU (s'ajoute à ce qui est calculé, pour les prochaines lames) :
    --   na_windslash_lacet   : tourne la lame vers la gauche / droite   (essaie 90, -90, 180)
    --   na_windslash_tangage : penche la lame vers le haut / le bas
    --   na_windslash_roulis  : la fait rouler autour de son axe de tir (en plus de ROULIS)
    local CV_LACET   = CreateConVar("na_windslash_lacet", "0", FCVAR_NONE, "Décalage de lacet (degrés) du modèle du Wind Slash")
    local CV_TANGAGE = CreateConVar("na_windslash_tangage", "0", FCVAR_NONE, "Décalage de tangage (degrés) du modèle du Wind Slash")
    local CV_ROULIS  = CreateConVar("na_windslash_roulis", "0", FCVAR_NONE, "Décalage de roulis (degrés) du modèle du Wind Slash")

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()

        -- Orientation du modèle : base d'origine (-90°, son +Y vers l'avant) puis encore 90° vers la DROITE
        -- (sens horaire vu de dessus) = -180°. Réglable en jeu avec na_windslash_lacet.
        local ang = self.Dir:Angle()
        ang:RotateAroundAxis(ang:Up(), -90 - 90 + CV_LACET:GetFloat())
        ang:RotateAroundAxis(ang:Right(), CV_TANGAGE:GetFloat())
        ang:RotateAroundAxis(self.Dir, self.Roulis + CV_ROULIS:GetFloat())
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

        if EstVivant(hit) and hit ~= owner then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(tr.HitPos)
            dmg:SetDamageForce(self.Dir * 3000)
            hit:TakeDamageInfo(dmg)
        end

        self:EmitSound("ambient/wind/wind_hit" .. math.random(1, 3) .. ".wav", 80, math.random(110, 130))
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

        if DEBUG_CVAR:GetBool() then   -- na_windslash_hitbox 1 : boîte de collision (cyan = trajet, rouge = impact)
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
    -- la lame est plus large que le petit modèle de base : zone d'affichage à sa taille
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-200, -200, -50), Vector(200, 200, 50))
    end
end
