--========================================================
-- Tornade de vent (entité, SERVEUR + CLIENT)
--
-- Une tornade qui AVANCE devant le lanceur : elle suit le sol, s'arrête contre un mur, et blesse
-- tout ce qui touche son cylindre (sauf le lanceur) à chaque tick. Elle disparaît après DUREE.
-- L'affichage est la particule solve_futon_tornado_move_s (particles/solve_futon.pcf), créée par
-- chaque client à la réception de l'entité.
--
-- Les valeurs viennent de la technique (sv_futon_tornade.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Tornade de vent"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seule la particule se voit
ENT.FX    = "solve_futon_tornado_move_s"

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 4
ENT.Vitesse    = 300     -- vitesse d'avance (unités par seconde)
ENT.Rayon      = 130     -- rayon du cylindre qui blesse
ENT.Hauteur    = 250     -- hauteur du cylindre qui blesse
ENT.Degats     = 6       -- dégâts par tick
ENT.Intervalle = 0.25    -- secondes entre deux ticks
ENT.Recul      = 300     -- projection vers l'extérieur de la tornade, à chaque tick (0 = aucune)
ENT.Souleve    = 220     -- projection vers le haut, à chaque tick

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
end

if SERVER then
    local DEBUG_CVAR = CreateConVar("na_tornade_hitbox", "0", FCVAR_NONE, "1 = affiche la zone de dégâts de la tornade de vent")

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self:SetRayon(self.Rayon)
        self.MortA = CurTime() + self.Duree
        self.ProchainTick = CurTime()
        self.Dir = self.Direction or self:GetForward()
        self.Dir.z = 0
        self.Dir:Normalize()

        self:EmitSound("ambient/wind/windgust_strong.wav", 80, 100)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Blesser()
        local pos = self:GetPos()
        local r, h = self.Rayon, self.Hauteur
        local lanceur = self:GetOwner()

        for _, ent in ipairs(ents.FindInBox(pos + Vector(-r, -r, -20), pos + Vector(r, r, h))) do
            if not EstCible(ent, lanceur) then continue end

            -- cylindre : distance horizontale au centre
            local d = ent:GetPos() - pos
            d.z = 0
            if d:LengthSqr() > r * r then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            -- bump : projeté vers l'extérieur du tourbillon et un peu vers le haut
            if self.Recul > 0 or self.Souleve > 0 then
                local sortie = d
                if sortie:LengthSqr() < 1 then sortie = self.Dir end
                sortie = sortie:GetNormalized() * self.Recul + Vector(0, 0, self.Souleve)
                if ent.loco then
                    ent.loco:SetVelocity(ent.loco:GetVelocity() + sortie)   -- NextBot
                else
                    ent:SetVelocity(sortie)
                end
            end
        end
    end

    -- Avance à l'horizontale, colle au sol, s'arrête contre un mur
    function ENT:Avancer(dt)
        local from = self:GetPos()
        local vers = from + self.Dir * self.Vitesse * dt

        local mur = util.TraceHull({
            start = from + Vector(0, 0, 40), endpos = vers + Vector(0, 0, 40),
            mins = Vector(-30, -30, -20), maxs = Vector(30, 30, 20),
            mask = MASK_SOLID_BRUSHONLY,
        })
        if mur.Hit then return false end

        local sol = util.TraceLine({
            start = vers + Vector(0, 0, 60), endpos = vers - Vector(0, 0, 200),
            mask = MASK_SOLID_BRUSHONLY,
        })
        self:SetPos(sol.Hit and sol.HitPos or vers)
        return true
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self.MortA then
            self:Remove()
            return
        end

        if not self:Avancer(FrameTime()) then
            self:Remove()   -- contre un mur : la tornade se dissipe
            return
        end

        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle
            self:Blesser()
        end

        if DEBUG_CVAR:GetBool() then   -- na_tornade_hitbox 1 : boîte englobante de la zone de dégâts
            local p, r = self:GetPos(), self.Rayon
            debugoverlay.Box(p, Vector(-r, -r, -20), Vector(r, r, self.Hauteur), 0.15, Color(0, 200, 255, 25))
        end

        self:NextThink(now)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- la tornade déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 100) * 2
        self:SetRenderBounds(Vector(-r, -r, -50), Vector(r, r, r * 2))
    end

    -- La particule est (re)créée ici plutôt qu'à l'Initialize : plus fiable, et relancée si
    -- l'entité sort puis revient dans le champ du joueur.
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
        -- (false, true) : détruit aussi les particules déjà émises
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission(false, true) end
        self:StopParticles()
    end
end
