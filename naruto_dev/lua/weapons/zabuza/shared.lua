--========================================================
-- Kubikiribocho (épée de Zabuza)
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Kubikiribocho"
SWEP.Author    = "zabuza"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true
SWEP.Rarete    = "legendaire"

SWEP.ViewModel  = "models/weapon/kubikiribocho/kubikiribocho.mdl"
SWEP.WorldModel = "models/weapon/kubikiribocho/kubikiribocho.mdl"

-- Modèle en main
SWEP.MainDroite = {
    modele  = "models/weapon/kubikiribocho/kubikiribocho.mdl",
    echelle = 0.5,
    pos     = Vector(3, 2, -3),
    rot     = Angle(100, 160, 0),
}

-- Dans le dos quand elle est rangée
SWEP.Dos = {
    modele  = "models/weapon/kubikiribocho/kubikiribocho.mdl",
    echelle = 0.5,
    os      = { "ValveBiped.Bip01_UpperChest", "ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_Spine4", "ValveBiped.Bip01_Spine2" },
    pos     = Vector(10, 14, 10),
    ang     = Angle(160, 35, 10),
    mode    = "local",
}

-- Animations de déplacement (la course de chakra garde la sienne)
SWEP.Anims = {
    idle        = "ryoku_h_idle",
    marche      = "walk_all",       -- marche normale, sans pose d'arme
    course      = "run_all_01",     -- course normale, sans pose d'arme
    seuilMarche = 10,
    seuilCourse = 250,
}

SWEP.Combo = {
    { anim = "nrp_sword_slashhorizon",         vitesseAnim = 2.5, duree = 0.6, degats = 100, touche = "izox_hit_type_one_basic" },
    { anim = "nrp_sword_turnslashingshoulder", vitesseAnim = 2.5, duree = 0.6, degats = 100, touche = "izox_hit_type_one_basic" },
    { anim = "nrp_sword_slashing",             vitesseAnim = 2.0, duree = 1, degats = 120, touche = "izox_hit_type_one_basic" },
}
SWEP.ComboReset = 2.0
SWEP.SoinCoup   = 1   -- % des PV max rendus à chaque coup touché

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Clic droit : deux explosions devant soi
SWEP.Special = {
    nom        = "Kubikiribocho",
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
