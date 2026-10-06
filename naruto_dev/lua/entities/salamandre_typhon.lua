--========================================================
-- Typhon de poison de la salamandre (entité, SERVEUR + CLIENT)
--
-- Posé au sol pendant quelques secondes :
--   - ATTIRE vers son centre tout ce qui est autour (sauf le lanceur),
--     en tourbillonnant ;
--   - le CŒUR blesse et empoisonne ce qui y est pris.
-- Particules godio_petite_zone_sala (particles/godio_salamandre.pcf), créées
-- par chaque client à la réception de l'entité : tout le monde les voit.
--
-- Les valeurs viennent de la technique (sv_tornadopoison.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Typhon de poison"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seules les particules se voient
ENT.FX    = "godio_petite_zone_sala"

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree            = 6
ENT.RayonAttraction  = 450    -- distance à partir de laquelle on est aspiré
ENT.RayonCoeur       = 220    -- zone qui blesse (~ taille des particules)
ENT.ForceAttraction  = 3000   -- plus fort que la course normale : on ne s'enfuit pas en courant
ENT.Tourbillon       = 900    -- rotation autour du centre
ENT.VitesseAttractionPNJ = 350   -- vitesse à laquelle les PNJ / nextbots glissent vers le centre
ENT.Degats           = 8
ENT.Intervalle       = 0.5
ENT.PoisonDuree      = 3

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "RayonAttraction")
    self:NetworkVar("Float", 1, "Fin")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetAngles(Angle(0, 0, 0))   -- les particules montent selon l'axe Z de l'entité

        self:SetRayonAttraction(self.RayonAttraction)
        self:SetFin(CurTime() + self.Duree)
        self.ProchainDegat = CurTime()

        self:EmitSound("naruto_sound/jutsu/senju/senju4.wav", 80, 70)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    -- on n'aspire pas à travers les murs
    local function Visible(depuis, ent)
        local tr = util.TraceLine({
            start = depuis,
            endpos = ent:WorldSpaceCenter(),
            mask = MASK_SOLID_BRUSHONLY,
        })
        return not tr.Hit
    end

    function ENT:Attirer(dt)
        local centre = self:GetPos() + Vector(0, 0, 40)
        local lanceur = self:GetOwner()
        local rayon = self:GetRayonAttraction()

        for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
            if not EstCible(ent, lanceur) or not Visible(centre, ent) then continue end

            local vers = centre - ent:GetPos()
            vers.z = 0
            local dist = vers:Length()
            if dist < 30 then continue end   -- déjà au centre : pas de tremblement

            local dir = vers / dist
            local tangente = Vector(-dir.y, dir.x, 0)

            -- l'aspiration faiblit près du centre, sinon on le dépasse et on fait des allers-retours
            local attenuation = math.Clamp(dist / self.RayonCoeur, 0.25, 1)

            if ent:IsPlayer() then
                -- accélération ajoutée à la vitesse du joueur (SetVelocity s'additionne)
                local force = self.ForceAttraction * attenuation
                -- aucune projection de la cible (pas de transfert de force)
            else
                -- PNJ / nextbots : on les fait glisser à vitesse fixe, sans traverser les murs
                local vitesse = self.VitesseAttractionPNJ * attenuation
                local pas = (dir * vitesse + tangente * vitesse * 0.3) * dt
                local depart = ent:GetPos()
                local tr = util.TraceHull({
                    start = depart, endpos = depart + pas,
                    mins = ent:OBBMins(), maxs = ent:OBBMaxs(),
                    filter = ent, mask = MASK_NPCSOLID,
                })
                if not tr.StartSolid then ent:SetPos(tr.HitPos) end
            end
        end
    end

    function ENT:Blesser()
        local centre = self:GetPos() + Vector(0, 0, 40)
        local lanceur = self:GetOwner()

        for _, ent in ipairs(ents.FindInSphere(centre, self.RayonCoeur)) do
            if not EstCible(ent, lanceur) then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_ACID)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            if self.PoisonDuree > 0 and SalamandrePoison and SalamandrePoison.Apply then
                SalamandrePoison.Apply(ent, lanceur, self.PoisonDuree)
            end
        end
    end

    function ENT:Think()
        local now = CurTime()

        if now >= self:GetFin() then
            self:Remove()
            return
        end

        local dt = 0.05
        self:Attirer(dt)

        if now >= self.ProchainDegat then
            self.ProchainDegat = now + self.Intervalle
            self:Blesser()
        end

        self:NextThink(now + dt)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        local r = math.max(self:GetRayonAttraction(), 128)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, 800))
    end

    -- La particule est (re)créée ici plutôt qu'à l'Initialize : à la création,
    -- l'entité n'est pas toujours prête côté client, et si elle sort puis revient
    -- dans le champ du joueur, l'effet doit être relancé.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- rien : seules les particules sont visibles
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
