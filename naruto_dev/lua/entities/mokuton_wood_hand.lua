--========================================================
-- Mains de bois (entité, SERVEUR + CLIENT)
--
-- Les mains du Bouddha rieur (models/mokuton/nr_mokuton_laughingbuddha_hands.mdl) surgissent du sol :
--   nr_LB_spawn (une fois, VITESSE_SPAWN fois plus vite) -> disparaissent DELAI_SUPPRESSION secondes après sa fin.
-- Les valeurs viennent de la technique (autorun/server/mokuton/mokuton_wood_hand_sv.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Mains de bois"
ENT.Spawnable = false

ENT.Model      = "models/mokuton/nr_mokuton_laughingbuddha_hands.mdl"
ENT.ANIM_SPAWN = "nr_LB_spawn"
ENT.FX_SPIKE       = "solve_doton_spike_spawn_add1"   -- particles/solve_doton.pcf
ENT.DELAI_FX       = 0.85  -- secondes après le début de l'animation où la particule se joue ET où les mains frappent (au sol)
ENT.DELAI_SUPPRESSION = 0.5   -- secondes entre la fin de l'animation et la suppression des mains
ENT.VITESSE_SPAWN = 3   -- vitesse de nr_LB_spawn (1 = normale, 3 = trois fois plus vite)

-- Valeurs par défaut (remplacées au lancement)
ENT.Echelle = 1     -- taille du modèle (1 = mains d'environ 330 unités de large)
ENT.Degats   = 30    -- dégâts de la frappe, une seule fois par personne touchée
ENT.Rayon    = 200   -- rayon de la zone qui frappe, autour des mains (developer 1 pour la voir)
ENT.Souleve  = 350   -- projection vers le haut des personnes touchées

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")   -- pour que le client puisse afficher la zone (developer 1)
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        -- boîte de collision du modèle dégénérée (mins > maxs) : "backwards mins/maxs" ; on en pose une valide (non solide)
        self:SetCollisionBounds(Vector(-8, -8, 0), Vector(8, 8, 8))
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self:SetRayon(self.Rayon)

        -- supprimées DELAI_SUPPRESSION secondes après la FIN de l'animation (durée réelle, déjà divisée par la vitesse)
        self.Fin = CurTime() + self:Jouer(self.ANIM_SPAWN, self.VITESSE_SPAWN) + self.DELAI_SUPPRESSION
        self.ProchainFx = CurTime() + self.DELAI_FX
    end

    -- Joue une animation à la vitesse donnée (1 par défaut) ; renvoie sa durée réelle en secondes (1 si introuvable)
    function ENT:Jouer(nom, vitesse)
        vitesse = vitesse or 1
        local id = self:LookupSequence(nom)
        if not id or id < 0 then return 1 end
        self:ResetSequence(id)
        self:SetCycle(0)
        self:SetPlaybackRate(vitesse)
        return self:SequenceDuration(id) / vitesse
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    -- Frappe : dégâts + projection vers le haut, une seule fois, à tous ceux qui sont dans la zone (sauf le lanceur)
    function ENT:Frapper()
        local centre = self:GetPos()
        local lanceur = self:GetOwner()

        for _, ent in ipairs(ents.FindInSphere(centre, self.Rayon)) do
            if not EstCible(ent, lanceur) then continue end
            if ent:WorldSpaceCenter().z < centre.z - 32 then continue end   -- zone au sol : rien sous le sol

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CLUB)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            -- petit bump vers le haut (Souleve, réglé dans _na_niveaux_techniques.lua) ; voulu, donné à la main
            -- (le fichier sv_sans_force.lua ne retire que la force des dégâts, pas cette vitesse)
            local vel = Vector(0, 0, self.Souleve)
            if ent.loco then
                ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
            else
                ent:SetVelocity(vel)
            end
        end
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self.Fin then
            self:Remove()
            return
        end

        if self.ProchainFx and now >= self.ProchainFx then
            self.ProchainFx = nil
            ParticleEffect(self.FX_SPIKE, self:GetPos(), angle_zero)
            self:Frapper()
        end

        self:FrameAdvance()   -- fait avancer l'animation en cours
        self:NextThink(now)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- les mains sont bien plus grandes que le petit modèle de base : zone d'affichage à leur taille
        self:SetRenderBounds(Vector(-400, -200, -60), Vector(400, 200, 400))
    end

    -- éclairage fixe : sinon les mains deviennent noires dans le sol / près d'un mur
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(0.6, 0.6, 0.6)
        render.SetModelLighting(BOX_TOP, 1, 1, 1)
        self:DrawModel()
        render.SuppressEngineLighting(false)

        -- developer 1 : rouge = boîte de collision du modèle, jaune = zone d'affichage, vert = zone de dégâts
        if GetConVar("developer"):GetInt() > 0 then
            render.DrawWireframeBox(self:GetPos(), self:GetAngles(), self:OBBMins(), self:OBBMaxs(), Color(255, 60, 60), true)
            local rmins, rmaxs = self:GetRenderBounds()
            render.DrawWireframeBox(self:GetPos(), self:GetAngles(), rmins, rmaxs, Color(255, 220, 60), true)
            -- vert = la zone qui frappe (dégâts)
            render.DrawWireframeSphere(self:GetPos(), self:GetRayon(), 16, 16, Color(60, 255, 60), true)
        end
    end
end
