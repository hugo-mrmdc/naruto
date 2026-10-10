--========================================================
-- Hiramekarei (deux lames)
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Hiramekarei"
SWEP.Author    = "hiramekarei"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true
SWEP.Rarete    = "legendaire"

SWEP.ViewModel  = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"
SWEP.WorldModel = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"

-- Modèles en main
SWEP.MainDroite = {
    modele  = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl",
    echelle = 0.8,
    pos     = Vector(4, 0, 0),
    rot     = Angle(-90, 0, 0),
}
SWEP.MainGauche = {
    modele  = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl",
    echelle = 0.8,
    pos     = Vector(4, 0, 0),
    rot     = Angle(90, 0, 0),
}

-- Dans le dos quand elle est rangée
SWEP.Dos = {
    modele  = "models/weapon/hiramekarei/atg_hiramekarei_dos.mdl",
    echelle = 0.8,
    os      = { "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2" },
    pos     = Vector(-15, -7, 0),
    ang     = Angle(-135, 0, 180),
    mode    = "accessoire",
}

-- Animations de déplacement (la course de chakra garde la sienne)
SWEP.Anims = {
    idle        = "idle_all_angry",
    marche      = "walk_all",       -- marche normale, sans pose d'arme
    course      = "run_all_01",     -- course normale, sans pose d'arme
    seuilMarche = 10,
    seuilCourse = 250,
}

-- Combo : le 1er coup touche 4 fois
SWEP.Combo = {
    { anim = "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw03",   vitesseAnim = 1.0, duree = 1.0, degats = 100, coups = 4, intervalle = 0.15, sons = 4, touche = "izox_hit_type_one_basic" },
    { anim = "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw04",   vitesseAnim = 1.0, duree = 0.7, degats = 100, touche = "izox_hit_type_one_basic" },
    { anim = "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl02_2", vitesseAnim = 1.0, duree = 1.0, degats = 100, touche = "izox_hit_type_one_basic" },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 40, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : deux explosions devant soi
SWEP.Special = {
    nom        = "Hiramekarei",
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
