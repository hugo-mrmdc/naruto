--========================================================
-- Shibuki
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

-- Particules : attaque spéciale (patlick_atgkaton.pcf) et explosion des 3 coups (boule_bakuton.pcf)
game.AddParticles("particles/patlick_atgkaton.pcf")
game.AddParticles("particles/boule_bakuton.pcf")
PrecacheParticleSystem("bombe_argilefinal_explo_base_pat")
PrecacheParticleSystem("super")

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
    { anim = "nrp_sword_slashhorizon",         vitesseAnim = 3.0, duree = 0.6, degats = 40 },
    { anim = "nrp_sword_turnslashingshoulder", vitesseAnim = 3, duree = 0.8, degats = 40 },
    { anim = "nrp_sword_slashing",             vitesseAnim = 1.0, duree = 1.3, degats = 40 },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")

-- Slash du clic gauche : angles X Y Z par coup (voir cl_slash_arme.lua)
--   x = roulis (0 horizontal, 90 vertical, ±45 diagonale), y = bascule (négatif = lève l'avant),
--   z = cap (tourne à gauche / droite). Autres réglages possibles : couleur, echelle, alpha...
SWEP.Slash = {
    angles = {
        { x = 15,   y = -25, z = 0 },   -- coup 1 : nrp_sword_slashhorizon
        { x = -45, y = -25, z = 0 },   -- coup 2 : nrp_sword_turnslashingshoulder
        { x = 100,  y = -40, z = 20 },   -- coup 3 : nrp_sword_slashing
    },
}

-- Explosion différée : quand tu touches le même ennemi 3 fois au clic gauche, il explose 1 seconde plus tard
SWEP.Explosif = {
    coups     = 3,      -- nombre de touches sur le même ennemi
    delai     = 1,      -- secondes avant l'explosion
    expire    = 4,      -- secondes sans le toucher avant que le compte reparte à 0
    rayon     = 130,
    degats    = 45,
    recul     = 250,
    reculHaut = 150,
    particule = "super",   -- explosion de boule_bakuton.pcf
    son       = "bakuton/solve_bakuton_explosion.wav",
    sonMarque = "weapons/grenade/tick1.wav",   -- petit tic quand l'ennemi est marqué (retire la ligne pour aucun son)
}

-- Clic droit : deux explosions devant soi
SWEP.Special = {
    nom        = "Shibuki",
    anim       = "customman_attack_shibuki_y retarget",
    vitesseAnim = 1,    -- vitesse de l'animation (1 = normale)
    recharge   = 5,
    duree      = 1.5,
    explosions = { { delai = 1, distance = 80 }, { delai = 1.5, distance = 140 } },
    rayon      = 150,
    degats     = 60,
    recul      = 300,
    reculHaut  = 200,
    particule  = "bombe_argilefinal_explo_base_pat",
    son        = "bakuton/solve_bakuton_explosion.wav",
}
