--========================================================
-- Raiton : Zone de foudre (entité, SERVEUR + CLIENT)
--
-- Zone posée au sol autour du lanceur (particule solve_raiton_area). Pendant sa durée :
--   - à chaque TICK : dégâts à tous ceux qui sont dedans, sauf le lanceur ;
--   - toutes les PULSE secondes : tous ceux qui sont dedans (sauf le lanceur) sont étourdis STUN secondes.
--   - tant qu'une personne (hors lanceur) est dans la zone, elle est reliée au centre par un arc
--     (solve_raiton_ball_link_vplayer), géré côté client : l'arc apparaît à l'entrée et disparaît à la sortie
--     (ou quand la technique finit, ou quand elle meurt).
--
-- Les valeurs viennent de la technique (sv_raiton_zone.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Zone de foudre"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seules les particules se voient
ENT.FX    = "solve_raiton_area"                 -- particles/solve_raiton.pcf

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 10
ENT.Rayon      = 450    -- la particule solve_raiton_area fait ~500 de rayon
ENT.Degats     = 4      -- par tick
ENT.Intervalle = 0.5    -- secondes entre deux ticks
ENT.Pulse      = 3      -- secondes entre deux étourdissements
ENT.Stun       = 1      -- secondes d'étourdissement

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
        self.ProchainTick  = CurTime()
        self.ProchainPulse = CurTime() + self.Pulse   -- premier étourdissement après une pulse (le temps de réagir)

        -- hitbox visible avec developer 1
        if GetConVar("developer"):GetInt() > 0 then
            debugoverlay.Sphere(self:GetPos(), self.Rayon, self.Duree, Color(120, 160, 255, 15), true)
        end

    end

    -- cibles dans la zone (hors lanceur) : une seule recherche par passage
    function ENT:Cibles()
        local lanceur, centre, rayon = self:GetOwner(), self:GetPos(), self:GetRayon()
        local liste = {}
        for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
            if EstCible(ent, lanceur) and ent:WorldSpaceCenter().z >= centre.z - 64 then liste[#liste + 1] = ent end
        end
        return liste
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self:GetFin() then self:Remove() return end

        local lanceur = self:GetOwner()
        local doitTick  = now >= self.ProchainTick
        local doitPulse = now >= self.ProchainPulse

        if doitTick or doitPulse then
            local cibles = self:Cibles()

            if doitTick then
                self.ProchainTick = now + self.Intervalle
                for _, ent in ipairs(cibles) do
                    local dmg = DamageInfo()
                    dmg:SetDamage(self.Degats)
                    dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_GENERIC)   -- pas DMG_SHOCK : le moteur y ajoute ses propres étincelles / effets électriques sur la cible
                    dmg:SetDamagePosition(ent:WorldSpaceCenter())
                    ent:TakeDamageInfo(dmg)
                end
            end

            if doitPulse then
                self.ProchainPulse = now + self.Pulse
                for _, ent in ipairs(cibles) do
                    if (not ent:IsPlayer() or ent:Alive()) and NA_Etourdir then
                        NA_Etourdir(ent, self.Stun)   -- sv_etourdissement.lua
                    end
                end
            end
        end

        self:NextThink(now + 0.1)
        return true
    end
end

if CLIENT then
    local FX_LIEN = "solve_raiton_ball_link_vplayer"
    local PERIODE = 0.1   -- secondes entre deux mises à jour des arcs

    function ENT:Initialize()
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r))
        self.Liens = {}   -- cible -> particule de l'arc
    end

    -- cible possible d'un arc : hors lanceur, vivante (le serveur décide des vrais effets, ceci n'est que visuel)
    local function PeutEtreLiee(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    local function Couper(fx)
        if fx and fx:IsValid() then fx:StopEmission(false, true) end   -- true : efface aussi les particules déjà émises
    end

    -- Une seule recherche par passage : un arc par personne dans la zone, coupé dès qu'elle sort / meurt.
    function ENT:MajLiens()
        local centre, rayon, lanceur = self:GetPos(), self:GetRayon(), self:GetOwner()
        local rayon2 = (rayon + 20) ^ 2
        local dedans = {}

        if self:GetFin() > CurTime() then
            for _, ent in ipairs(ents.FindInSphere(centre, rayon + 20)) do
                if PeutEtreLiee(ent, lanceur) and ent:GetPos():DistToSqr(centre) <= rayon2 then dedans[ent] = true end
            end
        end

        -- sortis (ou technique finie) : on coupe
        for cible, fx in pairs(self.Liens) do
            if not dedans[cible] or not fx:IsValid() then
                Couper(fx)
                self.Liens[cible] = nil
            end
        end

        -- entrés : on relie
        for cible in pairs(dedans) do
            if not self.Liens[cible] then
                local fx = CreateParticleSystem(self, FX_LIEN, PATTACH_ABSORIGIN_FOLLOW, 0)
                if fx then
                    fx:AddControlPoint(1, cible, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, 36))
                    self.Liens[cible] = fx
                end
            end
        end
    end

    -- La zone et ses arcs sont (re)créés ici plutôt qu'à l'Initialize : plus fiable, et relancés si l'entité sort
    -- puis revient dans le champ du joueur.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:MajLiens()
        self:SetNextClientThink(CurTime() + PERIODE)
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
        for _, fx in pairs(self.Liens or {}) do Couper(fx) end   -- la technique est finie : plus aucun arc
        self.Liens = {}
    end
end
