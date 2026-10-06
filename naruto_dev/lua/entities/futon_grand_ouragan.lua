--========================================================
-- Futon : Grand ouragan (entité, SERVEUR + CLIENT)
--
-- Un ouragan de vent posé au sol : il ATTIRE vers son centre tout ce qui est dans son rayon et le blesse à chaque tick,
-- sauf le lanceur. La particule solve_futon_ouragan_x (particles/solve_futon.pcf) est créée par chaque client et
-- disparaît avec l'entité. Les valeurs viennent de la technique (sv_futon_grand_ouragan.lua) au lancement.
-- OPTIMISÉ : une seule recherche d'ennemis par réflexion, qui sert à l'attraction ET aux dégâts.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Grand ouragan"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seule la particule se voit
ENT.FX    = "solve_futon_ouragan_x"

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 5
ENT.Rayon      = 380
ENT.Degats     = 10
ENT.Intervalle = 0.5
ENT.Attraction = 250     -- vitesse d'aspiration vers le centre (unités/s)

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
    self:NetworkVar("Float", 1, "Fin")
end

if SERVER then
    local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self:SetRayon(self.Rayon)
        self:SetFin(CurTime() + self.Duree)
        self.ProchainTick = CurTime()
        self:EmitSound("naruto_sound/jutsu/futon/futon1.wav", 85, 80)
    end

    -- aspire la cible vers le centre
    local function Attirer(self, ent, dt)
        local delta = self:GetPos() - ent:GetPos()
        delta.z = 0
        local dist = delta:Length()
        if dist < 40 then return end   -- au cœur de l'ouragan : on ne le secoue plus

        -- plus on est près du bord, plus l'aspiration est forte
        local voulu = (delta / dist) * self.Attraction * (0.5 + 0.5 * math.min(dist / self:GetRayon(), 1))
        local vel = ent:GetVelocity()
        local boost = (voulu - Vector(vel.x, vel.y, 0)) * math.min(dt * 6, 1)
        boost.z = ent:IsOnGround() and 40 or 0   -- décolle du sol pour ne pas frotter
        -- aucune projection de la cible (pas de transfert de force)
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self:GetFin() then self:Remove() return end

        local dt = now - (self.DernierThink or now - 0.05)
        self.DernierThink = now

        local lanceur = self:GetOwner()
        local centre = self:GetPos()
        local blesse = now >= self.ProchainTick
        if blesse then self.ProchainTick = now + self.Intervalle end

        for _, ent in ipairs(ents.FindInSphere(centre, self:GetRayon())) do
            if EstCible(ent, lanceur) and ent:WorldSpaceCenter().z >= centre.z - 32 then
                Attirer(self, ent, dt)
                if blesse then
                    local dmg = DamageInfo()
                    dmg:SetDamage(self.Degats)
                    dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_GENERIC)
                    dmg:SetDamagePosition(ent:WorldSpaceCenter())
                    ent:TakeDamageInfo(dmg)
                end
            end
        end

        self:NextThink(now + 0.05)
        return true
    end
end

if CLIENT then
    -- une seule fois pour le fichier (pas à chaque apparition : micro-freeze)
    game.AddParticles("particles/solve_futon.pcf")
    PrecacheParticleSystem("solve_futon_ouragan_x")

    function ENT:Initialize()
        -- la particule déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r * 1.5))
    end

    -- créée dans le Think (plus fiable qu'à l'Initialize), relancée si l'entité sort puis revient dans le champ du joueur
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw() end   -- rien : seule la particule est visible

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
