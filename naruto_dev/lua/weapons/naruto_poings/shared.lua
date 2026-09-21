--========================================================
-- Poings (combat à mains nues)
-- Toute la logique est dans lua/weapons/naruto_arme_base.lua :
-- ce fichier ne contient que les réglages.
--========================================================
AddCSLuaFile()

SWEP.Base      = "naruto_arme_base"
SWEP.PrintName = "Poings"
SWEP.Author    = "naruto"
SWEP.Category  = "Naruto"
SWEP.Spawnable = true
SWEP.Slot      = 0

-- Aucun modèle : ce sont les mains du personnage
SWEP.ViewModel  = ""
SWEP.WorldModel = ""
SWEP.UseHands   = false
SWEP.HoldType   = "normal"   -- mains vides : marche et course normales

-- Pas de modèle dans le dos
SWEP.Dos = nil

-- Marche et course imposées : celles "sans arme" de Garry's Mod, pour ne jamais
-- avoir la pose "objet en main" (notamment en ralentissant après une course).
SWEP.Anims = {
    idle        = "nrp2_idle02",
    marche      = "walk_all",
    course      = "run_all_01",
    seuilMarche = 10,     -- en dessous : idle
    seuilCourse = 250,    -- au-dessus : course (marche = 200, course = 340)
    idleDesArret = true,  -- idle dès qu'on relâche les touches, sans attendre l'arrêt complet
}

-- Vitesse des animations de coups : 1 = normale, 1.5 = 50 % plus rapide.
-- Chaque coup du combo a aussi sa propre vitesse ("vitesseAnim"), qui passe avant celle-ci.
-- Si tu la changes, adapte les "duree" (temps avant le coup suivant) dans le même rapport.
SWEP.VitesseAnim = 1.5

-- Combo : trois coups de poing, le dernier repousse la cible
SWEP.Combo = {
    { anim = "nrp2_attacks_punch1", vitesseAnim = 1.5, duree = 0.4, degats = 15 },
    { anim = "nrp2_attacks_punch2", vitesseAnim = 1.5, duree = 0.4, degats = 18 },
    { anim = "nrp2_attacks_punch3", vitesseAnim = 1.5, duree = 0.6, degats = 25, recul = 350, reculHaut = 100 },
}
SWEP.ComboReset = 1.5   -- secondes sans frapper avant de revenir au coup de poing

-- Zone de frappe : plus courte et plus étroite qu'une épée
SWEP.Frappe = { portee = 55, largeur = 25, hauteur = 35, delai = 0.07, duree = 0.25 }

SWEP.SonSwing   = Sound("npc/zombie/claw_miss1.wav")
SWEP.SonImpact  = Sound("Flesh.ImpactHard")
SWEP.TypeDegats = DMG_CLUB

SWEP.Special = nil   -- pas d'attaque au clic droit

function SWEP:ShouldDropOnDie()
    return false
end
