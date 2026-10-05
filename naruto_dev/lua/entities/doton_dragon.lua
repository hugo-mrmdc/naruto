--========================================================
-- Doton : Dragon de terre (entité, SERVEUR + CLIENT)
--
-- Un dragon de roche (models/nature/doton/doton_dragon_01) sort du sol. Pendant sa durée de vie il se TOURNE dans la
-- direction où regarde son lanceur (le cap seulement, pas le haut / bas) et TIRE des projectiles de pierre
-- (entité doton_dragon_balle) À L'HORIZONTALE, dans cette direction.
-- Il monte du sol au début et s'enfonce à la fin. Les valeurs viennent de la technique (sv_doton_dragon.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Dragon de terre"
ENT.Spawnable = false

ENT.Model = "models/nature/doton/doton_dragon_01.mdl"

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree     = 5      -- secondes de vie
ENT.Cadence   = 0.3    -- secondes entre deux tirs
ENT.Degats    = 20     -- dégâts d'un projectile
ENT.Vitesse   = 1600   -- vitesse d'un projectile
ENT.Echelle   = 1.2    -- le modèle fait ~165 de long et ~140 de haut à l'échelle 1
ENT.Rotation  = 200    -- degrés par seconde : vitesse à laquelle il se tourne vers la cible

-- Réglages visuels. Orientation mesurée en jeu (la lecture du .vvd était fausse : le modèle a un os racine tourné) :
-- à 0 degré la tête regarde vers la GAUCHE du lanceur, à 90 vers le lanceur lui-même, à 180 vers la droite.
-- Pour qu'elle regarde DEVANT, on tourne le modèle de -90 degrés.
ENT.DecalageYaw = -90
ENT.Bouche      = Vector(0, 75, 42)          -- bouche, à l'échelle 1, dans le repère du modèle (la tête regarde vers +y à yaw 0, en hauteur) : d'où partent les projectiles
ENT.Enfoncement = 150                        -- profondeur (échelle 1) dont il est enfoncé dans le sol au début / à la fin
ENT.Montee      = 0.6                        -- secondes pour sortir du sol (et pour s'enfoncer à la fin)

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetModelScale(self.Echelle, 0)
        self:DrawShadow(true)

        self.Sol     = self:GetPos()          -- point du sol où il est posé
        self.Yaw     = self:GetAngles().y
        self.Debut   = CurTime()
        self.Fin     = self.Debut + self.Duree
        self.Tir     = self.Debut + self.Montee + 0.3   -- premier tir : un instant après être sorti
        self:SetPos(self.Sol - Vector(0, 0, self.Enfoncement * self.Echelle))
        self:EmitSound("naruto_sound/jutsu/doton/earth10.wav", 85, 70)
    end

    function ENT:Think()
        local now = CurTime()
        local lanceur = self:GetOwner()
        if now >= self.Fin + self.Montee or not IsValid(lanceur) or not lanceur:Alive() then self:Remove() return end

        -- sort du sol, puis s'enfonce à la fin
        local t = math.Clamp((now - self.Debut) / self.Montee, 0, 1)
        local s = math.Clamp((self.Fin + self.Montee - now) / self.Montee, 0, 1)
        local sortie = math.min(t, s)
        sortie = sortie * sortie * (3 - 2 * sortie)   -- départ et arrivée en douceur
        self:SetPos(self.Sol - Vector(0, 0, self.Enfoncement * self.Echelle * (1 - sortie)))

        -- se tourne dans la direction où regarde le lanceur : son CAP (yaw) seulement, pas le haut / bas
        local dt = FrameTime()
        self.Yaw = math.ApproachAngle(self.Yaw, lanceur:EyeAngles().y, self.Rotation * dt)
        self:SetAngles(Angle(0, self.Yaw + self.DecalageYaw, 0))

        -- tire quand il est sorti, pas pendant qu'il s'enfonce
        if t >= 1 and now < self.Fin and now >= self.Tir then
            self.Tir = now + self.Cadence
            local bouche = self:LocalToWorld(self.Bouche * self.Echelle)
            local dir = Angle(0, self.Yaw, 0):Forward()   -- à l'horizontale, dans la direction où le dragon est tourné

            local balle = ents.Create("doton_dragon_balle")
            if IsValid(balle) then
                balle:SetPos(bouche)
                balle:SetAngles(dir:Angle())
                balle:SetOwner(lanceur)
                balle.Dir     = dir
                balle.Degats  = self.Degats
                balle.Vitesse = self.Vitesse
                balle.Dragon  = self
                balle:Spawn()
            end
            self:EmitSound("naruto_sound/jutsu/doton/earth11.wav", 80, math.random(60, 80))
        end

        self:NextThink(now)
        return true
    end
end

if CLIENT then
    -- particles/solve_doton.pcf (chargé une seule fois ; déjà utilisé par les Pics de pierre)
    game.AddParticles("particles/solve_doton.pcf")
    PrecacheParticleSystem("solve_doton_floor_crack")

    function ENT:Initialize()
        util.PrecacheModel(self.Model)
    end

    -- fissures au sol : la particule se place sur le modèle du dragon (point de contrôle 0 = le dragon) et le suit.
    -- Créée dans le Think (pas à l'Initialize : l'entité n'est pas toujours prête) ; elle s'arrête avec le dragon.
    function ENT:Think()
        if self.Fissures == nil or (self.Fissures and not IsValid(self.Fissures)) then
            self.Fissures = CreateParticleSystem(self, "solve_doton_floor_crack", PATTACH_ABSORIGIN_FOLLOW) or false
        end
        self:SetNextClientThink(CurTime() + 0.5)
        return true
    end

    function ENT:OnRemove()
        if IsValid(self.Fissures) then self.Fissures:StopEmission() end
    end

    -- éclairage fixe : il sort du sol, son origine est dans la géométrie et il deviendrait noir
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.8, 0.8, 0.8)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
