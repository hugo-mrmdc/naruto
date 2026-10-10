--========================================================
-- Kabutowari (hache + marteau)
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Kabutowari"
SWEP.Author    = "kabutowari"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true
SWEP.Rarete    = "legendaire"

SWEP.ViewModel  = "models/weapon/kabutowari/atg_kabutowari_hache.mdl"
SWEP.WorldModel = "models/weapon/kabutowari/atg_kabutowari_hache.mdl"

-- Modèles en main : hache à droite, marteau à gauche
SWEP.MainDroite = {
    modele  = "models/weapon/kabutowari/atg_kabutowari_hache.mdl",
    echelle = 0.8,
    pos     = Vector(3, 2, -15),
    rot     = Angle(-90, 0, 0),
}
SWEP.MainGauche = {
    modele  = "models/weapon/kabutowari/atg_kabutowari_marteau.mdl",
    echelle = 0.8,
    pos     = Vector(3, 1, -5),
    rot     = Angle(90, 0, 0),
}

-- Dans le dos quand elle est rangée
SWEP.Dos = {
    modele  = "models/weapon/kabutowari/atg_kabutowari_dos.mdl",
    echelle = 0.8,
    os      = { "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2" },
    pos     = Vector(-5, -7, -5),
    ang     = Angle(45, 0, 180),
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

SWEP.Combo = {
    { anim = "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl02_2",  vitesseAnim = 1.0, duree = 1.0, degats = 40, touche = "izox_hit_type_one_basic" },
    { anim = "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl03a_0", vitesseAnim = 1.0, duree = 1.1, degats = 40, touche = "izox_hit_type_one_basic" },
    { anim = "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw03u01", vitesseAnim = 1.0, duree = 1.3, degats = 40, touche = "izox_hit_type_one_basic" },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : deux explosions devant soi
SWEP.Special = {
    nom        = "Kabutowari",
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
