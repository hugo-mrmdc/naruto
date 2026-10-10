--========================================================
-- Katana basique
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages de l'arme.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Katana basique"
SWEP.Author    = "katana"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true

SWEP.ViewModel  = "models/katana/basique/nr_weapon_katana5.mdl"
SWEP.WorldModel = "models/katana/basique/nr_weapon_katana5.mdl"

-- Modèle en main (réglé avec "na_arme_placer")
SWEP.MainDroite = {
    modele  = "models/katana/basique/nr_weapon_katana5.mdl",
    echelle = 0.98,
    pos     = Vector(3.13, 45.31, 1.56),
    rot     = Angle(-90, -2.81, -120.94),
}

-- Dans le dos quand il est rangé
SWEP.Dos = {
    modele  = "models/katana/basique/nr_weapon_katana5.mdl",
    echelle = 1,
    os      = "ValveBiped.Bip01_Spine",
    pos     = Vector(-14.84, -22.66, -29.69),
    ang     = Angle(-84.37, 0, 28.13),
    mode    = "accessoire",
}

-- Animations de déplacement (la course de chakra garde la sienne)
SWEP.Anims = {
    idle        = "phalanx_b_idle",
    marche      = "walk_all",       -- marche normale, sans pose d'arme
    course      = "run_all_01",     -- course normale, sans pose d'arme
    seuilMarche = 10,
    seuilCourse = 250,
}

-- Quand le coup touche et quand la particule de hit apparaît (par coup) :
--   delai        = secondes après le début de l'animation avant que le coup soit actif (= le moment du hit)
--   dureeFrappe  = secondes pendant lesquelles la zone de frappe reste active
--   delaiTouche  = secondes entre le hit (dégâts) et la particule "touche"
SWEP.Combo = {
    { anim = "m_sd_attack_2edgesword_cmb_01", vitesseAnim = 1.5, duree = 0.5, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    { anim = "m_sd_attack_2edgesword_cmb_03", vitesseAnim = 1.5, duree = 0.8, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
     
    { anim = "solve_kenjutsu_3mfncmb00 (3mfnbod1) retarget", vitesseAnim = 0.8, duree = 0.5, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    --{ anim = "solve_kenjutsu_3mfncmb01 (3mfnbod1) retarget", vitesseAnim = 1.2, duree = 0.5, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    --{ anim = "m_sd_attack_2edgesword_cmb_05", vitesseAnim = 1.5, duree = 0.8, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    --{ anim = "solve_kenjutsu_3mfncmb00 (3mfnbod1) retarget", vitesseAnim = 1.2, duree = 0.7, degats = 40, delai = 0.25, dureeFrappe = 0.4, delaiTouche = 0.2, touche = "izox_hit_type_one_basic" },
   -- { anim = "solve_kenjutsu_3mfncmr00 (3mfnbod1) retarget", vitesseAnim = 1.2, duree = 0.7, degats = 40, delai = 0.25, dureeFrappe = 0.4, delaiTouche = 0.2, touche = "izox_hit_type_one_basic" },
   -- { anim = "nrp_sword_turnslashing_left", vitesseAnim = 1.5, duree = 0.5, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    --{ anim = "nrp_sword_turnslashing_right", vitesseAnim = 1.5, duree = 0.5, degats = 30, delai = 0.15, dureeFrappe = 0.3, delaiTouche = 0.1, touche = "izox_hit_type_one_basic" },
    --{ anim = "m_sd_attack_sword_06_verticalslashing", vitesseAnim = 1, duree = 0.7, degats = 40, delai = 0.25, dureeFrappe = 0.4, delaiTouche = 0.2, touche = "izox_hit_type_one_basic" },
}
SWEP.ComboReset = 2.0

SWEP.Frappe = { portee = 80, largeur = 35, hauteur = 40, delai = 0, duree = 0.6 }
SWEP.SonSwing = Sound("fuma/swing1.wav")
