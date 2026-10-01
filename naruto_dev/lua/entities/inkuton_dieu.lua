--========================================================
-- Inkuton : Dieu d'encre (entité, SERVEUR + CLIENT)
-- Court tout droit dans la direction du lancement (yaw fixé au départ). Au contact d'un ennemi il
-- s'arrête, frappe (anim punch) puis disparaît. Un mur l'arrête aussi.
-- Gauche = loeve_ink_left (loeve_l_run / loeve_l_punch), droit = loeve_ink_right (loeve_run / loeve_punch).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Dieu d'encre"
ENT.Spawnable = false
ENT.AutomaticFrameAdvance = true   -- sinon la séquence ne joue pas (comme les chiens d'encre)

-- Valeurs par défaut ; la technique les remplace au lancement (sv_inkuton_dieux.lua)
ENT.Gauche      = false
ENT.Vitesse     = 1200
ENT.Degats      = 80
ENT.DureeVie    = 3
ENT.Etourdi     = 2      -- secondes d'étourdissement de la cible touchée
ENT.Echelle     = 1      -- le modèle fait ~36 unités de haut à 1
ENT.RayonTouche = 70     -- distance de contact, en unités monde
ENT.DelaiCoup   = 0.35   -- secondes entre le début du punch et les dégâts
ENT.PiedsSol    = 10      -- ajustement fin : monte (+) ou enfonce (-) les pieds par rapport au sol
ENT.DecalageYaw = 0      -- si le modèle ne court pas par son avant : essayer 90, -90 ou 180

local function EstCible(ent, lanceur) return NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

-- voulu : durée imposée (la lecture est ralentie / accélérée pour y tenir) ; sert à synchroniser les deux dieux
local function Jouer(self, nom, voulu)
    local id = self:LookupSequence(nom)
    if id < 0 then id = self:LookupSequence(nom:gsub("_l_", "_")) end   -- repli : nom sans le "_l_"
    if id < 0 then return 1 end
    self:ResetSequence(id)
    self:SetCycle(0)
    local d = self:SequenceDuration(id)
    self:SetPlaybackRate(voulu and d / voulu or 1)
    return voulu or d
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Gauche and "models/inkuton/loeve_ink_left.mdl" or "models/inkuton/loeve_ink_right.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.AnimCourse = self.Gauche and "loeve_l_run" or "loeve_run"
        self.AnimCoup   = self.Gauche and "loeve_l_punch" or "loeve_punch"
        self.MortA = CurTime() + self.DureeVie
        self.Cap = self:GetAngles().y
        self:SetAngles(Angle(0, self.Cap + self.DecalageYaw, 0))
        Jouer(self, self.AnimCourse)
    end

    function ENT:DureeCoup()
        local id = self:LookupSequence(self.AnimCoup)
        if id < 0 then id = self:LookupSequence(self.AnimCoup:gsub("_l_", "_")) end
        return id >= 0 and self:SequenceDuration(id) or 1
    end

    -- voulu : durée du coup commune aux deux dieux (la plus longue des deux animations)
    function ENT:Frapper(cible, voulu)
        self.Frappe = true
        voulu = voulu or (IsValid(self.Frere) and math.max(self:DureeCoup(), self.Frere:DureeCoup())) or self:DureeCoup()
        -- les deux dieux frappent ensemble : le frère s'arrête et frappe la même cible
        if IsValid(self.Frere) and not self.Frere.Frappe then self.Frere:Frapper(cible, voulu) end
        self:SetNW2Bool("Frappe", true)
        local duree = Jouer(self, self.AnimCoup, voulu)
        local owner = self:GetOwner()
        timer.Simple(self.DelaiCoup, function()
            if not IsValid(self) or not IsValid(cible) then return end
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            dmg:SetDamagePosition(cible:WorldSpaceCenter())
            cible:TakeDamageInfo(dmg)
            if NA_Etourdir then NA_Etourdir(cible, self.Etourdi) end   -- sv_etourdissement.lua
            -- impact du moine d'encre, joué au sol sous l'ennemi (côté client, voir Think)
            local p = cible:GetPos()
            self:SetNW2Vector("ImpactPos", util.TraceLine({ start = p + Vector(0, 0, 20), endpos = p - Vector(0, 0, 500), mask = MASK_SOLID_BRUSHONLY }).HitPos)
            self:SetNW2Int("Impact", 1)
        end)
        timer.Simple(math.max(duree, self.DelaiCoup + 0.5), function() if IsValid(self) then self:Remove() end end)   -- laisse le temps à l'impact de s'afficher
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Frappe then return true end
        if CurTime() > self.MortA then self:Remove() return true end

        -- ponytail: si la course n'est pas en boucle, on la rejoue depuis le début quand elle finit
        if self:GetCycle() >= 0.98 then self:SetCycle(0) end

        local from = self:GetPos()
        local avant = Angle(0, self.Cap, 0):Forward()
        local owner = self:GetOwner()

        -- contact avec un ennemi devant (ou sur place)
        -- (20 fois par seconde suffit : FindInSphere à chaque tick coûte cher)
        if CurTime() >= (self.ProchainContact or 0) then
            self.ProchainContact = CurTime() + 0.05
            for _, ent in ipairs(ents.FindInSphere(from + avant * self.RayonTouche * 0.5, self.RayonTouche)) do
                if EstCible(ent, owner) then self:Frapper(ent) return true end
            end
        end

        local to = from + avant * self.Vitesse * FrameTime()
        local mur = util.TraceHull({
            start = from + Vector(0, 0, 30), endpos = to + Vector(0, 0, 30),
            mins = Vector(-15, -15, -15), maxs = Vector(15, 15, 15), mask = MASK_SOLID_BRUSHONLY, filter = self,
        })
        if mur.Hit then self:Remove() return true end

        -- collé au sol
        local sol = util.TraceLine({ start = to + Vector(0, 0, 40), endpos = to - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY })
        if sol.Hit then to.z = sol.HitPos.z + self.PiedsSol end

        self:SetPos(to)
        return true
    end
end

if CLIENT then
    local PCF_IMPACT, FX_IMPACT = "particles/patlick_atgparticules.pcf", "golem_encre_impact_pat"

    -- une seule fois pour le fichier (avant : à chaque apparition d'un dieu, le .pcf était rechargé = freeze)
    game.AddParticles(PCF_IMPACT)
    PrecacheParticleSystem(FX_IMPACT)

    function ENT:Think()
        local n = self:GetNW2Int("Impact", 0)
        if n ~= (self.Impact or 0) then
            self.Impact = n
            ParticleEffect(FX_IMPACT, self:GetNW2Vector("ImpactPos"), angle_zero)
        end
        self:SetNextClientThink(CurTime())
        return true
    end

    -- éclairage fixe : sinon le modèle (VertexlitGeneric + lightwarp) devient noir à l'ombre ou contre le sol (comme le moine)
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.8, 0.8, 0.8)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
