--========================================================
-- Shibuki
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Shibuki"
SWEP.Author    = "shibuki"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true

SWEP.ViewModel  = "models/weapon/shibuki/shibuki.mdl"
SWEP.WorldModel = "models/weapon/shibuki/shibuki.mdl"

-- Modèle en main
SWEP.MainDroite = {
    modele  = "models/weapon/shibuki/shibuki.mdl",
    echelle = 0.6,
    pos     = Vector(3, 1, -4),
    rot     = Angle(100, 170, -30),
}

-- Dans le dos quand elle est rangée
SWEP.Dos = {
    modele  = "models/weapon/shibuki/shibuki.mdl",
    echelle = 0.5,
    os      = { "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2" },
    pos     = Vector(-20, 5, 4),
    ang     = Angle(125, 0, 0),
    mode    = "accessoire",
}

-- Animations de déplacement (la course de chakra garde la sienne)
SWEP.Anims = {
    idle        = "nrp_base_bigsword_idle_loop",
    marche      = "walk_all",       -- marche normale, sans pose d'arme
    course      = "run_all_01",     -- course normale, sans pose d'arme
    seuilMarche = 10,
    seuilCourse = 250,
}

SWEP.Combo = {
    { anim = "nrp_sword_slashhorizon",         vitesseAnim = 2.0, duree = 1.0, degats = 40 },
    { anim = "nrp_sword_turnslashingshoulder", vitesseAnim = 1.5, duree = 0.8, degats = 40 },
    { anim = "nrp_sword_slashing",             vitesseAnim = 1.0, duree = 1.3, degats = 40 },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : deux explosions devant soi
SWEP.Special = {
    nom        = "Shibuki",
    anim       = "nrp_sword_swordturnkickupperslash",
    vitesseAnim = 1.0,    -- vitesse de l'animation (1 = normale)
    recharge   = 5,
    duree      = 1.5,
    explosions = { { delai = 0.3, distance = 80 }, { delai = 0.6, distance = 140 } },
    rayon      = 150,
    degats     = 60,
    recul      = 300,
    reculHaut  = 200,
    particule  = "[2]_concasse_blast",
    son        = "bakuton/solve_bakuton_explosion.wav",
}
