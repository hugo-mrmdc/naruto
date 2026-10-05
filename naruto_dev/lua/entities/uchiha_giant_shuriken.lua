--========================================================
-- Uchiha : Shuriken géant (entité projectile, SERVEUR + CLIENT)
-- Vole en ligne droite, tourne à plat sur lui-même, enveloppé de flammes
-- (katon_boule_feu_outils4, particles/atg_reworkpvp.pcf). Blesse et brûle ce qu'il touche.
-- Le serveur trace sa trajectoire à chaque tick : il ne traverse ni les murs ni les joueurs.
--
-- Modèle (mesuré dans le .vvd) : disque plat dans le plan X-Y (51 u de large, 5,6 u d'épaisseur),
-- centré sur son origine : on le fait tourner autour de l'axe vertical, comme un frisbee.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Shuriken géant"
ENT.Spawnable = false

ENT.Model     = "models/clan/konoha/uchiha/nr_tools_bigshuriken.mdl"
ENT.PCF       = "particles/atg_reworkpvp.pcf"
ENT.FX        = "katon_boule_feu_outils4"
-- explosion à l'impact : la même que la boule de feu Katon (cl_bouledefeut.lua)
ENT.PCF_HIT   = "particles/atg_reworkpvp.pcf"
ENT.FX_HIT    = "izox_katon_pluie_explode"

-- Valeurs par défaut ; la technique les remplace au lancement (sv_uchiha_shuriken.lua)
ENT.Vitesse    = 1800
ENT.Degats     = 50
ENT.DureeVie   = 3
ENT.Echelle    = 1.5
ENT.VitRotation = 1440   -- degrés par seconde
ENT.BruleDuree = 4
ENT.BruleDps   = 4

local RAYON_BASE = 25.66   -- demi-largeur du modèle à l'échelle 1

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Spin")
end

if SERVER then
    resource.AddFile(ENT.PCF_HIT)
    game.AddParticles(ENT.PCF_HIT)
    PrecacheParticleSystem(ENT.FX_HIT)

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self:SetSpin(self.VitRotation)

        self.MortA = CurTime() + self.DureeVie
        self.Direction = self.Direction or self:GetForward()
        self:SetAngles(self.Direction:Angle())
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit = tr.Entity
        local owner = self:GetOwner()

        if IsValid(hit) and hit ~= owner then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(bit.bor(DMG_SLASH, DMG_BURN))
            dmg:SetDamagePosition(tr.HitPos)
            dmg:SetDamageForce(self.Direction * 3000)
            hit:TakeDamageInfo(dmg)

            if NA_Bruler and (hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot()) then
                NA_Bruler(hit, IsValid(owner) and owner or self, self.BruleDuree, self.BruleDps)
            end
        end

        ParticleEffect(self.FX_HIT, tr.HitPos, angle_zero)

        self:EmitSound("naruto_sound/jutsu/uchiha/uchiha6.wav", 75, 90)
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end
        if CurTime() > self.MortA then self:Remove() return end

        local from = self:GetPos()
        local to = from + self.Direction * self.Vitesse * FrameTime()
        local r = RAYON_BASE * self.Echelle * 0.6   -- zone de touche un peu plus petite que les pointes
        local tr = util.TraceHull({
            start = from, endpos = to,
            mins = Vector(-r, -r, -r), maxs = Vector(r, r, r),
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
    -- Flammes sur tout le shuriken : une grosse au centre + une à chaque pointe (il a 4 branches),
    -- les pointes tournent avec lui. PATTACH_CUSTOMORIGIN : on place nous-mêmes chaque point.
    local POINTES = 4
    local PLACEMENT = 0.85   -- où se posent les flammes sur les branches (0 = centre, 1 = bout de la pointe)

    -- Particules réglables EN JEU (puis relancer un shuriken), pour comparer sans toucher au code :
    --   uchiha_shuriken_fx_centre   katon_boule_feu_atg2
    --   uchiha_shuriken_fx_pointe   katon_boule_feu_outils4
    -- autres essais : katon_boule_feu_outils1 à 5, izox_katon_bigball_bis, katon_danse_outils1 à 3, katon_brulureatg
    local cvCentre = CreateClientConVar("uchiha_shuriken_fx_centre", "katon_boule_feu_atg2", true, false, "Particule au centre du shuriken géant")
    local cvPointe = CreateClientConVar("uchiha_shuriken_fx_pointe", "katon_boule_feu_outils4", true, false, "Particule sur chaque pointe du shuriken géant")

    function ENT:Initialize()
        game.AddParticles(self.PCF)
        game.AddParticles(self.PCF_HIT)
        PrecacheParticleSystem(self.FX_HIT)
        self.Rot = 0
        self.FXsys = {}
    end

    -- Crée (ou recrée si le système a été coupé) puis place les flammes : au centre et sur chaque pointe.
    -- Fait dans Think (et pas seulement Draw) pour que chacun des shurikens lancés ensemble ait les siennes.
    local function Flammes(self)
        local pos = self:GetPos()
        local rayon = RAYON_BASE * self:GetModelScale() * PLACEMENT
        for i = 0, POINTES do
            local fx = self.FXsys[i]
            if fx == nil or (fx and not IsValid(fx)) then   -- false = création impossible (nom de particule faux) : on n'insiste pas
                local nom = i == 0 and cvCentre:GetString() or cvPointe:GetString()
                PrecacheParticleSystem(nom)
                fx = CreateParticleSystem(self, nom, PATTACH_CUSTOMORIGIN)
                self.FXsys[i] = fx or false
            end
            if fx and IsValid(fx) then
                fx:SetControlPoint(0, i == 0 and pos or pos + Angle(0, self.Rot + (i - 1) * 360 / POINTES, 0):Forward() * rayon)
            end
        end
    end

    function ENT:Think()
        self.Rot = ((self.Rot or 0) + FrameTime() * self:GetSpin()) % 360
        Flammes(self)
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        -- rotation visuelle uniquement (le serveur ne gère que la trajectoire)
        self:SetRenderAngles(Angle(0, self.Rot or 0, 0))
        self:DrawModel()
        self:SetRenderAngles(nil)
    end

    function ENT:OnRemove()
        for _, fx in pairs(self.FXsys or {}) do
            if IsValid(fx) then fx:StopEmission() end
        end
    end
end
