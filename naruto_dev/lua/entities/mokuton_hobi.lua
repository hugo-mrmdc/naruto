--========================================================
-- Protection de bois (entité, SERVEUR + CLIENT)
--
-- Le cocon de bois (models/mokuton/nr_mokuton_hobi_face.mdl) qui entoure le lanceur. Il ne fait que
-- jouer les animations que lui demande la technique (sv : autorun/server/mokuton/mokuton_protection_sv.lua) :
--   nr_mokuton_Hobi_close -> nr_mokuton_Hobi_close_idle (en boucle) -> nr_mokuton_Hobi_open
-- et reste à sa place (le lanceur ne peut pas bouger : autorun/mokuton/sh_mokuton_protection.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Protection de bois"
ENT.Spawnable = false

ENT.Model  = "models/mokuton/nr_mokuton_hobi_face.mdl"
ENT.Echelle = 1   -- taille du modèle (posé à la taille d'origine : à régler si le cocon est trop grand ou trop petit)

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
    end

    -- Joue une animation ; renvoie sa durée en secondes (1 si le modèle ne la trouve pas)
    function ENT:Jouer(nom)
        local id = self:LookupSequence(nom)
        if not id or id < 0 then return 1 end
        self:ResetSequence(id)
        self:SetCycle(0)
        self:SetPlaybackRate(1)
        return self:SequenceDuration(id)
    end

    -- fait avancer l'animation en cours ; le cocon reste où il a été posé (le lanceur est immobile)
    function ENT:Think()
        self:FrameAdvance()
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    -- La pousse de bois (particles/atg_farisv2.pcf) : ces particules jouent ENSEMBLE sur le cocon tant qu'il existe
    ENT.FX = { "[6]_mokuton_growups_add2", "[6]_mokuton_growups_add" }
    game.AddParticles("particles/atg_farisv2.pcf")
    for _, nom in ipairs(ENT.FX) do PrecacheParticleSystem(nom) end

    function ENT:Initialize()
        -- le cocon est bien plus grand que le petit modèle de base : zone d'affichage à sa taille
        self:SetRenderBounds(Vector(-300, -300, -50), Vector(300, 300, 300))
    end

    -- La particule est (re)créée ici plutôt qu'à l'Initialize : plus fiable, et relancée si l'entité sort puis
    -- revient dans le champ du joueur. Elle disparaît avec l'entité.
    function ENT:Think()
        self.Particules = self.Particules or {}
        for i, nom in ipairs(self.FX) do
            if not (self.Particules[i] and self.Particules[i]:IsValid()) then
                self.Particules[i] = CreateParticleSystem(self, nom, PATTACH_ABSORIGIN_FOLLOW, 0)
            end
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:OnRemove()
        for _, fx in pairs(self.Particules or {}) do
            if fx and fx:IsValid() then fx:StopEmission() end
        end
        self:StopParticles()
    end
end
