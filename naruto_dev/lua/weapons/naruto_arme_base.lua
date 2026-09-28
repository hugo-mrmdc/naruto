--========================================================
-- Base commune des armes Naruto (épées, haches, shuriken géant...)
--
-- Chaque arme (lua/weapons/<arme>/shared.lua) ne contient QUE ses réglages :
-- modèles, animations, combo, attaque spéciale. Toute la logique est ici :
--   - combo au clic gauche, zone de frappe qui touche TOUS les ennemis devant ;
--   - attaque spéciale au clic droit (explosions devant soi par défaut) ;
--   - modèles en main (1 ou 2 mains) et dans le dos quand l'arme est rangée ;
--   - animations d'attente / marche / course de l'arme. En course de chakra,
--     c'est l'animation de course de chakra qui passe (cl_sprint_chakra.lua).
--
-- Debug des zones de frappe : developer 1 + na_arme_debug 1
--========================================================

AddCSLuaFile()

SWEP.Base      = "weapon_base"
SWEP.PrintName = "Arme Naruto (base)"
SWEP.Category  = "Naruto"
SWEP.Spawnable = false
SWEP.NA_Arme   = true      -- repère utilisé par les autres scripts (course, etc.)

SWEP.HoldType      = "melee"
SWEP.UseHands      = true
SWEP.DrawAmmo      = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

--========================================================
-- RÉGLAGES PAR DÉFAUT (chaque arme remplace ce qu'elle veut)
--========================================================

-- Modèle en main : { modele, echelle, pos, rot }   (MainGauche = nil -> une seule main)
SWEP.MainDroite = nil
SWEP.MainGauche = nil

-- Modèle dans le dos quand l'arme est rangée :
--   { modele, echelle, os = { "os1", "os2 si os1 absent", ... }, pos, ang, mode }
--   mode "accessoire" : même placement que les accessoires (rotation puis décalage)
--   mode "local"      : décalage et rotation dans le repère de l'os (LocalToWorld)
SWEP.Dos = nil

-- Animations de déplacement avec l'arme en main (nil = animation de base)
SWEP.Anims = {
    idle        = nil,
    marche      = nil,
    course      = nil,
    seuilMarche = 10,    -- vitesse à partir de laquelle on marche
    seuilCourse = 120,   -- vitesse à partir de laquelle on court
    idleDesArret = false, -- true = idle dès qu'on relâche les touches de déplacement
}

-- Combo du clic gauche. Chaque coup :
--   anim, duree (s, avant le coup suivant), degats,
--   coups (nombre de touches sur une même cible), intervalle (s entre deux touches),
--   sons (nombre de sons de swing joués)
--   vitesseAnim (vitesse de l'animation du coup : 1 = normale, 1.5 = 50 % plus rapide,
--                0.8 = plus lente ; absente = SWEP.VitesseAnim)
--   optionnels :
--                portee (remplace celle de SWEP.Frappe), recul / reculHaut (projette la cible),
--                delai / dureeFrappe (remplacent ceux de SWEP.Frappe)
SWEP.Combo = {
    { anim = "nrp_sword_slashhorizon",         duree = 1.0, degats = 40 },
    { anim = "nrp_sword_turnslashingshoulder", duree = 1.1, degats = 40 },
    { anim = "nrp_sword_slashing",             duree = 1.3, degats = 40 },
}
SWEP.FonduAnim  = 0.25 -- secondes de fondu à la fin d'une attaque (retour en douceur à l'animation normale)
SWEP.VitesseAnim = 1.0  -- vitesse des animations d'attaque (si le coup n'a pas son propre "vitesseAnim")
SWEP.ComboReset = 2.0   -- secondes sans frapper avant de revenir au 1er coup

-- Zone de frappe devant le joueur
SWEP.Frappe = {
    portee  = 80,    -- distance devant soi
    largeur = 35,    -- demi-largeur
    hauteur = 40,    -- demi-hauteur
    delai   = 0,     -- secondes après le début du coup avant que la zone soit active
    duree   = 0.6,   -- secondes pendant lesquelles la zone touche
}
SWEP.SonSwing   = Sound("fuma/swing1.wav")
SWEP.SonImpact  = nil          -- son quand un coup touche (nil = aucun)
SWEP.TypeDegats = DMG_SLASH    -- DMG_CLUB pour les coups de poing / pied

-- Slash du clic gauche (optionnel, réglages propres à cette arme ; voir la liste complète
-- dans lua/autorun/client/cl_slash_arme.lua). Angles X Y Z par coup, en degrés :
-- X = roulis (90 = vertical), Y = bascule (négatif = lève l'avant), Z = cap.
--   SWEP.Slash = {
--       angles  = { {x = 0, y = -25, z = 0}, {x = -45, y = -25, z = 0}, {x = 90, y = -40, z = 0} },
--       couleur = "bleu", echelle = 2, alpha = 160,
--   }
-- SWEP.Slash = false : PAS de slash pour cette arme (poings, armes sans swing...)
SWEP.Slash = nil

-- Explosion différée (optionnel) : quand un même ennemi est touché "coups" fois par le clic
-- gauche, une explosion se déclenche sur lui "delai" secondes plus tard. nil = aucune.
--   coups (nombre de touches), delai (s), expire (s sans toucher avant que le compte reparte à 0),
--   rayon, degats, recul / reculHaut (projection des joueurs), particule, son,
--   sonMarque (son au moment où l'ennemi est marqué, facultatif)
--   SWEP.Explosif = { coups = 3, delai = 1, rayon = 130, degats = 45, particule = "...", son = "..." }
SWEP.Explosif = nil

-- Attaque spéciale (clic droit). nil = pas d'attaque spéciale.
--   anim, vitesseAnim (vitesse de son animation, 1 = normale),
--   explosions : { { delai, distance }, ... } devant le joueur
SWEP.Special = nil
--========================================================

if SERVER then
    util.AddNetworkString("NA_Arme_Anim")
    util.AddNetworkString("NA_Arme_Slash")   -- effet de slash (cl_slash_arme.lua)
end

-- Particules communes aux attaques spéciales
game.AddParticles("particles/naruto_fw.pcf")
game.AddParticles("particles/atg_orugi_particle.pcf")
game.AddParticles("particles/julio.pcf")
PrecacheParticleSystem("[2]_concasse_blast")
PrecacheParticleSystem("smoke_orugi2")

-- Le joueur appuie-t-il sur une touche de déplacement ? (pour "idleDesArret")
-- Le serveur le partage aux autres joueurs ; pour soi-même, on lit ses touches.
hook.Add("SetupMove", "NA_Arme_Bouge", function(ply, mv)
    if not SERVER then return end
    local bouge = mv:GetForwardSpeed() ~= 0 or mv:GetSideSpeed() ~= 0
    if ply:GetNW2Bool("NA_Bouge", false) ~= bouge then
        ply:SetNW2Bool("NA_Bouge", bouge)
    end
end)

local function Bouge(ply)
    if CLIENT and ply == LocalPlayer() then
        return ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_BACK)
            or ply:KeyDown(IN_MOVELEFT) or ply:KeyDown(IN_MOVERIGHT)
    end
    return ply:GetNW2Bool("NA_Bouge", false)
end

local cvDebug = CreateConVar("na_arme_debug", "0", { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "1 = affiche les zones de frappe des armes (il faut aussi developer 1)")

-- Zones de frappe affichées dès que le mode développeur est actif (developer 1),
-- comme pour les techniques ; na_arme_debug 1 les force aussi.
local function Debug()
    local dev = GetConVar("developer")
    return cvDebug:GetBool() or (dev and dev:GetInt() > 0)
end

function SWEP:SetupDataTables()
    self:NetworkVar("Int",   0, "Combo")         -- dernier coup joué (1..n)
    self:NetworkVar("Float", 0, "DernierCoup")   -- moment du dernier coup
    self:NetworkVar("Float", 1, "Occupe")        -- attaque en cours jusqu'à
    self:NetworkVar("Float", 2, "SpecialPret")   -- attaque spéciale disponible à
end

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

-- Joue une animation d'attaque sur le joueur chez tout le monde
local function JouerAnim(ply, nom, vitesse)
    if not SERVER or not nom or nom == "" then return end
    net.Start("NA_Arme_Anim")
        net.WriteEntity(ply)
        net.WriteString(nom)
        net.WriteFloat(vitesse or 1)
    net.Broadcast()
end

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    -- PNJ : tant qu'il n'est pas mort (même à 0 PV, il doit pouvoir être achevé)
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

--========================================================
-- Clic gauche : combo
--========================================================
-- Pendant un vol de technique (rayon Jinton...) ou pendant les mudras d'une
-- technique (_na_mudra.lua), on ne frappe pas : l'animation de la technique
-- reste affichée
local function VolTechnique(owner)
    if NA_EnMudra and NA_EnMudra(owner) then return true end
    if NA_EnRechargeChakra and NA_EnRechargeChakra(owner) then return true end   -- recharge du chakra (R)
    return owner:GetNW2Bool("NA_Vol", false)
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) or VolTechnique(owner) then return end

    local now = CurTime()
    if now < self:GetOccupe() then return end

    local combo = self.Combo
    local index = self:GetCombo() + 1
    if now - self:GetDernierCoup() > self.ComboReset or index > #combo then
        index = 1
    end
    local coup = combo[index]

    self:SetCombo(index)
    self:SetDernierCoup(now)
    self:SetOccupe(now + coup.duree)
    self:SetNextPrimaryFire(now + coup.duree)

    if not SERVER then return end

    -- frapper coupe la course de chakra (sv_sprint_chakra.lua)
    if NA_StopChakraRun then NA_StopChakraRun(owner) end

    JouerAnim(owner, coup.anim, coup.vitesseAnim or coup.vitesse or self.VitesseAnim)   -- "vitesse" : ancien nom

    -- sons de swing (plusieurs pour les coups multiples)
    local sons = coup.sons or 1
    local ecart = coup.intervalle or 0.15
    for i = 0, sons - 1 do
        timer.Simple(i * ecart, function()
            if IsValid(self) then self:EmitSound(self.SonSwing) end
        end)
    end

    -- effet de slash chez tout le monde (un par touche pour les coups multiples)
    -- SWEP.Slash = false : pas de slash pour cette arme (poings...)
    if self.Slash ~= false then
        for i = 0, sons - 1 do
            timer.Simple(i * ecart, function()
                if not IsValid(self) or not IsValid(owner) then return end
                net.Start("NA_Arme_Slash")
                    net.WriteEntity(owner)
                    net.WriteUInt(index, 4)
                net.Broadcast()
            end)
        end
    end

    local f = self.Frappe
    self.Attaque = {
        debut      = now + (coup.delai or f.delai or 0),
        fin        = now + (coup.delai or f.delai or 0) + (coup.dureeFrappe or f.duree),
        degats     = coup.degats,
        coups      = coup.coups or 1,
        intervalle = coup.intervalle or 0,
        portee     = coup.portee,
        recul      = coup.recul,
        reculHaut  = coup.reculHaut,
        touches    = {},
    }
end

-- Tous les ennemis dans la zone devant le joueur (et pas derrière un mur)
function SWEP:CiblesDansLaZone(owner, portee)
    local f = table.Copy(self.Frappe)
    f.portee = portee or f.portee
    local origine = owner:GetShootPos()
    local dir = owner:GetAimVector()
    local cibles = {}

    for _, ent in ipairs(ents.FindInSphere(origine, f.portee + f.largeur + 32)) do
        if not EstCible(ent, owner) then continue end

        local centre = ent:WorldSpaceCenter()
        local v = centre - origine
        local avant = v:Dot(dir)
        if avant < -16 or avant > f.portee + 16 then continue end

        local ecart = v - dir * avant
        if ecart:Length2D() > f.largeur + 16 or math.abs(ecart.z) > f.hauteur + 36 then continue end

        local tr = util.TraceLine({ start = origine, endpos = centre, mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then continue end

        cibles[#cibles + 1] = ent
    end

    if Debug() then
        local fin = origine + dir * f.portee
        local mins, maxs = Vector(-15, -f.largeur, -f.hauteur), Vector(15, f.largeur, f.hauteur)
        debugoverlay.SweptBox(origine, fin, mins, maxs, dir:Angle(), 0.05, Color(0, 255, 0, 60))
    end

    return cibles
end

-- Compte les touches sur chaque ennemi et programme l'explosion différée (SWEP.Explosif)
local marques = setmetatable({}, { __mode = "k" })   -- [arme] = { [ennemi] = { n, dernier, pos, enAttente } }

function SWEP:CompterCoup(owner, ent)
    local cfg = self.Explosif
    if not cfg then return end

    local now = CurTime()
    marques[self] = marques[self] or setmetatable({}, { __mode = "k" })
    local m = marques[self][ent]
    if not m or now - m.dernier > (cfg.expire or 4) then
        m = { n = 0, dernier = now }
        marques[self][ent] = m
    end
    if m.enAttente then return end   -- une explosion est déjà prévue sur lui

    m.n = m.n + 1
    m.dernier = now
    m.pos = ent:WorldSpaceCenter()
    if m.n < (cfg.coups or 3) then return end

    -- touché assez de fois : il explose dans "delai" secondes
    m.enAttente = true
    if cfg.sonMarque then ent:EmitSound(cfg.sonMarque, 70, 100) end

    timer.Simple(cfg.delai or 1, function()
        if marques[self] then marques[self][ent] = nil end
        if not IsValid(self) or not IsValid(owner) then return end

        local pos = IsValid(ent) and ent:WorldSpaceCenter() or m.pos   -- s'il est mort : là où il était
        if cfg.particule then ParticleEffect(cfg.particule, pos, angle_zero) end
        if cfg.son then sound.Play(cfg.son, pos, 85, 100, 1) end

        local rayon = cfg.rayon or 130
        for _, cible in ipairs(ents.FindInSphere(pos, rayon)) do
            if not EstCible(cible, owner) then continue end

            local attenuation = 1 - math.Clamp(cible:WorldSpaceCenter():Distance(pos) / rayon, 0, 1) * 0.5

            local dmg = DamageInfo()
            dmg:SetDamage((cfg.degats or 45) * attenuation)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(pos)
            cible:TakeDamageInfo(dmg)

            if cible:IsPlayer() and ((cfg.recul or 0) > 0 or (cfg.reculHaut or 0) > 0) then
                local dir = cible:GetPos() - pos
                dir.z = 0
                if dir:LengthSqr() < 1 then dir = owner:GetForward() end
                dir:Normalize()
                cible:SetVelocity(dir * (cfg.recul or 0) * attenuation + Vector(0, 0, cfg.reculHaut or 0))
            end
        end

        if Debug() then debugoverlay.Sphere(pos, rayon, 1, Color(255, 120, 0, 40), true) end
    end)
end

function SWEP:Think()
    -- type de prise toujours à jour (même si le fichier de l'arme a été modifié
    -- alors qu'elle était déjà en main)
    if self.GetHoldType and self:GetHoldType() ~= self.HoldType then
        self:SetHoldType(self.HoldType)
    end

    if not SERVER then return end

    local a = self.Attaque
    if not a then return end

    local now = CurTime()
    if now > a.fin then self.Attaque = nil return end
    if now < a.debut then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:Alive() then self.Attaque = nil return end

    for _, ent in ipairs(self:CiblesDansLaZone(owner, a.portee)) do
        local t = a.touches[ent]
        if not t then
            t = { n = 0, derniere = 0 }
            a.touches[ent] = t
        end

        if t.n < a.coups and now - t.derniere >= a.intervalle then
            t.n = t.n + 1
            t.derniere = now

            local dmg = DamageInfo()
            dmg:SetDamage(a.degats)
            dmg:SetAttacker(owner)
            dmg:SetInflictor(self)
            dmg:SetDamageType(self.TypeDegats or DMG_SLASH)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            dmg:SetDamageForce(owner:GetAimVector() * 2000)
            ent:TakeDamageInfo(dmg)
            self:CompterCoup(owner, ent)

            if self.SonImpact then ent:EmitSound(self.SonImpact, 75, math.random(95, 105)) end

            if ((a.recul or 0) > 0 or (a.reculHaut or 0) > 0) and ent:IsPlayer() then
                local dir = owner:GetAimVector()
                dir.z = 0
                dir:Normalize()
                ent:SetVelocity(dir * (a.recul or 0) + Vector(0, 0, a.reculHaut or 0))
            end

            if Debug() then
                debugoverlay.Cross(ent:WorldSpaceCenter(), 15, 0.5, Color(255, 0, 0), true)
            end
        end
    end
end

--========================================================
-- Clic droit : attaque spéciale
--========================================================
function SWEP:SecondaryAttack()
    local s = self.Special
    if not s then return end

    local owner = self:GetOwner()
    if not IsValid(owner) or VolTechnique(owner) then return end

    local now = CurTime()
    if now < self:GetOccupe() then return end

    if now < self:GetSpecialPret() then
        if SERVER and (self.ProchainMessage or 0) < now then
            self.ProchainMessage = now + 1
            owner:PrintMessage(HUD_PRINTCENTER, string.format("%s disponible dans %d s",
                s.nom or "Attaque spéciale", math.ceil(self:GetSpecialPret() - now)))
        end
        return
    end

    self:SetSpecialPret(now + s.recharge)
    self:SetOccupe(now + s.duree)
    self:SetNextSecondaryFire(now + s.duree)
    self:SetNextPrimaryFire(now + s.duree)

    if not SERVER then return end

    self.Attaque = nil
    if NA_StopChakraRun then NA_StopChakraRun(owner) end
    JouerAnim(owner, s.anim, s.vitesseAnim or 1)
    self:LancerSpecial(owner, s)
end

-- Attaque spéciale par défaut : explosions successives devant le joueur.
-- Chaque explosion : delai, distance (devant soi), cote (optionnel, décalage
-- latéral : négatif = gauche, positif = droite, absent/0 = centré).
-- Une arme peut la remplacer en définissant sa propre fonction SWEP:LancerSpecial.
function SWEP:LancerSpecial(owner, s)
    for _, e in ipairs(s.explosions or {}) do
        timer.Simple(e.delai, function()
            if not IsValid(self) or not IsValid(owner) or not owner:Alive() then return end
            if owner:GetActiveWeapon() ~= self then return end

            local ang = owner:EyeAngles()
            local pos = owner:GetShootPos() + owner:GetAimVector() * e.distance + ang:Right() * (e.cote or 0)
            if s.particule then ParticleEffect(s.particule, pos, ang) end
            if s.son then self:EmitSound(s.son) end

            for _, ent in ipairs(ents.FindInSphere(pos, s.rayon)) do
                if not EstCible(ent, owner) then continue end

                local attenuation = 1 - math.Clamp(ent:GetPos():Distance(pos) / s.rayon, 0, 1)

                local dmg = DamageInfo()
                dmg:SetDamage(s.degats * attenuation)
                dmg:SetAttacker(owner)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)

                if ent:IsPlayer() and (s.recul or 0) > 0 then
                    local dir = (ent:GetPos() - pos):GetNormalized()
                    ent:SetVelocity(dir * s.recul * attenuation + Vector(0, 0, s.reculHaut or 0))
                end
            end

            if Debug() then
                debugoverlay.Sphere(pos, s.rayon, 1, Color(255, 0, 0, 40), true)
            end
        end)
    end
end

--========================================================
-- Sortie / rangement
--========================================================
function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

function SWEP:Holster()
    self.Attaque = nil
    if CLIENT then self:SupprimerModeles() end
    return true
end

function SWEP:OnRemove()
    if CLIENT then self:SupprimerModeles() end
end

function SWEP:OwnerChanged()
    if CLIENT then self:SupprimerModeles() end
end

--========================================================
-- CLIENT : modèles et animations
--========================================================
if not CLIENT then return end

function SWEP:SupprimerModeles()
    for _, cle in ipairs({ "_ModeleDroite", "_ModeleGauche" }) do
        if IsValid(self[cle]) then self[cle]:Remove() end
        self[cle] = nil
    end
end

-- Dessine un modèle avec ses propres couleurs : sans ça, il reprend la teinte
-- et la transparence du joueur sur lequel il est dessiné.
-- eclairageNeutre = éclairage fixe, comme les accessoires (pas celui de la map).
local function DessinerPropre(m, eclairageNeutre)
    local r, g, b = render.GetColorModulation()
    local blend = render.GetBlend()
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)

    if eclairageNeutre then
        render.SuppressEngineLighting(true)
        render.SetLightingOrigin(m:GetPos())
        render.ResetModelLighting(1, 1, 1)
    end

    m:DrawModel()

    if eclairageNeutre then
        render.SuppressEngineLighting(false)
        render.SetLightingOrigin(vector_origin)
    end
    render.SetColorModulation(r, g, b)
    render.SetBlend(blend)
end

local function CreerModele(cfg)
    local m = ClientsideModel(cfg.modele, RENDERGROUP_OPAQUE)
    if not IsValid(m) then return end
    m:SetNoDraw(true)
    m:SetModelScale(cfg.echelle or 1, 0)
    return m
end

-- Modèle posé sur un os de la main : décalage dans le repère de l'os, puis rotation
local function DessinerEnMain(m, ply, nomOs, cfg)
    local os = ply:LookupBone(nomOs)
    if not os then return end
    local pos, ang = ply:GetBonePosition(os)
    if not pos then return end

    local d, r = cfg.pos or vector_origin, cfg.rot or angle_zero
    pos = pos + ang:Forward() * d.x + ang:Right() * d.y + ang:Up() * d.z

    ang = Angle(ang)
    ang:RotateAroundAxis(ang:Right(), r.p)
    ang:RotateAroundAxis(ang:Up(), r.y)
    ang:RotateAroundAxis(ang:Forward(), r.r)

    m:SetPos(pos)
    m:SetAngles(ang)
    DessinerPropre(m, false)
end

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    if not IsValid(owner) then
        self:DrawModel()   -- arme posée au sol
        return
    end

    -- placement du dos en cours de réglage (menu F4) : l'arme est montrée dans le dos, pas en main
    if owner == LocalPlayer() and NA_DosEdition and NA_DosEdition.classe == self:GetClass() then return end

    if self.MainDroite then
        if not IsValid(self._ModeleDroite) then self._ModeleDroite = CreerModele(self.MainDroite) end
        if IsValid(self._ModeleDroite) then
            DessinerEnMain(self._ModeleDroite, owner, "ValveBiped.Bip01_R_Hand", self.MainDroite)
        end
    end

    if self.MainGauche then
        if not IsValid(self._ModeleGauche) then self._ModeleGauche = CreerModele(self.MainGauche) end
        if IsValid(self._ModeleGauche) then
            DessinerEnMain(self._ModeleGauche, owner, "ValveBiped.Bip01_L_Hand", self.MainGauche)
        end
    end
end

-- Animations d'attaque envoyées par le serveur
net.Receive("NA_Arme_Anim", function()
    local ply = net.ReadEntity()
    local nom = net.ReadString()
    local vitesse = net.ReadFloat()
    if not IsValid(ply) then return end

    local seq = ply:LookupSequence(nom)
    if seq and seq >= 0 then
        ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        ply:AnimSetGestureWeight(GESTURE_SLOT_ATTACK_AND_RELOAD, 0)
        -- l'emplacement de geste correspond au calque d'animation du même numéro
        if vitesse > 0 and vitesse ~= 1 then
            ply:SetLayerPlaybackRate(GESTURE_SLOT_ATTACK_AND_RELOAD, vitesse)
        end

        local wep = ply:GetActiveWeapon()
        ply.NA_GesteArme = {
            debut = CurTime(),
            duree = ply:SequenceDuration(seq) / math.max(vitesse, 0.01),
            fondu = IsValid(wep) and wep.FonduAnim or 0.25,
            seq   = seq,   -- pour l'animation en l'air (voir plus bas)
        }
    end
end)

-- Fondu d'entrée (très court) et de sortie des animations d'attaque :
-- le personnage revient à son animation normale en douceur au lieu d'un à-coup.
local FONDU_ENTREE = 0.06

hook.Add("Think", "NA_Arme_FonduGeste", function()
    for _, ply in ipairs(player.GetAll()) do
        local g = ply.NA_GesteArme
        if not g then continue end

        local t = CurTime() - g.debut
        if t >= g.duree then
            ply.NA_GesteArme = nil
            ply:AnimSetGestureWeight(GESTURE_SLOT_ATTACK_AND_RELOAD, 0)
            continue
        end

        local entree = math.Clamp(t / FONDU_ENTREE, 0, 1)
        local sortie = g.fondu > 0 and math.Clamp((g.duree - t) / g.fondu, 0, 1) or 1
        local poids = math.min(entree, sortie)
        -- courbe douce plutôt que linéaire
        poids = poids * poids * (3 - 2 * poids)
        ply:AnimSetGestureWeight(GESTURE_SLOT_ATTACK_AND_RELOAD, poids)
    end
end)

----------------------------------------------------------
-- Coups donnés en l'air
-- Un geste superposé est masqué par l'animation de saut ; tant que le joueur est en
-- l'air pendant un coup, l'animation du coup devient donc l'animation principale
-- (même principe que cl_recharge_chakra.lua). Au sol, rien ne change.
----------------------------------------------------------
local function SeqEnLair(ply)
    local g = ply.NA_GesteArme
    if not g or not g.seq or ply:OnGround() or ply:GetMoveType() ~= MOVETYPE_WALK then return end
    if CurTime() - g.debut >= g.duree then return end
    return g.seq, g
end

hook.Add("CalcMainActivity", "NA_Arme_CoupEnLair", function(ply)
    local seq = SeqEnLair(ply)
    if seq then return ACT_MP_JUMP, seq end
end)

hook.Add("UpdateAnimation", "NA_Arme_CoupEnLair_Force", function(ply)
    local seq, g = SeqEnLair(ply)
    if not seq then return end

    -- le coup passe avant l'animation d'un jutsu / du double saut (nrp_base_doublejump), jouée
    -- dans le geste GESTURE_SLOT_CUSTOM par jutsu_anim_cl.lua, qui sinon la masque
    if (ply.NA_AnimFin or 0) > CurTime() then
        ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
        ply.NA_AnimFin = 0
        ply.NA_AnimJeton = (ply.NA_AnimJeton or 0) + 1
    end

    if ply:GetSequence() ~= seq then ply:SetSequence(seq) end
    ply:SetCycle(math.Clamp((CurTime() - g.debut) / g.duree, 0, 0.999))
    ply:SetPlaybackRate(0)   -- le cycle est réglé à la main chaque image : pas d'avance en plus
    return true
end)

----------------------------------------------------------
-- Animations de déplacement avec l'arme en main
----------------------------------------------------------
local function Sequence(ply, nom)
    if not nom then return end
    local seq = ply:LookupSequence(nom)
    if seq and seq >= 0 then return seq end
end

hook.Add("CalcMainActivity", "NA_Arme_Deplacement", function(ply, vel)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.NA_Arme or not wep.Anims then return end
    if ply:InVehicle() or ply:Crouching() or not ply:OnGround() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return end   -- en vol
    if ply:GetNW2Bool("NA_Etourdi", false) then return end   -- étourdi : son animation passe avant
    if ply:GetNW2Bool("NA_RechargeChakra", false) then return end   -- recharge du chakra : idem
    if ply:GetMoveType() ~= MOVETYPE_WALK then return end

    local a = wep.Anims
    local vitesse = vel:Length2D()

    -- touches relâchées : idle tout de suite, sans attendre que le perso ait fini de freiner
    if a.idleDesArret and not Bouge(ply) then
        local seq = Sequence(ply, a.idle)
        if seq then return ACT_MP_STAND_IDLE, seq end
    end

    -- course de chakra vers l'avant : son animation passe avant celle de l'arme
    if vitesse > 60 and ply:GetNW2Bool("NA_ChakraRun", false)
        and (not NA_SprintChakra or NA_SprintChakra.MouvementVersLAvant(ply)) then
        return
    end

    if vitesse > (a.seuilCourse or 120) then
        local seq = Sequence(ply, a.course)
        if seq then return ACT_MP_RUN, seq end
        return
    end

    if vitesse > (a.seuilMarche or 10) then
        local seq = Sequence(ply, a.marche)
        if seq then return ACT_MP_WALK, seq end
        return
    end

    local seq = Sequence(ply, a.idle)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

----------------------------------------------------------
-- Armes rangées : modèle dans le dos
----------------------------------------------------------
local function OsDuDos(ply, liste)
    if isstring(liste) then liste = { liste } end
    for _, nom in ipairs(liste) do
        local os = ply:LookupBone(nom)
        if os then return os end
    end
end

-- Placement du dos réglé par le joueur dans le menu F4 (sv_selecteur_armes.lua) :
-- NW2String "NA_EpeeDos" = JSON { [classe] = { x, y, z, p, ya, r, s } }
local cacheDos = {}
local function PlacementPerso(ply, classe)
    if ply == LocalPlayer() and NA_DosEdition and NA_DosEdition.classe == classe then
        return NA_DosEdition   -- réglage en cours dans l'éditeur : aperçu en direct
    end

    local brut = ply:GetNW2String("NA_EpeeDos", "")
    if brut == "" then return end

    local c = cacheDos[ply]
    if not c or c.brut ~= brut then
        c = { brut = brut, t = {} }
        for cl, p in pairs(util.JSONToTable(brut) or {}) do
            c.t[cl] = {
                pos = Vector(p.x or 0, p.y or 0, p.z or 0),
                ang = Angle(p.p or 0, p.ya or 0, p.r or 0),
                echelle = p.s,
            }
        end
        cacheDos[ply] = c
    end
    return c.t[classe]
end

local function DessinerDos(ply, m, cfg, classe)
    local os = OsDuDos(ply, cfg.os or "ValveBiped.Bip01_Spine4")
    if not os then return end
    local mat = ply:GetBoneMatrix(os)
    if not mat then return end

    local perso = PlacementPerso(ply, classe)
    local echelle = (perso and perso.echelle) or cfg.echelle or 1
    if m.NA_Echelle ~= echelle then
        m:SetModelScale(echelle, 0)
        m.NA_Echelle = echelle
    end

    local pos, ang = mat:GetTranslation(), mat:GetAngles()
    local d = (perso and perso.pos) or cfg.pos or vector_origin
    local r = (perso and perso.ang) or cfg.ang or angle_zero

    if cfg.mode == "local" then
        pos, ang = LocalToWorld(d, r, pos, ang)
    else
        ang = Angle(ang)
        ang:RotateAroundAxis(ang:Right(), r.p)
        ang:RotateAroundAxis(ang:Up(), r.y)
        ang:RotateAroundAxis(ang:Forward(), r.r)
        pos = pos + ang:Forward() * d.x + ang:Right() * d.y + ang:Up() * d.z
    end

    m:SetPos(pos)
    m:SetAngles(ang)
    DessinerPropre(m, cfg.mode ~= "local")
end

local function NettoyerDos(ply, garder)
    if not ply.NA_ModelesDos then return end
    for classe, m in pairs(ply.NA_ModelesDos) do
        if not (garder and garder[classe]) then
            if IsValid(m) then m:Remove() end
            ply.NA_ModelesDos[classe] = nil
        end
    end
end

hook.Add("PostPlayerDraw", "NA_Arme_Dos", function(ply)
    if not IsValid(ply) then return end
    if not ply:Alive() or ply:GetNWBool("IsInvisible", false) then
        NettoyerDos(ply)
        return
    end

    local active = ply:GetActiveWeapon()
    local dessinees = {}

    for _, wep in ipairs(ply:GetWeapons()) do
        local cfg = wep.NA_Arme and wep.Dos
        local classe = wep:GetClass()
        local enReglage = ply == LocalPlayer() and NA_DosEdition and NA_DosEdition.classe == classe
        if not cfg or (wep == active and not enReglage) then continue end

        ply.NA_ModelesDos = ply.NA_ModelesDos or {}
        local m = ply.NA_ModelesDos[classe]
        if not IsValid(m) then
            m = CreerModele(cfg)
            ply.NA_ModelesDos[classe] = m
        end

        if IsValid(m) then
            if not dessinees[1] then ply:SetupBones() end
            DessinerDos(ply, m, cfg, classe)
            dessinees[classe] = true
            dessinees[1] = true
        end
    end

    NettoyerDos(ply, dessinees)
end)

hook.Add("EntityRemoved", "NA_Arme_Dos_Nettoyage", function(ent)
    if ent:IsPlayer() then
        NettoyerDos(ent)
        cacheDos[ent] = nil
    end
end)
