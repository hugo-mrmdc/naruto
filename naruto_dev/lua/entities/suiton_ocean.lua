--========================================================
-- Suiton : Océan (entité, SERVEUR + CLIENT)
--
-- Une zone d'océan posée au sol : le modèle lv_zone_eau (agrandi à la taille de la zone) et la particule [23]_suiton_ocean
-- (particles/atg_farisv2.pcf). Elle ATTIRE légèrement vers son centre tout ce qui est dedans et le blesse à chaque tick,
-- sauf le lanceur. Les valeurs viennent de la technique (sv_suiton_ocean.lua) au lancement.
-- OPTIMISÉ : une seule recherche d'ennemis par réflexion, qui sert à l'attraction ET aux dégâts.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Océan"
ENT.Spawnable = false

ENT.Model = "models/nature/suiton/lv_zone_eau.mdl"
ENT.FX    = "[23]_suiton_ocean"
ENT.ECHELLE_FX = 4     -- taille de la particule (1 = taille d'origine)

-- lv_zone_eau mesure 1000 de large (rayon 500) et va de -117 à +500 en hauteur à l'échelle 1
ENT.RAYON_MODELE = 500
ENT.BAS_MODELE   = 117
ENT.HAUT_MODELE  = 500

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 8
ENT.Rayon      = 450
ENT.Degats     = 12
ENT.Intervalle = 0.5
ENT.Attraction = 120     -- vitesse d'aspiration vers le centre (unités/s) : légère

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
    self:NetworkVar("Float", 1, "Fin")
end

if SERVER then
    local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

    -- self:GetPos() = le sol au centre de la zone (modèle et particule posés dessus)
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self.Echelle = self.Rayon / self.RAYON_MODELE
        self.Sol = self:GetPos()
        self:SetModelScale(self.Echelle, 0)
        self:SetPos(self.Sol)   -- l'origine du modèle (son plan d'eau) est posée AU SOL ; sa partie basse (-BAS_MODELE) est sous le sol

        self:SetRayon(self.Rayon)
        self:SetFin(CurTime() + self.Duree)
        self.ProchainTick = CurTime()
        self:EmitSound("naruto_sound/jutsu/senju/senju3.wav", 85, 80)
    end

    function ENT:OnRemove()
        self:StopSound("naruto_sound/jutsu/senju/senju3.wav")
    end

    -- aspire légèrement la cible vers le centre
    local function Attirer(self, ent, dt)
        local delta = self.Sol - ent:GetPos()
        delta.z = 0
        local dist = delta:Length()
        if dist < 40 then return end   -- au centre : on ne le secoue plus

        -- plus on est près du bord, plus l'aspiration est forte (comme le Grand ouragan, en plus doux)
        local voulu = (delta / dist) * self.Attraction * (0.5 + 0.5 * math.min(dist / self:GetRayon(), 1))
        local vel = ent:GetVelocity()
        local boost = (voulu - Vector(vel.x, vel.y, 0)) * math.min(dt * 4, 1)
        boost.z = 0
        -- aucune projection de la cible (pas de transfert de force)
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self:GetFin() then self:Remove() return end

        local dt = now - (self.DernierThink or now - 0.05)
        self.DernierThink = now

        local lanceur = self:GetOwner()
        local sol = self.Sol
        local rayon = self:GetRayon()
        local haut = self.HAUT_MODELE * self.Echelle
        local blesse = now >= self.ProchainTick
        if blesse then self.ProchainTick = now + self.Intervalle end

        for _, ent in ipairs(ents.FindInSphere(sol, rayon + haut)) do
            if not EstCible(ent, lanceur) then continue end
            local p = ent:GetPos()
            -- dans le cylindre de la zone : rayon horizontal et hauteur du modèle
            if (p - sol):Length2D() > rayon or p.z < sol.z - 32 or p.z > sol.z + haut then continue end

            Attirer(self, ent, dt)
            if blesse then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_DROWN)
                dmg:SetDamagePosition(ent:WorldSpaceCenter())
                ent:TakeDamageInfo(dmg)
            end
        end

        self:NextThink(now + 0.05)
        return true
    end
else
    -- une seule fois pour le fichier (pas à chaque apparition : micro-freeze)
    game.AddParticles("particles/atg_farisv2.pcf")
    PrecacheParticleSystem("[23]_suiton_ocean")

    function ENT:Initialize()
        -- le modèle et la particule débordent : zone d'affichage à la taille de la zone
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -r), Vector(r, r, r * 1.5))
    end

    -- particule créée dans le Think (plus fiable qu'à l'Initialize), relancée si l'entité sort puis revient dans le champ du joueur
    function ENT:Think()
        if self:GetRayon() > 0 and not (self.Particule and self.Particule:IsValid()) then   -- rayon reçu du serveur : sinon la hauteur du sol serait fausse
            -- AU SOL : l'entité est posée sur le sol, la particule aussi
            local sol = self:GetPos()
            self.Particule = CreateParticleSystemNoEntity(self.FX, sol, angle_zero)
            -- taille x ECHELLE_FX : on étire les axes du point de contrôle 0 (les positions des particules, calculées dans ce repère, s'étalent d'autant)
            if self.Particule then
                local e = self.ECHELLE_FX
                self.Particule:SetControlPointOrientation(0, Vector(e, 0, 0), Vector(0, e, 0), Vector(0, 0, e))
            end
        end
        self:SetRenderBounds(Vector(-self:GetRayon(), -self:GetRayon(), -self:GetRayon()), Vector(self:GetRayon(), self:GetRayon(), self:GetRayon() * 1.5))
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- l'échelle est posée par le serveur à l'apparition ; on la rejoue côté client (le modèle suit le rayon réseau)
        local echelle = math.max(self:GetRayon(), 1) / self.RAYON_MODELE
        if self:GetModelScale() ~= echelle then self:SetModelScale(echelle, 0) end
        self:DrawModel()
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission(false, true) end
        self:StopParticles()
    end
end
