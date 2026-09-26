--========================================================
-- Séisme (entité, SERVEUR + CLIENT)
--
-- Zone de tremblement de terre posée au sol pendant quelques secondes : blesse tout ce qui est
-- dedans à chaque tick, sauf celui qui l'a lancée.
-- La particule (doton_seisme_pat) est créée par chaque client à la réception de l'entité :
-- tout le monde la voit, et elle disparaît avec l'entité.
--
-- Les valeurs viennent de la technique (sv_doton_seisme.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Séisme"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seule la particule se voit
ENT.FX    = "doton_seisme_pat"                  -- particles/patlick_atgparticules.pcf

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 5
ENT.Rayon      = 250    -- à régler sur la taille de la particule dans le .pcf
ENT.Degats     = 5
ENT.Intervalle = 0.5

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
    self:NetworkVar("Float", 1, "Fin")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self:SetRayon(self.Rayon)
        self:SetFin(CurTime() + self.Duree)
        self.ProchainTick = CurTime()

        self:EmitSound("physics/concrete/concrete_break3.wav", 85, 70)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Blesser()
        local centre = self:GetPos()
        local lanceur = self:GetOwner()

        for _, ent in ipairs(ents.FindInSphere(centre, self:GetRayon())) do
            if not EstCible(ent, lanceur) then continue end

            -- zone au sol : rien sous le sol de la zone
            if ent:WorldSpaceCenter().z < centre.z - 32 then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CRUSH)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)
        end
    end

    function ENT:Think()
        local now = CurTime()

        if now >= self:GetFin() then
            self:Remove()
            return
        end

        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle
            self:Blesser()
            self:EmitSound("physics/concrete/rock_impact_hard" .. math.random(1, 6) .. ".wav", 70, math.random(70, 90), 0.6)
        end

        self:NextThink(now + 0.1)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- la particule déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r))
    end

    -- La particule est (re)créée ici plutôt qu'à l'Initialize : plus fiable, et
    -- relancée si l'entité sort puis revient dans le champ du joueur.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- rien : seule la particule est visible
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
