--========================================================
-- Jinton : laser du Rayon de dissolution (entité, SERVEUR + CLIENT)
--
-- Suit son lanceur (Owner). Le laser part de sa main gauche vers là où il vise
-- et s'arrête sur les murs.
--   SERVEUR : dégâts à chaque tick sur tout ce qu'il traverse (+ particule hit_jinton)
--   CLIENT  : cylindre (models/justu/jinton/cylindreonokisolve.mdl) étiré entre la
--             main et le point d'impact, particules de particles/solve_jinton_geams.pcf :
--               [2]_red_large_main  -> faisceau : un jet de particules tiré depuis la main,
--                                      le long de l'axe AVANT (X) du point 0 et de l'axe
--                                      GAUCHE (Y) du point 1 -> les deux sont orientés sur le laser
--               start_laser         -> étincelles à la main
--               impact_world_geams  -> étincelles au point d'impact
-- Créée et retirée par sv_jinton_laser.lua.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Rayon de dissolution"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Modele      = "models/justu/jinton/cylindreonokisolve.mdl"   -- 466 de long (axe Y), 102 de large
ENT.LONGUEUR_MDL = 466
ENT.LARGEUR_MDL  = 102

ENT.FX_RAYON    = ""   -- jet de particules en forme de laser : retiré ("[2]_red_large_main" pour le remettre)
ENT.FX_DEPART   = "start_laser"
ENT.FX_IMPACT   = "impact_world_geams"
ENT.FX_TOUCHE   = "hit_jinton"
ENT.SON_BOUCLE  = "solve_naruto_base/jutsu/jinton/6fgcfjo.wav"

-- main d'où part le laser : "ValveBiped.Bip01_L_Hand" (gauche) ou "ValveBiped.Bip01_R_Hand" (droite)
local OS_MAIN = "ValveBiped.Bip01_L_Hand"

-- Valeurs par défaut (remplacées au lancement)
ENT.Degats      = 40
ENT.Intervalle  = 0.25

-- Début et fin du laser pour un joueur (même calcul des deux côtés)
--   osFrais = true : le squelette du joueur vient d'être calculé (client, juste
--   après son affichage) -> position exacte de la main
-- Client, joueur local : direction du regard EXACTE de cette image (angles de la dernière commande), pas celle que
-- renvoie le jeu pour le joueur, qui a un temps de retard : le laser était en retard sur le viseur.
local vueLocale

local function Extremites(ply, osFrais)
    local portee = GetGlobal2Float("NA_JintonLaserPortee", 1500)
    local oeil = ply:EyePos()
    local dir = (CLIENT and vueLocale and ply == LocalPlayer()) and vueLocale:Forward() or ply:GetAimVector()

    -- point visé : là où le regard touche un mur (le laser traverse les personnes)
    local tr = util.TraceLine({ start = oeil, endpos = oeil + dir * portee, mask = MASK_SOLID_BRUSHONLY })
    local fin = tr.HitPos

    -- départ (secours, et serveur) : un point fixe par rapport au regard : devant, un peu à gauche, sous les yeux.
    -- Le SERVEUR ne connaît pas la vraie main (il ne joue pas l'animation du laser, que seul le client force) : il part
    -- de ce point, sur la même ligne vers le point visé ; seul le client dessine depuis la main.
    local angVue = dir:Angle()
    local depart = oeil + dir * 30 - angVue:Right() * 14 - angVue:Up() * 16

    -- Client : la vraie main (OS_MAIN), position exacte du squelette de cette image (comme à l'origine).
    local os = osFrais and ply:LookupBone(OS_MAIN)
    if os then
        local m = ply:GetBoneMatrix(os)
        local p = m and m:GetTranslation()
        if p and p ~= ply:GetPos() then depart = p end
    end
    return depart, fin, tr.Hit
end

if SERVER then
    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")   -- invisible : tout est dessiné par le client
        self:SetNoDraw(false)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        local owner = self:GetOwner()
        if IsValid(owner) then self:SetParent(owner) end
        self.ProchainTick = CurTime() + 0.1

        self.Boucle = CreateSound(self, self.SON_BOUCLE)
        if self.Boucle then self.Boucle:PlayEx(0.8, 100) end
    end

    function ENT:Think()
        local owner = self:GetOwner()
        if not IsValid(owner) or not owner:Alive() then self:Remove() return end

        local now = CurTime()
        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle

            local depart, fin = Extremites(owner)
            local e = self.Hitbox or GetGlobal2Float("NA_JintonLaserHitbox", 45)   -- zone qui touche (par niveau) (≠ épaisseur affichée)
            local t = Vector(e, e, e)

            for _, ent in ipairs(ents.FindAlongRay(depart, fin, -t, t)) do
                if EstCible(ent, owner) then
                    local centre = ent:WorldSpaceCenter()
                    local dmg = DamageInfo()
                    dmg:SetDamage(self.Degats)
                    dmg:SetAttacker(owner)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_ENERGYBEAM)
                    dmg:SetDamagePosition(centre)
                    ent:TakeDamageInfo(dmg)
                    ParticleEffect(self.FX_TOUCHE, centre, angle_zero)
                end
            end

            if GetConVar("developer"):GetInt() > 0 then
                debugoverlay.SweptBox(depart, fin, -t, t, angle_zero, self.Intervalle, Color(255, 80, 80, 30))
            end
        end

        self:NextThink(now + 0.05)
        return true
    end

    function ENT:OnRemove()
        if self.Boucle then self.Boucle:Stop() end
    end
end

if CLIENT then
    hook.Add("CreateMove", "JintonLaser_Vue", function(cmd)
        vueLocale = cmd:GetViewAngles()
    end)

    function ENT:Initialize()
        self:SetRenderBounds(Vector(-4000, -4000, -4000), Vector(4000, 4000, 4000))
    end

    local function CreerFX(self, nom, pos)
        local p = CreateParticleSystem(self, nom, PATTACH_CUSTOMORIGIN, 0, pos)
        return p
    end

    -- Le laser est dessiné juste APRÈS son lanceur (PostPlayerDraw) : son squelette
    -- vient d'être calculé, avec la rotation du corps en vol, donc la main est à
    -- la bonne place. (Dessiné avant, il avait une image de retard et décrochait.)
    function ENT:Think()
        local owner = self:GetOwner()
        if IsValid(owner) then owner.NA_LaserEntite = self end
    end

    function ENT:Draw() end

    hook.Add("PostPlayerDraw", "JintonLaser_Dessin", function(ply)
        local laser = ply.NA_LaserEntite
        if IsValid(laser) and laser:GetOwner() == ply then
            laser:DessinerLaser(ply)
        end
    end)

    -- met à jour les particules et le cylindre à chaque image
    function ENT:DessinerLaser(owner)
        local depart, fin, mur = Extremites(owner, true)
        local dir = fin - depart
        local longueur = dir:Length()
        if longueur < 1 then return end
        dir:Normalize()

        -- particules (recréées si besoin, points de contrôle suivis à chaque image)
        if self.FX_RAYON ~= "" and not (self.FxRayon and self.FxRayon:IsValid()) then
            self.FxRayon = CreerFX(self, self.FX_RAYON, depart)
        end
        if not (self.FxDepart and self.FxDepart:IsValid()) then self.FxDepart = CreerFX(self, self.FX_DEPART, depart) end
        if not (self.FxImpact and self.FxImpact:IsValid()) then self.FxImpact = CreerFX(self, self.FX_IMPACT, fin) end

        -- repère du laser : avant = direction du tir
        local repere = dir:Angle()
        local avant, droite, haut = repere:Forward(), repere:Right(), repere:Up()

        if self.FxRayon and self.FxRayon:IsValid() then
            -- point 0 : le jet principal part vers son axe avant
            self.FxRayon:SetControlPoint(0, depart)
            self.FxRayon:SetControlPointOrientation(0, avant, droite, haut)
            -- point 1 : la traînée part vers son axe gauche (Y) -> gauche = direction du tir
            self.FxRayon:SetControlPoint(1, depart)
            self.FxRayon:SetControlPointOrientation(1, droite, -avant, haut)
        end
        if self.FxDepart and self.FxDepart:IsValid() then
            self.FxDepart:SetControlPoint(0, depart)
            self.FxDepart:SetControlPointOrientation(0, avant, droite, haut)
        end
        if self.FxImpact and self.FxImpact:IsValid() then
            -- étincelles d'impact seulement quand le laser touche un mur
            self.FxImpact:SetControlPoint(0, mur and fin or Vector(0, 0, -32000))
            self.FxImpact:SetControlPointOrientation(0, -avant, droite, haut)
        end

        -- cylindre étiré de la main au point d'impact (son axe Y suit le laser)
        if not IsValid(self.Cylindre) then
            self.Cylindre = ClientsideModel(self.Modele, RENDERGROUP_TRANSLUCENT)
            if IsValid(self.Cylindre) then self.Cylindre:SetNoDraw(true) end
        end
        local c = self.Cylindre
        if not IsValid(c) then return end

        local ang = dir:Angle()
        ang:RotateAroundAxis(ang:Up(), -90)   -- l'axe Y du modèle dans le sens du laser

        local e = GetGlobal2Float("NA_JintonLaserEpaisseur", 18)
        local largeur = (e * 2) / self.LARGEUR_MDL
        local m = Matrix()
        m:Scale(Vector(largeur, longueur / self.LONGUEUR_MDL, largeur))
        c:EnableMatrix("RenderMultiply", m)
        c:SetPos(depart + dir * (longueur / 2))
        c:SetAngles(ang)
        c:SetupBones()

        -- dessiné juste après le joueur : sans ça, le laser reprend sa teinte (couleur de peau)
        local r, g, b = render.GetColorModulation()
        local blend = render.GetBlend()
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)
        render.MaterialOverride(nil)
        c:DrawModel()
        render.SetColorModulation(r, g, b)
        render.SetBlend(blend)
    end

    function ENT:OnRemove()
        local owner = self:GetOwner()
        if IsValid(owner) and owner.NA_LaserEntite == self then owner.NA_LaserEntite = nil end
        for _, cle in ipairs({ "FxRayon", "FxDepart", "FxImpact" }) do
            local p = self[cle]
            if p and p:IsValid() then p:StopEmission() end
        end
        self:StopParticles()
        if IsValid(self.Cylindre) then self.Cylindre:Remove() end
    end
end
