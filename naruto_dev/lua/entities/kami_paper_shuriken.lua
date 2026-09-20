--========================================================
-- Shuriken de papier (entité projectile, SERVEUR + CLIENT)
-- Vole en ligne droite, tourne sur lui-même, laisse une traînée de papier.
-- Le serveur trace sa trajectoire à chaque tick : il ne traverse ni les murs
-- ni les joueurs, même à grande vitesse.
--
-- Debug : "kami_shuriken_debug 1" dans la console affiche la zone de touche du
-- shuriken, les hitbox des joueurs / PNJ proches et le point d'impact.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Shuriken de papier"
ENT.Spawnable = false

ENT.Model     = "models/clan/ame/kami/foc_arme_shuriken_papier.mdl"
ENT.FX_TRAIL  = "[2]_paper_shuriken"
ENT.FX_IMPACT = "[2]_paper_impact"

-- Valeurs par défaut ; la technique les remplace au lancement (sv_kami_shuriken.lua)
ENT.Vitesse   = 2200
ENT.Degats    = 35
ENT.DureeVie  = 3
ENT.Echelle   = 2.5
ENT.Largeur   = 1       -- élargit l'étoile (axe Z du modèle) sans l'épaissir
ENT.Hauteur   = 1       -- allonge l'étoile en hauteur (axe X du modèle) sans l'épaissir

--[[
    Géométrie réelle du modèle (mesurée dans le .vvd) :
      l'étoile est dans le plan X-Z (12,84 x 12,84 u), épaisse de 0,6 u sur Y ;
      son origine est sur son BORD : le centre est à Z = 5,61.
]]
ENT.RayonBase  = 6.42                  -- demi-largeur de l'étoile à l'échelle 1

-- Multiplicateur de dégâts selon la partie du corps touchée
ENT.Zones = {
    [HITGROUP_HEAD]     = 2.0,
    [HITGROUP_CHEST]    = 1.0,
    [HITGROUP_STOMACH]  = 1.0,
    [HITGROUP_LEFTARM]  = 0.75,
    [HITGROUP_RIGHTARM] = 0.75,
    [HITGROUP_LEFTLEG]  = 0.75,
    [HITGROUP_RIGHTLEG] = 0.75,
}

-- Debug partagé serveur/client (réglable par l'hôte / un admin)
local cvDebug = CreateConVar("kami_shuriken_debug", "0", { FCVAR_REPLICATED, FCVAR_ARCHIVE },
    "Affiche les hitbox et la zone de touche du shuriken de papier (0/1)")

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "SpinSpeed")
    self:NetworkVar("Float", 1, "Rayon")
    self:NetworkVar("Float", 2, "Vitesse")
    self:NetworkVar("Float", 3, "Largeur")
    self:NetworkVar("Float", 4, "Hauteur")
    self:NetworkVar("Float", 5, "RayonH")   -- demi-hauteur de la zone de touche
    -- direction du lancer, envoyée aux clients pour orienter modèle et particules
    self:NetworkVar("Vector", 0, "Dir")
end

-- Les cinq couloirs de trace : centre, bords droit/gauche (largeur) et haut/bas (hauteur)
local function Couloirs(dir, rayon, rayonH)
    local a = dir:Angle()
    local cote = a:Right() * rayon
    local haut = a:Up() * (rayonH or rayon)
    return { vector_origin, cote, -cote, haut, -haut }
end

if SERVER then
    util.AddNetworkString("kami_shuriken_dbg")

    local NOMS_ZONES = {
        [HITGROUP_HEAD] = "TÊTE", [HITGROUP_CHEST] = "torse", [HITGROUP_STOMACH] = "ventre",
        [HITGROUP_LEFTARM] = "bras gauche", [HITGROUP_RIGHTARM] = "bras droit",
        [HITGROUP_LEFTLEG] = "jambe gauche", [HITGROUP_RIGHTLEG] = "jambe droite",
    }

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)

        self:SetSpinSpeed(1440)
        self:SetLargeur(self.Largeur)
        self:SetHauteur(self.Hauteur)
        -- la zone de touche suit la taille visible de l'étoile
        self:SetRayon(self.RayonBase * self.Echelle * self.Largeur)
        self:SetRayonH(self.RayonBase * self.Echelle * self.Hauteur)
        self:SetVitesse(self.Vitesse)

        self.MortA = CurTime() + self.DureeVie
        self.Direction = self.Direction or self:GetForward()

        self:SetDir(self.Direction)
        self:SetAngles(self.Direction:Angle())
    end

    function ENT:Impact(tr)
        if self.Fini then return end
        self.Fini = true

        local hit = tr.Entity
        local owner = self:GetOwner()
        local degats = 0

        if IsValid(hit) and hit ~= owner and (hit:IsPlayer() or hit:IsNPC() or hit:IsNextBot()) then
            -- la hitbox touchée décide des dégâts (tête x2, membres x0.75...)
            local mult = self.Zones[tr.HitGroup] or 1
            degats = self.Degats * mult

            local dmg = DamageInfo()
            dmg:SetDamage(degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(tr.HitPos)
            dmg:SetDamageForce(self.Direction * 3000)
            hit:TakeDamageInfo(dmg)

            -- sang à l'endroit exact de la hitbox touchée
            local fx = EffectData()
            fx:SetOrigin(tr.HitPos)
            fx:SetNormal(tr.HitNormal)
            util.Effect("BloodImpact", fx)

            hit:EmitSound("physics/flesh/flesh_impact_bullet" .. math.random(1, 5) .. ".wav", 70, 110)
        elseif IsValid(hit) then
            -- objet du décor : on lui donne juste un coup
            local phys = hit:GetPhysicsObject()
            if IsValid(phys) then phys:ApplyForceOffset(self.Direction * 2000, tr.HitPos) end
        else
            self:EmitSound("physics/cardboard/cardboard_box_impact_hard" .. math.random(1, 7) .. ".wav", 70, 120)
        end

        ParticleEffect(self.FX_IMPACT, tr.HitPos, tr.HitNormal:Angle())

        -- Debug : point d'impact pour tout le monde + détail dans le chat du lanceur
        if cvDebug:GetBool() then
            net.Start("kami_shuriken_dbg")
                net.WriteVector(tr.HitPos)
                net.WriteUInt(tr.HitGroup or 0, 4)
                net.WriteBool(degats > 0)
            net.Broadcast()

            if IsValid(owner) then
                if degats > 0 then
                    owner:ChatPrint(string.format("[Shuriken debug] %s touché — zone : %s (hitgroup %d) — %.0f dégâts",
                        hit:IsPlayer() and hit:Nick() or hit:GetClass(),
                        NOMS_ZONES[tr.HitGroup] or "générique", tr.HitGroup or 0, degats))
                else
                    owner:ChatPrint("[Shuriken debug] impact décor : " .. (IsValid(hit) and hit:GetClass() or "monde"))
                end
            end
        end

        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end

        if CurTime() > self.MortA then
            self:Remove()
            return
        end

        local dt = FrameTime()
        local from = self:GetPos()
        local step = self.Direction * self.Vitesse * dt
        local to = from + step

        local owner = self:GetOwner()

        -- TraceLine + MASK_SHOT = test sur les HITBOX des joueurs et PNJ
        -- (TraceHull, lui, ne voit que leur boîte englobante).
        local best
        for _, off in ipairs(Couloirs(self.Direction, self:GetRayon(), self:GetRayonH())) do
            local tr = util.TraceLine({
                start = from + off,
                endpos = to + off,
                filter = { self, owner },
                mask = MASK_SHOT,
            })

            if tr.Hit then
                -- on garde l'impact le plus proche ; à distance égale, une
                -- créature passe avant le décor
                local vivant = IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC() or tr.Entity:IsNextBot())
                if not best
                    or tr.Fraction < best.tr.Fraction - 0.001
                    or (vivant and not best.vivant and tr.Fraction <= best.tr.Fraction + 0.001) then
                    best = { tr = tr, vivant = vivant }
                end
            end
        end

        if best then
            -- le projectile s'arrête là où la trace a touché
            self:SetPos(from + step * best.tr.Fraction)
            self:Impact(best.tr)
            return
        end

        self:SetPos(to)
        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    --[[
        Réglages d'orientation, modifiables EN JEU dans la console :
          kami_shuriken_fx_yaw 0        tourne la traînée autour de la verticale (en degrés)
          kami_shuriken_model_pitch 90  inclinaison du modèle (orientation validée : 90)
    ]]
    local cvFxYaw      = CreateClientConVar("kami_shuriken_fx_yaw", "0", true, false, "Orientation de la traînée du shuriken de papier")
    local cvModelPitch = CreateClientConVar("kami_shuriken_model_pitch", "90", true, false, "Inclinaison du modèle du shuriken de papier")

    local function Direction(ent)
        local dir = ent:GetDir()
        if not dir or dir:LengthSqr() < 0.01 then dir = ent:GetForward() end
        return dir
    end

    --[[
        Orientation de la traînée.
        Dans atg_faris.pcf, [2]_paper_shuriken lance ses petits shurikens à 700 u/s
        le long de l'axe LOCAL +Y de son point de contrôle ("speed in local coordinate
        system = 0 700 0"). Dans Source, +Y = la GAUCHE : c'est donc cet axe, et non
        l'avant, qu'il faut aligner sur la direction du lancer.
    ]]
    local function OrienterTrainee(ent)
        if not IsValid(ent.FX) then return end

        local dir = Direction(ent)
        if cvFxYaw:GetFloat() ~= 0 then
            local a = dir:Angle()
            a:RotateAroundAxis(Vector(0, 0, 1), cvFxYaw:GetFloat())
            dir = a:Forward()
        end

        local gauche = dir                                  -- +Y local = direction du lancer
        local haut = Vector(0, 0, 1) - gauche * gauche.z    -- vertical, rendu perpendiculaire
        if haut:LengthSqr() < 0.001 then haut = Vector(1, 0, 0) end
        haut:Normalize()
        local avant = gauche:Cross(haut)                    -- X = Y x Z

        ent.FX:SetControlPoint(0, ent:GetPos())
        ent.FX:SetControlPointOrientation(0, avant, -gauche, haut)
    end

    function ENT:Initialize()
        -- PATTACH_CUSTOMORIGIN : on pilote nous-mêmes position ET orientation du
        -- point de contrôle (le mode "follow" ne transmet pas l'orientation).
        self.FX = CreateParticleSystem(self, self.FX_TRAIL, PATTACH_CUSTOMORIGIN, 0)
        OrienterTrainee(self)
        self.Spin = 0
    end

    function ENT:Think()
        OrienterTrainee(self)
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        OrienterTrainee(self)

        -- rotation visuelle uniquement (le serveur ne gère que la trajectoire)
        self.Spin = ((self.Spin or 0) + FrameTime() * self:GetSpinSpeed()) % 360

        -- Orientation validée (celle d'avant l'agrandissement) :
        -- 1) regarde dans la direction du lancer
        local ang = Direction(self):Angle()
        -- 2) inclinaison du modèle
        ang:RotateAroundAxis(ang:Right(), cvModelPitch:GetFloat())
        -- 3) rotation sur lui-même
        ang:RotateAroundAxis(ang:Forward(), self.Spin)

        -- Taille : avec cette orientation, l'axe X du modèle est vertical (hauteur)
        -- et l'axe Z horizontal (largeur). L'épaisseur (axe Y) ne bouge pas.
        local largeur = self:GetLargeur()
        local hauteur = self:GetHauteur()
        if largeur <= 0 then largeur = 1 end
        if hauteur <= 0 then hauteur = 1 end

        local key = hauteur .. "_" .. largeur
        if self.TailleAppliquee ~= key then
            local m = Matrix()
            m:Scale(Vector(hauteur, 1, largeur))
            self:EnableMatrix("RenderMultiply", m)
            self.TailleAppliquee = key
        end

        self:SetRenderAngles(ang)
        self:DrawModel()
        self:SetRenderAngles(nil)
    end

    function ENT:OnRemove()
        if IsValid(self.FX) then self.FX:StopEmission() end
        self:StopParticles()
    end

    ------------------------------------------------------
    -- DEBUG (kami_shuriken_debug 1)
    ------------------------------------------------------
    local COL_ZONE   = Color(0, 200, 255)
    local COL_LANE   = Color(255, 220, 0)
    local COL_HEAD   = Color(255, 40, 40)
    local COL_BODY   = Color(40, 255, 80)
    local COL_IMPACT = Color(255, 0, 255)

    local impacts = {}

    net.Receive("kami_shuriken_dbg", function()
        impacts[#impacts + 1] = {
            pos = net.ReadVector(),
            group = net.ReadUInt(4),
            vivant = net.ReadBool(),
            fin = CurTime() + 4,
        }
    end)

    -- Hitbox réelles d'un joueur / PNJ (celles que testent les traces MASK_SHOT)
    local function DessinerHitbox(ent)
        local set = ent:GetHitboxSet() or 0
        for i = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
            local bone = ent:GetHitBoxBone(i, set)
            local mins, maxs = ent:GetHitBoxBounds(i, set)
            if bone and mins then
                local m = ent:GetBoneMatrix(bone)
                if m then
                    local col = ent:GetHitBoxHitGroup(i, set) == HITGROUP_HEAD and COL_HEAD or COL_BODY
                    render.DrawWireframeBox(m:GetTranslation(), m:GetAngles(), mins, maxs, col, true)
                end
            end
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "KamiShuriken_Debug", function(depth, sky)
        if sky or not cvDebug:GetBool() then return end

        local me = LocalPlayer()
        local shurikens = ents.FindByClass("kami_paper_shuriken")

        -- hitbox des cibles possibles autour de toi
        for _, ent in ipairs(ents.FindInSphere(me:GetPos(), 1500)) do
            if (ent:IsPlayer() and ent:Alive()) or ent:IsNPC() or ent:IsNextBot() then
                if ent ~= me or me:ShouldDrawLocalPlayer() then
                    DessinerHitbox(ent)
                end
            end
        end

        -- zone de touche de chaque shuriken : la lame + les 5 couloirs sur 0,1 s
        for _, s in ipairs(shurikens) do
            local dir = Direction(s)
            local rayon = s:GetRayon()
            local rayonH = s:GetRayonH()
            local pos = s:GetPos()
            local ahead = dir * s:GetVitesse() * 0.1

            render.DrawWireframeBox(pos, dir:Angle(), Vector(-2, -rayon, -rayonH), Vector(2, rayon, rayonH), COL_ZONE, true)
            for _, off in ipairs(Couloirs(dir, rayon, rayonH)) do
                render.DrawLine(pos + off, pos + off + ahead, COL_LANE, true)
            end
        end

        -- impacts récents
        for i = #impacts, 1, -1 do
            local imp = impacts[i]
            if CurTime() > imp.fin then
                table.remove(impacts, i)
            else
                render.DrawWireframeSphere(imp.pos, 4, 8, 8, imp.vivant and COL_HEAD or COL_IMPACT, true)
            end
        end
    end)
end
