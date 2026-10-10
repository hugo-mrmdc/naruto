--========================================================
-- Tornade de lame (entité projectile, SERVEUR + CLIENT)
--
-- Une tornade (particule kenjutsu_tornade_pat) qui file au ras du sol en ligne droite.
-- Elle blesse une fois chaque ennemi qu'elle croise et s'arrête contre un mur
-- ou au bout de sa durée de vie. Le serveur décide de tout (TraceHull à chaque tick).
--
-- Les valeurs viennent de la technique (sv_kenjutsu_tornade.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Tornade de lame"
ENT.Spawnable = false

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse  = 1400
ENT.Degats   = 60
ENT.DureeVie = 1.0
ENT.Souleve  = 350    -- projection vers le haut de chaque ennemi touché
ENT.Etourdi  = 0.4    -- étourdissement de l'ennemi touché (secondes)
ENT.Rayon    = 120    -- demi-largeur de la zone qui touche
ENT.RayonHaut = 130   -- demi-hauteur de la zone qui touche

local FX     = "kenjutsu_tornade_pat"   -- particles/patlick_atgparticules.pcf
local ECHELLE_FX   = 1      -- étirement supplémentaire côté client (1 = aucun) : la taille x2 est déjà écrite dans le .pcf (tools/scale_pcf.py)
local FX_HIT = "solve_ken_nrm_hit_03"   -- sur chaque cible touchée (particles/solve_kenjutsu_expert.pcf)

if SERVER then
    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetRenderMode(RENDERMODE_TRANSCOLOR)
        self:SetColor(Color(255, 255, 255, 0))   -- invisible : seule la particule se voit

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()
        self.Touches = self.Touches or {}   -- table partagée entre les tornades d'un même lancer : un ennemi n'est touché qu'une fois

        self:SetNWFloat("Rayon", self.Rayon)   -- lu par le client pour étaler les particules
        self:EmitSound("naruto_sound/jutsu/futon/futon12.wav", 80, 90)
    end

    function ENT:Blesser()
        local owner = self:GetOwner()
        for _, ent in ipairs(ents.FindInSphere(self:GetPos() + Vector(0, 0, self.RayonHaut / 2), self.Rayon)) do
            if self.Touches[ent] or not EstCible(ent, owner) then continue end
            self.Touches[ent] = true

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            dmg:SetDamageForce(vector_origin)   -- aucune poussée des dégâts : seule la projection verticale déplace la cible
            ent:TakeDamageInfo(dmg)

            -- stun léger (souple) puis bump : NA_Projeter laisse la cible partir en l'air avant qu'elle soit refixée à l'atterrissage
            if NA_Etourdir then NA_Etourdir(ent, self.Etourdi, nil, nil, true) end   -- sv_etourdissement.lua
            if NA_Projeter then NA_Projeter(ent, 1.5) end
            ent:SetGroundEntity(NULL)
            -- droit vers le haut : on annule d'abord la vitesse horizontale / verticale de la cible (SetVelocity s'ajoute chez les joueurs)
            local v = ent:GetVelocity()
            if ent:IsPlayer() then ent:SetVelocity(Vector(-v.x, -v.y, self.Souleve - v.z)) else ent:SetVelocity(Vector(0, 0, self.Souleve)) end
            ent:EmitSound("dimix/sond/taijutsu/hit6.wav", 75, math.random(95, 110))
            ParticleEffect(FX_HIT, ent:WorldSpaceCenter(), angle_zero)
        end
    end

    function ENT:Think()
        if CurTime() > self.MortA then
            self:Remove()
            return
        end

        local from = self:GetPos()
        local to = from + self.Dir * self.Vitesse * FrameTime()

        -- s'arrête contre un mur
        local mur = util.TraceHull({
            start = from + Vector(0, 0, 30), endpos = to + Vector(0, 0, 30),
            mins = Vector(-40, -40, 0), maxs = Vector(40, 40, 40),
            filter = { self, self:GetOwner() }, mask = MASK_SOLID_BRUSHONLY,
        })
        if mur.Hit then
            self:Remove()
            return
        end

        -- reste collée au sol
        local sol = util.TraceLine({
            start = to + Vector(0, 0, 60), endpos = to - Vector(0, 0, 200),
            filter = { self, self:GetOwner() }, mask = MASK_SOLID_BRUSHONLY,
        })
        if sol.Hit then to.z = sol.HitPos.z end

        self:SetPos(to)
        self:Blesser()
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    -- la tornade est plus large que le petit modèle de base : zone d'affichage à sa taille
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-400, -400, -50), Vector(400, 400, 600))
    end

    -- Particule créée dans le Think (plus fiable qu'à l'Initialize) et placée sur l'entité à chaque tick.
    -- Taille x ECHELLE_FX : on étire les axes du point de contrôle 0 (même méthode que suiton_ocean.lua).
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystemNoEntity(FX, self:GetPos(), angle_zero)
        end
        if self.Particule and self.Particule:IsValid() then
            local e = ECHELLE_FX
            self.Particule:SetControlPoint(0, self:GetPos())
            self.Particule:SetControlPointOrientation(0, Vector(e, 0, 0), Vector(0, e, 0), Vector(0, 0, e))
        end
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission(false, true) end
    end
end
