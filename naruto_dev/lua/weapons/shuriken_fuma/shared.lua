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
    { anim = "ryoku_r_right_t1", duree = 0.5, degats = 40 },
    { anim = "ryoku_r_left_t2",  duree = 0.5, degats = 40 },
    { anim = "ryoku_r_right_t2", duree = 1.3, degats = 40 },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : lance un shuriken qui explose au contact d'un ennemi
SWEP.Special = {
    nom         = "Shuriken",
    anim        = "nrp_ninjutsu_defend_d35nj2_throw",
    recharge    = 1,
    duree       = 0.8,
    son         = "fuma/throw_1.wav",
    delaiSon    = 0.4,
    delaiLancer = 0.6,
    modele      = "models/fumaSpell/orga_props_shuriken.mdl",
    vitesse     = 2400,    -- unités / seconde
    dureeVie    = 3,       -- secondes avant de disparaître s'il ne touche rien
    rayon       = 200,     -- rayon de l'explosion à l'impact sur un ennemi
    degats      = 60,
}

if not SERVER then return end

local TAILLE = Vector(12, 12, 6)   -- demi-taille de la zone de collision du shuriken

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

        local arme = self
        local fin = CurTime() + s.dureeVie
        local precedent = CurTime()
        local nom = "NA_ShurikenFuma_" .. proj:EntIndex()

        timer.Create(nom, 0, 0, function()
            if not IsValid(proj) then timer.Remove(nom) return end

            local now = CurTime()
            local dt = now - precedent
            precedent = now
            if now > fin then
                proj:Remove()
                timer.Remove(nom)
                return
            end

            local depart = proj:GetPos()
            local arrivee = depart + dir * s.vitesse * dt
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
                proj:Remove()
                timer.Remove(nom)
                return
            end

            proj:SetPos(arrivee)
        end)
    end)
end
