--========================================================
-- Fuma : fil d'acier du Jugement des Quatre Lames (entité, SERVEUR + CLIENT)
--
-- Phases :
--   "aller"   : le bout du fil avance ; il accroche le premier joueur / PNJ qu'il
--               touche, ou s'arrête sur un mur / au bout de la portée ;
--   "accroche": fil tendu entre la main du lanceur et la cible (pendant l'étourdissement) ;
--   "retour"  : le fil se rétracte vers la main puis disparaît.
-- Le fil est dessiné par le client entre la main droite du lanceur et son bout.
-- Créé par sv_fumajugement.lua.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Fil d'acier"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.Materiau = "cable/cable2"   -- texture du fil
ENT.Largeur  = 2

-- Valeurs par défaut (remplacées au lancement)
ENT.Portee   = 1000
ENT.Vitesse  = 3000
ENT.Hitbox   = 18
ENT.Accroche = 2.5
ENT.VitesseRetour = 4000

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Cible")
    self:NetworkVar("Vector", 0, "Bout")
end

local function MainDroite(ply)
    local os = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    if os then
        local m = ply:GetBoneMatrix(os)
        if m then return m:GetTranslation() end
    end
    return ply:GetShootPos()
end

if SERVER then
    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    -- Rappelé quand les shurikens touchent la cible : le fil se détache et se rétracte
    function NA_FumaRetirerFil(cible)
        for _, fil in ipairs(ents.FindByClass("fuma_fil")) do
            if fil:GetCible() == cible then
                fil.Phase = "retour"
                fil:SetBout(cible:WorldSpaceCenter())
                fil:SetCible(NULL)
            end
        end
    end

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self.Phase = "aller"
        self.Depart = self:GetPos()
        self.Direction = (self.Direction or Vector(1, 0, 0)):GetNormalized()
        self:SetBout(self.Depart)
        self.Precedent = CurTime()
    end

    function ENT:Think()
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner:Alive() then self:Remove() return end

        local now = CurTime()
        local dt = now - self.Precedent
        self.Precedent = now

        if self.Phase == "aller" then
            local depart = self:GetBout()
            local arrivee = depart + self.Direction * self.Vitesse * dt
            local parcouru = arrivee:Distance(self.Depart)
            local bout = parcouru >= self.Portee

            -- mur sur le trajet ?
            local mur = util.TraceLine({ start = depart, endpos = arrivee, mask = MASK_SOLID_BRUSHONLY })
            local finSegment = mur.Hit and mur.HitPos or arrivee

            -- une cible dans la hitbox du fil ?
            local t = Vector(self.Hitbox, self.Hitbox, self.Hitbox)
            local cible
            for _, ent in ipairs(ents.FindAlongRay(depart, finSegment, -t, t)) do
                if EstCible(ent, owner) then cible = ent break end
            end

            if GetConVar("developer"):GetInt() > 0 then
                debugoverlay.SweptBox(depart, finSegment, -t, t, angle_zero, 0.2, Color(0, 255, 0, 40))
            end

            if cible then
                self.Phase = "accroche"
                self.FinAccroche = now + self.Accroche
                self:SetCible(cible)
                self:SetBout(cible:WorldSpaceCenter())
                cible:EmitSound("physics/metal/metal_chainlink_impact_hard" .. math.random(1, 3) .. ".wav", 75, 120)
                if NA_FumaJugementTouche then NA_FumaJugementTouche(owner, cible) end
            elseif mur.Hit or bout then
                self.Phase = "retour"
                self:SetBout(finSegment)
                if NA_FumaJugementRate then NA_FumaJugementRate(owner) end
            else
                self:SetBout(arrivee)
            end

        elseif self.Phase == "accroche" then
            local cible = self:GetCible()
            local vivante = IsValid(cible) and (not cible:IsPlayer() or cible:Alive())
            if not vivante or now >= self.FinAccroche then
                self.Phase = "retour"
                self:SetCible(NULL)
                if IsValid(cible) then self:SetBout(cible:WorldSpaceCenter()) end
            else
                self:SetBout(cible:WorldSpaceCenter())
            end

        else -- retour
            local main = MainDroite(owner)
            local bout = self:GetBout()
            local reste = main - bout
            local pas = self.VitesseRetour * dt
            if reste:Length() <= pas then self:Remove() return end
            self:SetBout(bout + reste:GetNormalized() * pas)
        end

        self:NextThink(now)
        return true
    end
end

if CLIENT then
    local mat

    function ENT:Initialize()
        self:SetRenderBounds(Vector(-3000, -3000, -3000), Vector(3000, 3000, 3000))
    end

    function ENT:DrawTranslucent()
        local owner = self:GetOwner()
        if not IsValid(owner) then return end

        local debut = MainDroite(owner)
        local cible = self:GetCible()
        local fin = IsValid(cible) and cible:WorldSpaceCenter() or self:GetBout()
        local longueur = debut:Distance(fin)
        if longueur < 2 then return end

        mat = mat or Material(self.Materiau)
        render.SetMaterial(mat)
        render.DrawBeam(debut, fin, self.Largeur, 0, longueur / 32, Color(210, 215, 225))
    end

    function ENT:Draw() end
end
