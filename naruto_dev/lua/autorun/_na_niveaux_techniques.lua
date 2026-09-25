--========================================================
-- Stats des techniques NIVEAU PAR NIVEAU (PARTAGÉ serveur + client)
--
-- C'est ICI qu'on règle ce que chaque niveau change sur une technique.
--
--   NA_NIV_TECH.<id de la technique> = {
--       [1] = { stat = valeur, ... },   -- niveau 1 : TOUTES les stats réglées
--       [2] = { stat = valeur },        -- niveaux suivants : seulement ce qui change
--       ...
--   }
--
-- Un niveau qui ne donne pas une stat garde la valeur du niveau d'avant.
-- Une stat réglée ici REMPLACE le pourcentage général (PAR_NIVEAU de _na_niveaux.lua).
-- Une technique absente de ce fichier garde le pourcentage général.
--
-- Côté serveur, la technique lit la stat avec :
--   NA_Stat(ply, "chinoike_vortex", "rayon", RAYON_COEUR)
-- (la valeur de base sert si la stat n'est pas réglée ici)
--
-- TOUS les réglages des techniques sont branchés : le niveau 1 de chaque
-- technique ci-dessous les liste tous avec leur valeur actuelle (tick =
-- "intervalle", durée, rayon, portée, vitesse, durée des mudras...).
-- Pour les changer à un niveau, recopie la ligne voulue dans [2]..[5].
--
-- Stats déjà branchées dans toutes les techniques : degats, chakra, recharge
-- (+ soin pour kaguya_danse, recharge_rate pour fuma_jugement, poison pour salamandre_poison).
--
-- "hitbox" = DEMI-taille de la zone qui touche (plus grand = plus facile à toucher).
-- Branchée dans les techniques qui ont une hitbox :
--   katon_boule (18), katon_saut (18), suiton_requin (18), mokuton_arche (40, visée),
--   fuma_tp (16, joueurs/PNJ seulement), fuma_jugement (18, le fil),
--   jinton_cube (20, visée), jinton_laser (45), salamandre_poison (6)
--   (entre parenthèses : valeur actuelle dans le fichier serveur)
-- Dans les fichiers serveur, chaque réglage passe par Niv(joueur, "stat", VALEUR) :
-- le nom de la stat = le nom du réglage en minuscules (INTERVALLE -> intervalle).
-- Un NOUVEAU réglage ajouté plus tard doit aussi passer par Niv pour être réglable ici.
-- Pourcentages : bonus_degats, bonus_vitesse, reduction, pourcent_vie (20 = 20 %).
--
-- Les stats réglées ici s'affichent dans la fiche de la bibliothèque (F6),
-- avec la valeur actuelle -> valeur au niveau suivant.
--========================================================

if SERVER then AddCSLuaFile() end

NA_NIV = NA_NIV or {}
NA_NIV_TECH = NA_NIV_TECH or {}

-- Nom affiché dans la bibliothèque et unité, dans l'ordre d'affichage.
-- Une stat absente de cette liste s'affiche avec son nom en majuscules.
NA_NIV.NOMS = {
    { "degats",     "DÉGÂTS",      "" },
    { "soin",       "SOIN",        "" },
    { "poison",     "POISON",      "" },
    { "chakra",     "CHAKRA",      "" },
    { "recharge",   "RECHARGE",    " S" },
    { "recharge_rate", "RECHARGE (RATÉ)", " S" },
    { "duree",      "DURÉE",       " S" },
    { "rayon",      "RAYON",       "" },
    { "hitbox",     "HITBOX",      "" },
    { "bonus_degats",  "BONUS DÉGÂTS",  " %" },
    { "bonus_vitesse", "BONUS VITESSE", " %" },
    { "vol_vie",       "VOL DE VIE",    " %" },
    { "portee",     "PORTÉE",      "" },
    { "force",      "FORCE",       "" },
    { "vitesse",    "VITESSE",     "" },
    { "nombre",     "NOMBRE",      "" },
    { "intervalle",       "TICK",                  " S" },
    { "duree_mudra",      "DURÉE DES MUDRAS",      " S" },
    { "delai_lancer",     "DÉLAI DE LANCER",       " S" },
    { "delai_cercle",     "DÉLAI DU CERCLE",       " S" },
    { "duree_vie",        "DURÉE DE VIE",          " S" },
    { "life",             "DURÉE DE VIE",          " S" },
    { "brulure_duree",    "DURÉE BRÛLURE",         " S" },
    { "brulure_dps",      "DÉGÂTS BRÛLURE / S",    "" },
    { "swarm_life",       "DURÉE DE VIE (NUÉE)",   " S" },
    { "etourdi",          "ÉTOURDISSEMENT",        " S" },
    { "stun_time",        "ÉTOURDISSEMENT",        " S" },
    { "poison_duree",     "DURÉE DU POISON",       " S" },
    { "poison_tick",      "TICK DU POISON",        " S" },
    { "drop_time",        "DURÉE DE CHUTE",        " S" },
    { "delay",            "DÉLAI ENTRE ARCHES",    " S" },
    { "pas",              "PAS D'ASPIRATION",      " S" },
    { "hauteur",          "HAUTEUR",               "" },
    { "height",           "HAUTEUR DE CHUTE",      "" },
    { "rayon_attire",     "RAYON D'ASPIRATION",    "" },
    { "rayon_attraction", "RAYON D'ASPIRATION",    "" },
    { "rayon_coeur",      "RAYON DU CŒUR",         "" },
    { "rayon_contact",    "RAYON DE CONTACT",      "" },
    { "rayon_explo",      "RAYON D'EXPLOSION",     "" },
    { "explo_rayon",      "RAYON D'EXPLOSION",     "" },
    { "explo_hauteur",    "HAUTEUR D'EXPLOSION",   "" },
    { "damage_radius",    "RAYON DES DÉGÂTS",      "" },
    { "swarm_radius",     "RAYON DE LA NUÉE",      "" },
    { "mid_radius",       "RAYON D'ARRIVÉE",       "" },
    { "portee_max",       "PORTÉE",                "" },
    { "portee_casse",     "DISTANCE DE RUPTURE",   "" },
    { "trace_range",      "PORTÉE",                "" },
    { "riposte_distance", "DISTANCE DE RIPOSTE",   "" },
    { "spawn_distance",   "DISTANCE D'APPARITION", "" },
    { "hitbox_mur",       "HITBOX (MURS)",         "" },
    { "angle_visee",      "ANGLE DE VISÉE",        "°" },
    { "force_attraction", "FORCE",                 "" },
    { "tourbillon",       "TOURBILLON",            "" },
    { "vitesse_pnj",      "VITESSE (PNJ)",         "" },
    { "vitesse_fil",      "VITESSE DU FIL",        "" },
    { "speed",            "VITESSE",               "" },
    { "main_speed",       "VITESSE",               "" },
    { "swarm_speed",      "VITESSE DE LA NUÉE",    "" },
    { "poussee",          "POUSSÉE",               "" },
    { "gravite",          "GRAVITÉ",               "" },
    { "ralenti",          "RALENTI (x VITESSE)",   "" },
    { "malus_vitesse",    "MALUS DE VITESSE",      "" },
    { "reduction",        "RÉDUCTION DÉGÂTS",      " %" },
    { "pourcent_vie",     "BOUCLIER (VIE MAX)",    " %" },
    { "chakra_mini",      "CHAKRA MINIMUM",        "" },
    { "count",            "NOMBRE",                "" },
    { "swarm_count",      "NOMBRE (NUÉE)",         "" },
    { "gap",              "ÉCART",                 "" },
    { "ecart",            "ÉCART",                 "" },
    { "echelle",          "TAILLE",                "" },
    { "largeur",          "LARGEUR",               "" },
    { "duree_stun",       "ÉTOURDISSEMENT",        " S" },
    { "immunite",         "IMMUNITÉ",              " S" },
    { "vagues",           "SALVES",                "" },
    { "cibles",           "CIBLES MAX",            "" },
    { "angle",            "ANGLE",                 "°" },
    { "boules",           "BOULES",                "" },
    { "delai",            "DÉLAI AVANT TIR",       " S" },
    { "montee",           "HAUTEUR DU BOND",       "" },
    { "fin_vol",          "FIN DU VOL",            " S" },
    { "anim_coupe",       "DURÉE DE L'ANIMATION",  " S" },
}

--========================================================
-- Règle suivie pour toutes les techniques :
--   niveau 1 = valeurs actuelles des fichiers serveur (rien ne change au déblocage)
--   niveaux 2 et 4 = plus de dégâts
--   niveau 3 = dégâts + petit bonus (recharge, hitbox, durée...)
--   niveau 5 = gros palier (dégâts, chakra moins cher, recharge plus courte)
--   => niveau 5 ~ +40 % de dégâts, -20 % de chakra, -20 % de recharge
--========================================================

--========================================================
-- KATON
--========================================================
-- Boule de feu (sv_bouledefeut.lua)
NA_NIV_TECH.katon_boule = {
    [1] = {
        degats = 35, recharge = 1, hitbox = 18,
        life = 2.5, speed = 1600,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 38 },
    [3] = { degats = 42, hitbox = 21, brulure_dps = 5 },
    [4] = { degats = 45 },
    [5] = { degats = 50, recharge = 0.8, hitbox = 24, brulure_duree = 5, brulure_dps = 6 },
}

-- Boule de feu sautée (sv_bouledefeuxJump.lua)
NA_NIV_TECH.katon_saut = {
    [1] = {
        degats = 35, recharge = 1, hitbox = 18,
        life = 2.5, speed = 1600,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 38 },
    [3] = { degats = 42, hitbox = 21, brulure_dps = 5 },
    [4] = { degats = 45 },
    [5] = { degats = 50, recharge = 0.8, hitbox = 24, brulure_duree = 5, brulure_dps = 6 },
}

-- Dôme de feu (sv_katon_dome.lua)
NA_NIV_TECH.katon_dome = {
    [1] = {
        degats = 6, chakra = 20, recharge = 10,
        duree = 5, rayon = 300, intervalle = 0.5, duree_mudra = 0.8,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 7 },
    [3] = { degats = 8, recharge = 9, brulure_dps = 5 },
    [4] = { degats = 9 },
    [5] = { degats = 10, chakra = 16, recharge = 8, brulure_duree = 5, brulure_dps = 6 },
}

--========================================================
-- SUITON
--========================================================
-- Requin d'eau (sv_suiton_shark.lua) : pas de dégâts branchés (fixés dans le fichier)
NA_NIV_TECH.suiton_requin = {
    [1] = {
        recharge = 5, hitbox = 18,
        swarm_count = 10, swarm_radius = 500, swarm_speed = 15, mid_radius = 40, swarm_life = 1,
        main_speed = 15,
    },
    [2] = { hitbox = 20 },
    [3] = { recharge = 4.5, hitbox = 22 },
    [4] = { hitbox = 24 },
    [5] = { recharge = 4, hitbox = 28 },
}

--========================================================
-- MOKUTON
--========================================================
-- Arche (mokuton_arche_sv.lua)
NA_NIV_TECH.mokuton_arche = {
    [1] = {
        degats = 20, recharge = 2, hitbox = 40,
        trace_range = 1000, damage_radius = 120, height = 800, drop_time = 0.6, stun_time = 4,
        count = 3, delay = 0.1, gap = 4,
    },
    [2] = { degats = 22 },
    [3] = { degats = 24, hitbox = 46 },
    [4] = { degats = 26 },
    [5] = { degats = 28, recharge = 1.6, hitbox = 52 },
}

-- Fleur (mokuton_fleur_sv.lua)
NA_NIV_TECH.mokuton_fleur = {
    [1] = {
        degats = 50, recharge = 1.5,
        damage_radius = 500, spawn_distance = 20,
    },
    [2] = { degats = 55 },
    [3] = { degats = 60, recharge = 1.3 },
    [4] = { degats = 65 },
    [5] = { degats = 70, recharge = 1.2 },
}

-- Dragon (mokuton_dragon_sv.lua) : aucune stat branchée par NA_Stat,
-- les niveaux ne changent rien tant que le fichier serveur ne les lit pas.

--========================================================
-- SALAMANDRE
--========================================================
-- Crachat de poison (sv_poison_projectile.lua)
--   degats = impact du crachat, poison = dégâts par tick du poison
NA_NIV_TECH.salamandre_poison = {
    [1] = {
        degats = 50, poison = 10, chakra = 10, recharge = 1, hitbox = 30,
        poison_duree = 5, poison_tick = 1, vitesse = 1500, duree_vie = 3, gravite = 0,
        duree_mudra = 1, delai_lancer = 0.5,
    },
    [2] = { degats = 55, poison = 11 },
    [3] = { degats = 60, poison = 12, hitbox = 30 },
    [4] = { degats = 65, poison = 13 },
    [5] = { degats = 70, poison = 14, chakra = 8, recharge = 0.8, hitbox = 30 },
}

-- Dôme de brume (sv_dome_salamandre.lua)
NA_NIV_TECH.salamandre_dome = {
    [1] = {
        degats = 5, chakra = 15, recharge = 6,
        duree = 5, rayon = 500, intervalle = 0.5, poison_duree = 3, duree_mudra = 0.8,
    },
    [2] = { degats = 5.5 },
    [3] = { degats = 6, recharge = 5.5 },
    [4] = { degats = 6.5 },
    [5] = { degats = 7, chakra = 12, recharge = 5 },
}

-- Corps de poison (sv_corps_poison.lua)
NA_NIV_TECH.salamandre_corps = {
    [1] = {
        degats = 4, chakra = 20, recharge = 15,
        poison_duree = 4, duree = 10, intervalle = 0.5, rayon_contact = 90, riposte_distance = 150,
        duree_mudra = 0.8,
    },
    [2] = { degats = 4.5 },
    [3] = { degats = 5, recharge = 13.5 },
    [4] = { degats = 5.5 },
    [5] = { degats = 6, chakra = 16, recharge = 12 },
}

-- Typhon de poison (sv_tornadopoison.lua)
NA_NIV_TECH.salamandre_tornade = {
    [1] = {
        degats = 8, chakra = 25, recharge = 12,
        portee_max = 900, duree = 6, rayon_attraction = 220, rayon_coeur = 220, force_attraction = 3000,
        tourbillon = 900, vitesse_pnj = 350, intervalle = 0.5, poison_duree = 3, duree_mudra = 1,
    },
    [2] = { degats = 9 },
    [3] = { degats = 10, recharge = 11 },
    [4] = { degats = 10.5 },
    [5] = { degats = 11, chakra = 20, recharge = 10 },
}

--========================================================
-- FUMA
--========================================================
-- Téléportation (sv_fumatp.lua) : pas de chakra
NA_NIV_TECH.fuma_tp = {
    [1] = {
        degats = 60, recharge = 2, hitbox = 16,
        rayon_explo = 200, duree_vie = 1.5, hitbox_mur = 6, vitesse = 2400,
        duree_mudra = 0.2, delai_lancer = 0.5,
    },
    [2] = { degats = 66 },
    [3] = { degats = 72, hitbox = 19 },
    [4] = { degats = 78 },
    [5] = { degats = 85, recharge = 1.6, hitbox = 22 },
}

-- Invisibilité (sv_fumainv.lua) : seule la recharge est branchée
NA_NIV_TECH.fuma_invisibilite = {
    [1] = {
        recharge = 8,
        duree = 10,
    },
    [2] = { recharge = 7.5 },
    [3] = { recharge = 7 },
    [4] = { recharge = 6.5 },
    [5] = { recharge = 6 },
}

-- Aura Fuma (sv_fumaaura.lua) : pas de dégâts branchés
NA_NIV_TECH.fuma_aura = {
    [1] = {
        chakra = 20, recharge = 25,
        duree = 12, duree_mudra = 0.4, bonus_degats = 30, reduction = 25,
    },
    [2] = { recharge = 24 },
    [3] = { chakra = 18, recharge = 23 },
    [4] = { recharge = 22 },
    [5] = { chakra = 16, recharge = 20 },
}

-- Jugement des Quatre Lames (sv_fumajugement.lua) : degats = CHAQUE shuriken (x4)
NA_NIV_TECH.fuma_jugement = {
    [1] = {
        degats = 20, chakra = 25, recharge = 18, recharge_rate = 6, hitbox = 18,
        etourdi = 2.5, delai_lancer = 0.3, portee = 1000, vitesse_fil = 3000,
    },
    [2] = { degats = 22 },
    [3] = { degats = 24, hitbox = 21 },
    [4] = { degats = 26 },
    [5] = { degats = 28, chakra = 20, recharge = 15, recharge_rate = 5, hitbox = 24 },
}

-- Shuriken Céleste (sv_fumaciel.lua)
NA_NIV_TECH.fuma_ciel = {
    [1] = {
        degats = 70, chakra = 35, recharge = 28,
        portee = 1000, duree_mudra = 0.6, vitesse = 2200, echelle = 6, rayon = 260,
        poussee = 450, hauteur = 2200,
    },
    [2] = { degats = 77 },
    [3] = { degats = 84, recharge = 26 },
    [4] = { degats = 91 },
    [5] = { degats = 100, chakra = 28, recharge = 23 },
}

--========================================================
-- KAMI
--========================================================
-- Shuriken de papier (sv_kami_shuriken.lua)
NA_NIV_TECH.kami_shuriken = {
    [1] = {
        degats = 35, chakra = 8, recharge = 1.5,
        nombre = 1, ecart = 6, vitesse = 2200, duree_vie = 3, echelle = 2.5,
        largeur = 1.1, hauteur = 1.5, delai_lancer = 0.25,
    },
    [2] = { degats = 38 },
    [3] = { degats = 42, recharge = 1.3 },
    [4] = { degats = 45 },
    [5] = { degats = 50, chakra = 6, recharge = 1.2 },
}

-- Ailes de papier (sv_kami_wings.lua) : chakra = PAR SECONDE de vol
NA_NIV_TECH.kami_ailes = {
    [1] = {
        chakra = 6, recharge = 3,
        chakra_mini = 15, duree_mudra = 0.8,
    },
    [2] = { chakra = 5.5 },
    [3] = { chakra = 5, recharge = 2.5 },
    [4] = { chakra = 4.5 },
    [5] = { chakra = 4, recharge = 2 },
}

-- Kami Circle (sv_kami_circle.lua)
-- ATTENTION : ces valeurs remplacent les convars kami_circle_damage et
-- kami_circle_cooldown (la console ne change plus les dégâts ni la recharge).
NA_NIV_TECH.kami_circle = {
    [1] = {
        degats = 20, recharge = 12,
        rayon = 220, duree = 6, intervalle = 0.5, duree_mudra = 1.1, delai_cercle = 0.5,
    },
    [2] = { degats = 22 },
    [3] = { degats = 24, recharge = 11 },
    [4] = { degats = 26 },
    [5] = { degats = 28, recharge = 10 },
}

-- Paper Shield (sv_kami_shield.lua) : pas de dégâts branchés
NA_NIV_TECH.kami_bouclier = {
    [1] = {
        chakra = 25, recharge = 15,
        duree = 15, duree_mudra = 0.6, reduction = 50,
    },
    [2] = { recharge = 14 },
    [3] = { chakra = 22, recharge = 13.5 },
    [4] = { recharge = 13 },
    [5] = { chakra = 20, recharge = 12 },
}

-- Roue de papier (sv_kami_roue.lua) : deux roues qui roulent au sol
NA_NIV_TECH.kami_roue = {
    [1] = {
        degats = 30, chakra = 30, recharge = 10,
        vitesse = 1500, duree_vie = 1, echelle = 0.3, ecart = 28, devant = 50,
        intervalle = 0.6, poussee = 350, soulevement = 200,
        duree_mudra = 0.0, delai_roues = 0.8,
    },
    [2] = { degats = 33 },
    [3] = { degats = 37, recharge = 9 },
    [4] = { degats = 41 },
    [5] = { degats = 45, chakra = 25, recharge = 8 },
}

--========================================================
-- JINTON
--========================================================
-- Cube de confinement (sv_jinton_cube.lua)
NA_NIV_TECH.jinton_cube = {
    [1] = {
        degats = 40, chakra = 30, recharge = 1, hitbox = 20,
        portee = 900, duree_mudra = 0.6, duree = 1.5, intervalle = 0.7, echelle = 1.1,
    },
    [2] = { degats = 40,duree = 1.7 },
    [3] = { degats = 40, hitbox = 24,duree = 2 },
    [4] = { degats = 40 ,duree = 2.5},
    [5] = { degats = 40, chakra = 24, hitbox = 28,duree = 3 },
}

-- Bouclier Jinton (sv_jinton_bouclier.lua) : degats = explosion du bouclier
NA_NIV_TECH.jinton_bouclier = {
    [1] = {
        degats = 70, chakra = 25, recharge = 20,
        explo_hauteur = 140, explo_rayon = 200, pourcent_vie = 20, echelle = 1.35, duree = 10,
        duree_mudra = 0.5,
    },
    [2] = { degats = 80 },
    [3] = { degats = 90, recharge = 18.5 },
    [4] = { degats = 100 },
    [5] = { degats = 120, chakra = 20, recharge = 16 },
}

-- Rayon de dissolution (sv_jinton_laser.lua)
NA_NIV_TECH.jinton_laser = {
    [1] = {
        degats = 20, chakra = 40, recharge = 30, hitbox = 45,
        intervalle = 0.25, duree = 15, duree_mudra = 0.6,
    },
    [2] = { degats = 22 },
    [3] = { degats = 24, recharge = 28, hitbox = 50 },
    [4] = { degats = 26 },
    [5] = { degats = 28, chakra = 32, recharge = 24, hitbox = 55 },
}

--========================================================
-- KAGUYA
--========================================================
-- Armure d'os (sv_kaguya_armure.lua) : à activer / désactiver
--   chakra = PAR SECONDE, reduction = % de dégâts subis en moins,
--   recharge = secondes avant de pouvoir la réactiver (après l'arrêt)
NA_NIV_TECH.kaguya_armure = {
    [1] = {
        chakra = 4, recharge = 10, chakra_mini = 20,
        malus_vitesse = 0, duree_mudra = 0.5, reduction = 40,
    },
    [2] = { reduction = 42 },
    [3] = { chakra = 3.5, recharge = 9, reduction = 45 },
    [4] = { reduction = 48 },
    [5] = { chakra = 3, recharge = 8, reduction = 50 },
}

-- Danse des os (sv_kaguya_danse.lua) : soin = vie rendue au lanceur par tick
NA_NIV_TECH.kaguya_danse = {
    [1] = {
        degats = 12, soin = 8, chakra = 30, recharge = 20,
        portee = 900, angle_visee = 12, duree = 6, intervalle = 0.5, portee_casse = 1100,
        duree_mudra = 0.4,
    },
    [2] = { degats = 13, soin = 9 },
    [3] = { degats = 14, soin = 10, recharge = 18.5 },
    [4] = { degats = 15, soin = 10.5 },
    [5] = { degats = 17, soin = 11, chakra = 24, recharge = 16 },
}

-- Légion d'os (sv_kaguya_legion.lua)
NA_NIV_TECH.kaguya_legion = {
    [1] = {
        degats = 12, chakra = 30, recharge = 25,
        hauteur = 90, rayon = 180, intervalle = 0.5, duree = 8, duree_mudra = 0.5,
    },
    [2] = { degats = 13 },
    [3] = { degats = 14, recharge = 23 },
    [4] = { degats = 15 },
    [5] = { degats = 17, chakra = 24, recharge = 20 },
}

--========================================================
-- CHINOIKE
--========================================================
-- Ketsuryugan (sv_chinoike_ketsuryugan.lua) : à activer / désactiver
--   chakra = PAR SECONDE, bonus_degats / bonus_vitesse = en %
NA_NIV_TECH.chinoike_ketsuryugan = {
    [1] = {
        chakra = 1, recharge = 20, bonus_degats = 20, bonus_vitesse = 5,
        chakra_mini = 20, duree_mudra = 0.4,
        vol_vie = 20,                           -- % des dégâts infligés rendus en vie
    },
    [2] = { chakra = 2,bonus_degats = 23 },
    [3] = { chakra = 3, bonus_degats = 26, bonus_vitesse = 5, vol_vie = 3 },
    [4] = { chakra = 4,bonus_degats = 30 },
    [5] = { chakra = 5, recharge = 20, bonus_degats = 35, bonus_vitesse = 5, vol_vie = 6 },
}

-- Genjutsu du Ketsuryugan (sv_chinoike_genjutsu.lua)
--   duree = paralysie + dégâts, portee = distance max de la cible
NA_NIV_TECH.chinoike_genjutsu = {
    [1] = {
        degats = 6, chakra = 30, recharge = 25, duree = 3, portee = 800, hitbox = 20,
        intervalle = 0.5, duree_mudra = 0.5,
    },
    [2] = { degats = 7 },
    [3] = { degats = 8, duree = 3.5, hitbox = 24 },
    [4] = { degats = 9, recharge = 22 },
    [5] = { degats = 10, chakra = 24, recharge = 20, duree = 4, portee = 1000 },
}

-- Pluie de sang (sv_chinoike_pluie.lua)
NA_NIV_TECH.chinoike_pluie = {
    [1] = {
        degats = 30, chakra = 35, recharge = 22,
        portee = 800, hauteur = 300, rayon = 300, ralenti = 0.75, intervalle = 0.5,
        duree = 8, duree_mudra = 0.5,
    },
    [2] = { degats = 33 },
    [3] = { degats = 36, recharge = 20 },
    [4] = { degats = 39 },
    [5] = { degats = 42, chakra = 28, recharge = 18 },
}

-- Vortex de sang (sv_chinoike_vortex.lua)
NA_NIV_TECH.chinoike_vortex = {
    [1] = {
        degats = 10, chakra = 30, recharge = 20, duree = 3.5, rayon = 200, force = 3000,
        portee = 900, rayon_attire = 450, tourbillon = 900, pas = 0.05, vitesse_pnj = 350,
        intervalle = 0.5, duree_mudra = 0.5,
    },
    [2] = { degats = 12 },
    [3] = { degats = 14, duree = 4,   rayon = 230 },
    [4] = { degats = 16, recharge = 18 },
    [5] = { degats = 20, duree = 5,   rayon = 260, force = 3600 },
}

--========================================================
-- KIMINARI
--========================================================
-- Frappe noire (sv_kiminari_frappe.lua) : duree = étourdissement
NA_NIV_TECH.kiminari_frappe = {
    [1] = {
        degats = 15, chakra = 25, recharge = 18, duree = 2, rayon = 250, portee = 500, duree_mudra = 0, anim_coupe = 0.4,
    },
    [2] = { degats = 17 },
    [3] = { degats = 19, duree = 2.3, recharge = 16.5 },
    [4] = { degats = 21, rayon = 280 },
    [5] = { degats = 24, duree = 2.7, chakra = 20, recharge = 15 },
}

-- Prison noire (sv_kiminari_prison.lua) : étourdit qui entre OU sort de la zone
NA_NIV_TECH.kiminari_prison = {
    [1] = {
        degats = 12, chakra = 35, recharge = 24, duree = 8, rayon = 250, hauteur = 250,
        duree_stun = 1.5, immunite = 1, intervalle = 0.1, duree_mudra = 0.5,
    },
    [2] = { degats = 14 },
    [3] = { degats = 16, duree_stun = 1.8, recharge = 22 },
    [4] = { degats = 18, rayon = 280, duree = 9 },
    [5] = { degats = 21, duree_stun = 2.2, chakra = 30, recharge = 20 },
}

-- Laser Circus (sv_kiminari_laser.lua) : degats = par laser
NA_NIV_TECH.kiminari_laser = {
    [1] = {
        degats = 14, chakra = 40, recharge = 5, vagues = 3, intervalle = 0.35,
        portee = 1200, duree_mudra = 0.5,
    },
    [2] = { degats = 16 },
    [3] = { degats = 18, vagues = 4, recharge = 5 },
    [4] = { degats = 20, portee = 1400 },
    [5] = { degats = 40, vagues = 5, chakra = 35, recharge = 5 },
}

-- Boulets noirs (sv_kiminari_boulets.lua) : degats = par boule
NA_NIV_TECH.kiminari_boulets = {
    [1] = {
        degats = 8, chakra = 30, recharge = 22, boules = 10, delai = 0.6, intervalle = 0.25, vitesse = 2200,
        rayon = 90, portee = 1500, montee = 1000, fin_vol = 0.5, duree_mudra = 0.3, anim_coupe = 0.4,
    },
    [2] = { degats = 9 },
    [3] = { degats = 10, boules = 12, recharge = 20 },
    [4] = { degats = 11, rayon = 110 },
    [5] = { degats = 13, boules = 3, chakra = 25, recharge = 18 },
}

--========================================================
-- JITON
--========================================================
-- Sarcophage de sable (sv_jiton_sarcophage.lua) : degats = une seule fois, duree = étourdissement
NA_NIV_TECH.jiton_sarcophage = {
    [1] = {
        degats = 20, chakra = 30, recharge = 20, duree = 3, portee = 800, hitbox = 20, duree_mudra = 0.5,
    },
    [2] = { degats = 23 },
    [3] = { degats = 26, duree = 3.3, recharge = 18 },
    [4] = { degats = 29, portee = 900 },
    [5] = { degats = 33, duree = 3.8, chakra = 25, recharge = 16 },
}

-- Émergence de sable (sv_jiton_emergence.lua) : degats = par tick et par ennemi,
-- ralenti = vitesse des ennemis dans la zone (0.6 = 60 % de leur vitesse)
NA_NIV_TECH.jiton_emergence = {
    [1] = {
        degats = 8, chakra = 30, recharge = 18, duree = 6, intervalle = 0.5,
        rayon = 200, hauteur = 150, ralenti = 0.6, duree_mudra = 0.5,
    },
    [2] = { degats = 9 },
    [3] = { degats = 10, duree = 7, recharge = 16 },
    [4] = { degats = 11, rayon = 230, ralenti = 0.55 },
    [5] = { degats = 13, duree = 8, chakra = 25, recharge = 14, ralenti = 0.5 },
}

-- Tornade de sable (sv_jiton_tornade.lua / entities/jiton_tornade.lua) : degats = une fois par ennemi,
-- distance parcourue = vitesse x duree
NA_NIV_TECH.jiton_tornade = {
    [1] = {
        degats = 25, chakra = 40, recharge = 24, vitesse = 600, duree = 2.5, rayon = 110,
        hauteur = 220, projection = 350, duree_mudra = 0.5,
    },
    [2] = { degats = 28 },
    [3] = { degats = 32, duree = 3, recharge = 22 },
    [4] = { degats = 36, rayon = 130 },
    [5] = { degats = 42, vitesse = 700, duree = 3, chakra = 35, recharge = 18 },
}

-- Nuage de sable (sv_jiton_nuage.lua) : duree = secondes de vol
NA_NIV_TECH.jiton_nuage = {
    [1] = { chakra = 35, recharge = 45, duree = 20, duree_mudra = 0.5 },
    [2] = { duree = 22 },
    [3] = { duree = 25, recharge = 40 },
    [4] = { duree = 28, chakra = 30 },
    [5] = { duree = 32, recharge = 35 },
}

-- Vortex de sable (sv_jiton_vortex.lua) : même aspiration que le Vortex de sang
NA_NIV_TECH.jiton_vortex = {
    [1] = {
        degats = 10, chakra = 30, recharge = 20, duree = 3.5, rayon = 200, force = 3000,
        portee = 900, rayon_attire = 450, tourbillon = 900, pas = 0.05, vitesse_pnj = 350,
        intervalle = 0.5, duree_mudra = 0.5,
    },
    [2] = { degats = 12 },
    [3] = { degats = 14, duree = 4,   rayon = 230 },
    [4] = { degats = 16, recharge = 18 },
    [5] = { degats = 20, duree = 5,   rayon = 260, force = 3600 },
}
