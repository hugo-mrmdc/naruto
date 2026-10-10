--========================================================
-- Shuriken Fuma (tenu en main, lancé au clic droit)
-- Toute la logique commune est dans lua/weapons/naruto_arme_base.lua ;
-- ici : les réglages, et le lancer du shuriken qui remplace l'attaque spéciale.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Shuriken Fuma"
SWEP.Author    = "fuma"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true
SWEP.Rarete    = "legendaire"

SWEP.ViewModel  = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"
SWEP.WorldModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"

-- Modèle en main
SWEP.MainDroite = {
    modele  = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl",
    echelle = 0.6,
    pos     = Vector(5, 2, -3),
    rot     = Angle(45, 0, 80),
}

-- Dans le dos quand il est rangé
SWEP.Dos = {
    modele  = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl",
    echelle = 0.5,
    os      = { "ValveBiped.Bip01_UpperChest", "ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2" },
    pos     = Vector(-6, 2, 0),
    ang     = Angle(45, 30, 90),
    mode    = "local",
}

-- Animations de déplacement (la course de chakra garde la sienne)
SWEP.Anims = {
    idle        = "ryoku_r_idle",
    marche      = "walk_all",       -- marche normale, sans pose d'arme
    course      = "run_all_01",     -- course normale, sans pose d'arme
    seuilMarche = 10,
    seuilCourse = 250,
}

SWEP.Combo = {
    { anim = "ryoku_r_right_t1", vitesseAnim = 1.0, duree = 0.5, degats = 40 },
    { anim = "ryoku_r_left_t2",  vitesseAnim = 1.0, duree = 0.5, degats = 40 },
    { anim = "ryoku_r_right_t2", vitesseAnim = 1.0, duree = 1.3, degats = 40 },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : lance un shuriken qui explose au contact d'un ennemi
SWEP.Special = {
    nom         = "Shuriken",
    anim        = "nrp_ninjutsu_defend_d35nj2_throw",
    vitesseAnim = 1.0,    -- vitesse de l'animation (1 = normale)
    recharge    = 1,
    duree       = 0.8,
    son         = "fuma/throw_1.wav",
    delaiSon    = 0.4,
    delaiLancer = 0.6,
    modele      = "models/fumaSpell/orga_props_shuriken.mdl",
    vitesse     = 2400,    -- unités / seconde
    dureeAller  = 0.6,     -- secondes d'aller (ou impact) avant que le shuriken revienne
    dureeVie    = 4,       -- sécurité : retour forcé en main après ce délai
    rayon       = 200,     -- rayon de l'explosion à l'impact sur un ennemi
    degats      = 60,
}

if not SERVER then return end

local TAILLE = Vector(50, 12, 6)   -- demi-taille de la zone de collision du shuriken

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    return ent:IsNPC() or ent:IsNextBot()
end

local function Exploser(pos, owner, inflicteur, s)
    for _, ent in ipairs(ents.FindInSphere(pos, s.rayon)) do
        if not EstCible(ent, owner) then continue end

        local attenuation = 1 - math.Clamp(ent:GetPos():Distance(pos) / s.rayon, 0, 1)
        local dmg = DamageInfo()
        dmg:SetDamage(s.degats * attenuation)
        dmg:SetAttacker(owner)
        dmg:SetInflictor(inflicteur)
        dmg:SetDamageType(DMG_BLAST)
        dmg:SetDamagePosition(pos)
        ent:TakeDamageInfo(dmg)
    end
end

function SWEP:LancerSpecial(owner, s)
    timer.Simple(s.delaiSon, function()
        if IsValid(self) then self:EmitSound(s.son) end
    end)

    timer.Simple(s.delaiLancer, function()
        if not IsValid(self) or not IsValid(owner) or not owner:Alive() then return end

        local dir = owner:GetAimVector()
        local proj = ents.Create("prop_dynamic")
        if not IsValid(proj) then return end
        proj:SetModel(s.modele)
        proj:SetPos(owner:GetShootPos() + dir * 30)
        proj:SetAngles(dir:Angle())
        proj:SetOwner(owner)
        proj:Spawn()
        proj:SetSolid(SOLID_NONE)
        proj:SetMoveType(MOVETYPE_NONE)

        -- le shuriken n'est plus dans la main tant qu'il n'est pas revenu
        self:SetNW2Bool("NA_MainVide", true)

        local arme = self
        local now0 = CurTime()
        local finAller = now0 + s.dureeAller
        local fin = now0 + s.dureeVie
        local precedent = now0
        local retour = false
        local nom = "NA_ShurikenFuma_" .. proj:EntIndex()

        local function Terminer()
            if IsValid(arme) then arme:SetNW2Bool("NA_MainVide", false) end
            if IsValid(proj) then proj:Remove() end
            timer.Remove(nom)
        end

        timer.Create(nom, 0, 0, function()
            if not IsValid(proj) or not IsValid(owner) or not owner:Alive() or CurTime() > fin then
                Terminer()
                return
            end

            local now = CurTime()
            local dt = now - precedent
            precedent = now
            local depart = proj:GetPos()

            if retour then
                local cible = owner:GetPos() + Vector(0, 0, 50)
                local vers = cible - depart
                local pas = s.vitesse * dt
                if vers:Length() <= math.max(pas, 40) then
                    Terminer()
                    return
                end
                proj:SetAngles(vers:Angle())
                proj:SetPos(depart + vers:GetNormalized() * pas)
                return
            end

            local arrivee = depart + dir * s.vitesse * dt
            local dev = GetConVar("developer")
            if GetConVar("na_arme_debug"):GetBool() or (dev and dev:GetInt() > 0) then
                debugoverlay.Box(arrivee, -TAILLE, TAILLE, 0.5, Color(255, 0, 0, 40))
                debugoverlay.Sphere(arrivee, s.rayon, 0.1, Color(255, 128, 0, 10), true)
            end
            local tr = util.TraceHull({
                start  = depart,
                endpos = arrivee,
                mins   = -TAILLE,
                maxs   = TAILLE,
                filter = { owner, proj },
                mask   = MASK_SHOT_HULL,
            })

            if tr.Hit then
                if EstCible(tr.Entity, owner) then
                    Exploser(tr.HitPos, owner, IsValid(arme) and arme or proj, s)
                end
                retour = true
                return
            end

            proj:SetPos(arrivee)
            if now > finAller then retour = true end
        end)
    end)
end

-- pas de nouveau lancer tant que le shuriken n'est pas revenu en main
function SWEP:DeclencherSpecial()
    if self:GetNW2Bool("NA_MainVide", false) then return end
    self.BaseClass.DeclencherSpecial(self)
end
