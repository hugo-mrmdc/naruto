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
    { "tomoe",      "TOMOE",       "" },
    { "degats",     "DÉGÂTS",      "" },
    { "degats_final", "DÉGÂTS FINAUX", "" },
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

-- Boule de feu sautée (sv_uchiha_boule_saut.lua)
NA_NIV_TECH.katon_saut = {
    [1] = {
        degats = 35, recharge = 1, hitbox = 45,
        life = 2.5, speed = 1600,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 38 },
    [3] = { degats = 42, hitbox = 50, brulure_dps = 5 },
    [4] = { degats = 45 },
    [5] = { degats = 50, recharge = 0.8, hitbox = 55, brulure_duree = 5, brulure_dps = 6 },
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

-- Souffle katon (sv_katon_souffle.lua)
NA_NIV_TECH.katon_souffle = {
    [1] = {
        degats = 5, chakra = 25, recharge = 8,
        duree = 3, portee = 450, intervalle = 0.25, duree_mudra = 0.8,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 5.5 },
    [3] = { degats = 6, recharge = 7, portee = 500, brulure_dps = 5 },
    [4] = { degats = 6.5 },
    [5] = { degats = 7, chakra = 20, recharge = 6, duree = 3.5, brulure_duree = 5, brulure_dps = 6 },
}

-- Tornade de feu (sv_katon_tornade.lua)
NA_NIV_TECH.katon_tornade = {
    [1] = {
        degats = 10, chakra = 30, recharge = 12,
        duree = 5, rayon = 350, intervalle = 0.5, attraction = 600, duree_mudra = 0.8,
        brulure_duree = 4, brulure_dps = 4,
    },
    [2] = { degats = 13 },
    [3] = { degats = 15, recharge = 11, rayon = 400, brulure_dps = 5 },
    [4] = { degats = 18, attraction = 700 },
    [5] = { degats = 24, chakra = 25, recharge = 10, duree = 6, brulure_duree = 5, brulure_dps = 6 },
}

-- Nuée ardente (sv_katon_nuee.lua) : une nuée de feu éclate au sol là où le lanceur regarde ; un seul coup de dégâts à l'éclatement, puis brûlure
--   duree = secondes de la nuée (la particule dure 0.75 s), reprise = secondes entre deux jaillissements de la particule, rayon = zone, degats = coup unique, portee = distance de visée
NA_NIV_TECH.katon_nuee = {
    [1] = { degats = 280, duree = 1, reprise = 1, rayon = 380, portee = 700, brulure_duree = 4, brulure_dps = 5, chakra = 70, recharge = 22, duree_mudra = 0.8 },
    [2] = { degats = 300 },
    [3] = { degats = 330, chakra = 62, brulure_dps = 6 },
    [4] = { degats = 350, recharge = 19 },
    [5] = { degats = 380, chakra = 55, recharge = 16, brulure_duree = 5, brulure_dps = 7 },
}

-- Météore (server/katon/sv_katon_meteore.lua) : un météore tombe du ciel sur le point visé ; explosion au sol, dégâts (les mêmes partout dans le rayon) puis brûlure
--   degats = de l'explosion, rayon = zone, echelle = taille du météore (1 = ~418 de large), hauteur = hauteur de départ, gravite = accélération de chute, portee = distance max du point visé, brulure_duree / brulure_dps
NA_NIV_TECH.katon_meteore = {
    [1] = { degats = 400, rayon = 600, echelle = 2, hauteur = 2500, gravite = 500, portee = 1500, brulure_duree = 4, brulure_dps = 6, chakra = 90, recharge = 45, duree_mudra = 1 },
    [2] = { degats = 440 },
    [3] = { degats = 490, chakra = 82, rayon = 650 },
    [4] = { degats = 540, recharge = 39 },
    [5] = { degats = 600, chakra = 74, rayon = 700, recharge = 1, brulure_duree = 5, brulure_dps = 8 },
}

-- Grosse boule de feu (sv_katon_grosse_boule.lua)
NA_NIV_TECH.katon_grosse_boule = {
    [1] = {
        degats = 100, chakra = 35, recharge = 10, duree_mudra = 1,
        vitesse = 900, vie = 3, hitbox = 40, rayon = 220,
        brulure_duree = 4, brulure_dps = 5,
    },
    [2] = { degats = 120 },
    [3] = { degats = 130, recharge = 9, rayon = 250, brulure_dps = 6 },
    [4] = { degats = 150 },
    [5] = { degats = 180, chakra = 30, recharge = 8, rayon = 280, brulure_duree = 5, brulure_dps = 7 },
}

--========================================================
-- SUITON
--========================================================
-- Requin d'eau (sv_suiton_shark.lua) : degats = dégâts du requin principal quand il touche (la nuée fait 1 par requin en plus), stun = secondes d'étourdissement en l'air, recul / souleve = bump (vitesse horizontale / verticale, comme le Wind Ball)
NA_NIV_TECH.suiton_requin = {
    [1] = {
        recharge = 5, hitbox = 18, degats = 150, stun = 1, recul = 10, souleve = 120,
        swarm_count = 10, swarm_radius = 250, swarm_speed = 15, mid_radius = 40, swarm_life = 1,
        main_speed = 15, detect = 450,   -- detect = distance à laquelle le requin repère une cible et se met à la suivre
    },
    [2] = { hitbox = 20, degats = 160 },
    [3] = { recharge = 4.5, hitbox = 22, degats = 165, detect = 550 },
    [4] = { hitbox = 24, degats = 36 },
    [5] = { recharge = 4, hitbox = 28, degats = 172, detect = 650 },
}

-- Tsunami (sv_suiton_tsunami.lua) : une vague emporte le lanceur en continu dans la direction de son regard ; dégâts aux ennemis touchés par son front
--   duree = secondes sur la vague, vitesse = vitesse de la vague, degats = par touche, intervalle = secondes avant de retoucher le même ennemi, rayon = zone touchée devant le lanceur
NA_NIV_TECH.suiton_tsunami = {
    [1] = { degats = 70, duree = 6, vitesse = 650, intervalle = 1 ,rayon = 400, chakra = 60, recharge = 20, duree_mudra = 0.8 },
    [2] = { degats = 80 },
    [3] = { degats = 100, duree = 7, chakra = 54 },
    [4] = { degats = 120, rayon = 450, recharge = 17 },
    [5] = { degats = 150, duree = 8, vitesse = 750, chakra = 48, recharge = 1 },
}

-- Océan (server/suiton/sv_suiton_ocean.lua) : une zone d'océan posée au sol devant le lanceur ; elle attire légèrement et blesse tous les ennemis dedans
--   degats = par tick, intervalle = secondes entre deux ticks, duree = secondes, rayon = zone (le modèle lv_zone_eau suit), attraction = vitesse d'aspiration (légère), distance = distance max devant le lanceur
NA_NIV_TECH.suiton_ocean = {
    [1] = { degats = 20, duree = 8, rayon = 450, intervalle = 0.5, attraction = 120, distance = 500, chakra = 80, recharge = 40, duree_mudra = 0.8 },
    [2] = { degats = 25 },
    [3] = { degats = 30, chakra = 72, rayon = 500 },
    [4] = { degats = 35, recharge = 34, attraction = 140 },
    [5] = { degats = 40, chakra = 64, recharge = 28, duree = 10, rayon = 550 },
}

-- Pluie suiton (sv_suiton_pluie.lua) : un nuage fait pleuvoir des bulles d'eau sur la zone visée ; chaque bulle qui touche le sol explose et blesse
--   duree = secondes de pluie, rayon = zone, par_vague / intervalle = bulles par vague et secondes entre deux vagues, degats = par bulle,
--   rayon_bulle = zone touchée sous une bulle, hauteur = hauteur de chute, hauteur_nuage = hauteur du nuage, vitesse = vitesse de chute, portee = distance de visée
NA_NIV_TECH.suiton_pluie = {
    [1] = { degats = 30, rayon = 250, duree = 4, par_vague = 3, intervalle = 0.2, rayon_bulle = 110, hauteur = 400, hauteur_nuage = 650, vitesse = 300, portee = 700, chakra = 40, recharge = 14, duree_mudra = 0.5 },
    [2] = { degats = 30 },
    [3] = { degats = 33, rayon = 280, rayon_bulle = 125, chakra = 36 },
    [4] = { degats = 35, duree = 4.5, recharge = 12 },
    [5] = { degats = 40, rayon = 320, rayon_bulle = 140, par_vague = 4, duree = 5, chakra = 32, recharge = 10 },
}

-- Boule d'eau (sv_suiton_waterball.lua)
NA_NIV_TECH.suiton_waterball = {
    [1] = {
        degats = 60, chakra = 20, recharge = 6,
        vitesse = 1400, duree_vie = 2, hitbox = 26, echelle = 0.5, recul = 350, duree_mudra = 0.6,
    },
    [2] = { degats = 70 },
    [3] = { degats = 80, recharge = 5.5, hitbox = 25 },
    [4] = { degats = 90 },
    [5] = { degats = 100, chakra = 16, recharge = 4.5, hitbox = 28 },
}

-- Prison aqueuse (sv_suiton_prison.lua)
NA_NIV_TECH.suiton_prison = {
    [1] = {
        degats = 4, chakra = 30, recharge = 12,
        duree = 5, portee = 800, hitbox = 20, duree_mudra = 0.6, hauteur = 100, intervalle = 0.5,   -- duree = durée MAXIMALE (clic droit maintenu)
    },
    [2] = { degats = 4.5, duree = 5.5 },
    [3] = { degats = 5, recharge = 11, portee = 900 },
    [4] = { degats = 5.5, duree = 6 },
    [5] = { degats = 6, chakra = 25, recharge = 9, duree = 7 },
}

-- Bulles (sv_suiton_bulle.lua)
NA_NIV_TECH.suiton_bulle = {
    [1] = {
        degats = 5, chakra = 25, recharge = 8,
        nombre = 10, duree_salve = 0.7, vitesse = 800, duree_vie = 3, hitbox = 26, duree_mudra = 0.6,
    },
    [2] = { degats = 6, nombre = 10 },
    [3] = { degats = 8, recharge = 7, hitbox = 28 },
    [4] = { degats = 10, nombre = 11 },
    [5] = { degats = 12, chakra = 20, recharge = 6, nombre = 13 },
}

--========================================================
-- FUTON
--========================================================
-- Wind Slash (sv_futon_windslash.lua)
NA_NIV_TECH.futon_windslash = {
    [1] = {
        degats = 60, chakra = 20, recharge = 5,
        vitesse = 1800, duree_vie = 1.5, hitbox = 40, hitbox_haut = 15, echelle = 0.6, roulis = 0, duree_mudra = 0.5,
    },
    [2] = { degats = 64 },
    [3] = { degats = 73, recharge = 4.5, hitbox = 45 },
    [4] = { degats = 79 },
    [5] = { degats = 103, chakra = 16, recharge = 4, hitbox = 50 },
}

-- Tornade de vent (sv_futon_tornade.lua)
NA_NIV_TECH.futon_tornade = {
    [1] = {
        degats = 66, chakra = 30, recharge = 12,
        duree = 2, vitesse = 1200, rayon = 130, hauteur = 250, intervalle = 0.25, recul = 300, souleve = 220, duree_mudra = 0.8,
    },
    [2] = { degats = 74 },
    [3] = { degats = 86, recharge = 11, duree = 2 },
    [4] = { degats = 98 },
    [5] = { degats = 112, chakra = 24, recharge = 9, duree = 2 },
}

-- Ouragan de vent (sv_futon_ouragan.lua) : une grosse tornade qui avance ; dégâts + bump à chaque ennemi traversé (une fois chacun)
--   degats = dégâts, rayon, vitesse, duree_vie = secondes (portée = vitesse x durée), pousse = bump horizontal, souleve = bump vertical, devant = distance de départ
NA_NIV_TECH.futon_ouragan = {
    [1] = { degats = 124, rayon = 110, vitesse = 500, duree_vie = 3, pousse = 10, souleve = 120, devant = 70, chakra = 40, recharge = 12, duree_mudra = 0.4 },
    [2] = { degats = 136 },
    [3] = { degats = 142, chakra = 36, rayon = 120 },
    [4] = { degats = 153, recharge = 10, duree_vie = 3.5 },
    [5] = { degats = 166, chakra = 32, recharge = 8, rayon = 135, duree_vie = 4 },
}

-- Expulsion de vent (sv_futon_expulsion.lua) : explosion autour du lanceur, dégâts + projection des ennemis proches
--   degats, rayon = zone autour du lanceur, pousse = vitesse horizontale donnée aux ennemis, souleve = vitesse verticale
NA_NIV_TECH.futon_expulsion = {
    [1] = { degats = 110, rayon = 350, pousse = 1100, souleve = 300, chakra = 40, recharge = 14, duree_mudra = 0.5 },
    [2] = { degats = 123 },
    [3] = { degats = 135, rayon = 400, chakra = 36 },
    [4] = { degats = 150, recharge = 12 },
    [5] = { degats = 173, rayon = 450, pousse = 1300, chakra = 32, recharge = 10 },
}

-- Grand ouragan (sv_futon_grand_ouragan.lua) : un ouragan posé au sol devant le lanceur ; il attire et blesse tout le monde dedans
--   degats = par tick, intervalle = secondes entre deux ticks, duree = secondes, rayon = zone, attraction = vitesse d'aspiration, distance = distance max devant le lanceur
NA_NIV_TECH.futon_grand_ouragan = {
    [1] = { degats = 10, duree = 5, rayon = 380, intervalle = 0.5, attraction = 250, distance = 450, chakra = 60, recharge = 22, duree_mudra = 0.8 },
    [2] = { degats = 12 },
    [3] = { degats = 14, chakra = 54, rayon = 420 },
    [4] = { degats = 17, recharge = 19, attraction = 300 },
    [5] = { degats = 20, chakra = 48, recharge = 16, duree = 6, rayon = 460 },
}

-- Rasenshuriken Futon (server/futon/sv_futon_rasenshuriken.lua) : le lanceur monte dans les airs, joue l'animation et lance un Rasenshuriken qui explose au contact
--   degats = de l'explosion (les mêmes partout dans le rayon), rayon = de l'explosion, vitesse = du Rasenshuriken, duree_vie = secondes avant qu'il disparaisse, poussee / souleve = projection horizontale / verticale,
--   hauteur = montée du lanceur, vitesse_montee, delai_lancer = secondes entre le début de l'animation et le lancer, fin_anim = secondes en l'air après le lancer
NA_NIV_TECH.futon_rasenshuriken = {
    [1] = { degats = 1000, rayon = 350, vitesse = 1400, duree_vie = 3, poussee = 500, souleve = 300, hauteur = 350, vitesse_montee = 700, delai_lancer = 2, fin_anim = 0.6, chakra = 80, recharge = 40, duree_mudra = 0.4 },
    [2] = { degats = 1050 },
    [3] = { degats = 1150, rayon = 400, chakra = 72 },
    [4] = { degats = 1200, recharge = 34 },
    [5] = { degats = 1300, rayon = 450, chakra = 64, recharge = 1 },
}

-- Wind Ball (sv_futon_windball.lua)
NA_NIV_TECH.futon_windball = {
    [1] = {
        degats = 60, chakra = 20, recharge = 6,
        vitesse = 1500, duree_vie = 2, hitbox = 30, hitbox_haut = 30, echelle = 0.5, recul = 600, souleve = 250, duree_mudra = 0.5,
    },
    [2] = { degats = 76 },
    [3] = { degats = 80, recharge = 5.5, hitbox = 34 },
    [4] = { degats = 88 },
    [5] = { degats = 95, chakra = 16, recharge = 4.5, hitbox = 38, recul = 750 },
}

--========================================================
-- RAITON
--========================================================
-- Jugement de l'éclair (sv_raiton_jugement.lua) : duree = étourdissement
NA_NIV_TECH.raiton_jugement = {
    [1] = {
        degats = 50, chakra = 30, recharge = 14, duree = 1.5, rayon = 180, portee = 900,
    },
    [2] = { degats = 55 },
    [3] = { degats = 60, duree = 1.8, recharge = 13 },
    [4] = { degats = 65, rayon = 210 },
    [5] = { degats = 80, duree = 2.2, chakra = 24, recharge = 11 },
}

-- Cercle de foudre (sv_raiton_cercle.lua) : à chaque impulsion, dégâts + projection vers l'extérieur
NA_NIV_TECH.raiton_cercle = {
    [1] = {
        degats = 70, chakra = 35, recharge = 15,
        rayon = 320, impulsions = 1, intervalle = 0.8, recul = 700, souleve = 250, duree_mudra = 0.5,
    },
    [2] = { degats = 80 },
    [3] = { degats = 90, recharge = 13.5},
    [4] = { degats = 100, rayon = 350 },
    [5] = { degats = 110, chakra = 28, recharge = 12},
}

-- Boule de foudre (sv_raiton_boule.lua) : duree = étourdissement
NA_NIV_TECH.raiton_boule = {
    [1] = { degats = 40, chakra = 25, recharge = 10, duree = 1.5, vitesse = 1300, duree_mudra = 0.3 },
    [2] = { degats = 50 },
    [3] = { degats = 60, duree = 1.8, recharge = 9 },
    [4] = { degats = 70, vitesse = 1500 },
    [5] = { degats = 80, duree = 2.2, chakra = 20, recharge = 8 },
}

--========================================================
-- Zone de foudre (sv_raiton_zone.lua) : zone autour du lanceur ; dégâts à chaque tick, et toutes les `pulse` secondes les ennemis dedans sont étourdis
--   duree = secondes de zone, rayon, degats = par tick, intervalle = secondes entre deux ticks, pulse = secondes entre deux étourdissements, stun = secondes d'étourdissement
NA_NIV_TECH.raiton_zone = {
    [1] = { degats = 10, rayon = 450, duree = 10, intervalle = 0.5, pulse = 3, stun = 1, chakra = 45, recharge = 15, duree_mudra = 0.8 },
    [2] = { degats = 12 },
    [3] = { degats = 15, chakra = 40, stun = 1.2 },
    [4] = { degats = 18, recharge = 13 },
    [5] = { degats = 25, chakra = 35, recharge = 11, stun = 1.5, duree = 12 },
}

-- Chidori (sv_raiton_chidori.lua) : charge dans la main gauche, course droit devant, impact sur le premier ennemi touché : dégâts + étourdissement
--   degats, stun = secondes d'étourdissement, vitesse = de la course, duree = secondes de course (portée = vitesse x duree), charge = secondes de charge avant de courir
NA_NIV_TECH.raiton_chidori = {
    [1] = { degats = 70, stun = 2, vitesse = 1000, duree = 3, charge = 0.8, chakra = 55, recharge = 18 },
    [2] = { degats = 80 },
    [3] = { degats = 92, chakra = 50, charge = 0.7 },
    [4] = { degats = 105, recharge = 15 },
    [5] = { degats = 120, chakra = 45, charge = 0.6, recharge = 13 },
}

-- Kirin (sv_raiton_kirin.lua) : un nuage se forme au-dessus du point visé, le Kirin en sort et frappe le sol : dégâts + étourdissement
--   degats, rayon = zone autour de l'impact, stun = secondes, vitesse = du Kirin, echelle = taille du modèle, angle_pitch / angle_yaw / angle_roll = orientation du modèle par rapport au vol (degrés), monte = hauteur de départ du Kirin au-dessus du centre du nuage, decal_x / decal_y = décalage horizontal (monde) du départ, centrer = 1 centre la boîte du modèle sur le point de départ (0 = l'origine du modèle), face_moi = 1 : le Kirin regarde le lanceur (face = degrés de correction : 180 si c'est son dos, 90 / -90 de profil), anim_cycle = pose figée de l'animation du modèle (0 à 1 ; -1 = animation jouée, il dérive), debug = 1 : le Kirin reste immobile en l'air (sans recharge) pour régler les angles, 0 = normal, portee = distance max du point visé, delai_nuage = secondes avant la sortie du Kirin
NA_NIV_TECH.raiton_kirin = {
    [1] = { degats = 750, rayon = 350, stun = 2, vitesse = 600, echelle = 2, angle_pitch = 90, angle_yaw = 180, angle_roll = 0, monte = 1700, decal_x = 0, decal_y = 0, centrer = 1, debug = 0, anim_cycle = -1, face_moi = 1, face = 0, portee = 1200, delai_nuage = 0.5, chakra = 90, recharge = 50, duree_mudra = 0.5 },
    [2] = { degats = 830 },
    [3] = { degats = 870, chakra = 82, stun = 2.5 },
    [4] = { degats = 940, recharge = 44 },
    [5] = { degats = 1000, chakra = 75, stun = 3, recharge = 1 },
}

-- Poing de foudre (sv_raiton_poing.lua) : petit bond puis plongeon vers le bas, poing chargé ; onde + dégâts + projection à l'atterrissage
--   degats, rayon = zone autour de l'impact, projection / proj_haut = vitesses données aux ennemis, stun = secondes d'étourdissement des ennemis touchés, vitesse = du plongeon, saut = hauteur du bond, delai_plongee = secondes de bond avant de plonger
NA_NIV_TECH.raiton_poing = {
    [1] = { degats = 50, rayon = 280, projection = 450, proj_haut = 280, stun = 0.5, vitesse = 1700, saut = 600, delai_plongee = 0.45, chakra = 40, recharge = 16 },
    [2] = { degats = 56 },
    [3] = { degats = 63, rayon = 310, chakra = 36 },
    [4] = { degats = 70, recharge = 14 },
    [5] = { degats = 80, rayon = 340, projection = 550, chakra = 32, recharge = 1 },
}

--========================================================
-- DOTON
--========================================================
-- Boule de roche (sv_doton_pierre.lua)
NA_NIV_TECH.doton_pierre = {
    [1] = {
        degats = 64, chakra = 20, recharge = 8,
        vitesse = 1300, duree_vie = 2, hitbox = 22, hitbox_haut = 22, echelle = 0.45, recul = 500, souleve = 200, duree_mudra = 0.6,
    },
    [2] = { degats = 76 },
    [3] = { degats = 86, recharge = 7 },
    [4] = { degats = 97, hitbox = 25, echelle = 0.52 },
    [5] = { degats = 105, chakra = 16, recharge = 6 },
}

-- Séisme (sv_doton_seisme.lua) : dégâts à chaque tick ; la recharge compte depuis la FIN de la zone
NA_NIV_TECH.doton_seisme = {
    [1] = { degats = 8, chakra = 20, recharge = 10, duree = 5, rayon = 250, intervalle = 0.5, duree_mudra = 0.8 },
    [2] = { degats = 12 },
    [3] = { degats = 15, recharge = 9 },
    [4] = { degats = 18, rayon = 280 },
    [5] = { degats = 22, chakra = 16, recharge = 8, duree = 6 },
}

-- Voyage souterrain (sv_doton_taupe.lua) : duree = temps sous terre ; recharge compte depuis la sortie
NA_NIV_TECH.doton_taupe = {
    [1] = { chakra = 30, recharge = 15, duree = 6 },
    [2] = { duree = 7 },
    [3] = { recharge = 13 },
    [4] = { duree = 8 },
    [5] = { chakra = 24, recharge = 11, duree = 10 },
}

-- Dragon de terre (sv_doton_dragon.lua) : un dragon de roche sort du sol, s'oriente vers là où regarde le lanceur et tire des projectiles
--   duree = secondes du dragon, cadence = secondes entre deux tirs, degats = par projectile, vitesse = d'un projectile, echelle = taille du dragon, devant = distance où il sort
NA_NIV_TECH.doton_dragon = {
    [1] = { degats = 20, duree = 5, cadence = 0.2, vitesse = 1600, echelle = 1.2, devant = 90, chakra = 60, recharge = 25, duree_mudra = 0.8 },
    [2] = { degats = 23 },
    [3] = { degats = 26, chakra = 54 },
    [4] = { degats = 30, duree = 6, recharge = 22 },
    [5] = { degats = 35, cadence = 0.2, chakra = 48, recharge = 18 },
}

-- Golem de roche (server/doton/sv_doton_golem.lua) : le lanceur devient un golem (lv_golem_dot) ; clic gauche = attaque ; relancer = le détruire
--   duree = secondes sous forme de golem, degats = de l'attaque, rayon = zone qui frappe, reduction = % de dégâts reçus en moins, echelle = taille du golem
NA_NIV_TECH.doton_golem = {
    [1] = { duree = 30, degats = 90, rayon = 200, reduction = 50, echelle = 0.55, chakra = 70, recharge = 45, duree_mudra = 0.6 },
    [2] = { degats = 105 },
    [3] = { duree = 35, degats = 120, chakra = 64, reduction = 55 },
    [4] = { degats = 140, recharge = 38 },
    [5] = { duree = 40, degats = 165, chakra = 58, reduction = 60, recharge = 1 },
}

-- Éruption de roche (sv_doton_eruption.lua) : des roches de MÊME taille sortent du sol en éventail devant le lanceur
--   rangees, par_rangee = nombre de roches, rayon = zone touchée autour d'une roche, echelle = taille (1 = taille du modèle, ~14 x 30), degats, stun (0 = aucun), duree_vie
NA_NIV_TECH.doton_eruption = {
    [1] = { degats = 120, rayon = 95, rangees = 6, par_rangee = 5, echelle = 5, stun = 0, duree_vie = 2, chakra = 45, recharge = 16, duree_mudra = 0.4 },
    [2] = { degats = 134 },
    [3] = { degats = 140, rangees = 7, chakra = 41 },
    [4] = { degats = 152, recharge = 14 },
    [5] = { degats = 160, rangees = 8, par_rangee = 6, chakra = 36, recharge = 12 },
}

-- Pics de pierre (sv_doton_pics.lua) : comme le Cube Jinton, vise l'ennemi le plus proche dans la hitbox de visée ; dégâts + étourdissement + pierre
--   degats, stun = secondes d'étourdissement, portee = distance maximale, hitbox = demi-taille de la boîte de visée
NA_NIV_TECH.doton_pics = {
    [1] = { degats = 50, stun = 2, portee = 900, hitbox = 20, chakra = 35, recharge = 14, duree_mudra = 0.5 },
    [2] = { degats = 58, stun = 2.3 },
    [3] = { degats = 64, hitbox = 24, chakra = 32 },
    [4] = { degats = 72, stun = 2.7, recharge = 12 },
    [5] = { degats = 80, hitbox = 28, stun = 3, chakra = 28, recharge = 10 },
}

--========================================================
-- MOKUTON
--========================================================
-- Arche (server/mokuton/mokuton_arche_sv.lua)
NA_NIV_TECH.mokuton_arche = {
    [1] = {
        degats = 20, recharge = 2, hitbox = 40,
        trace_range = 1000, damage_radius = 120, height = 800, drop_time = 0.6, stun_time = 4,
        count = 3, delay = 0.1, gap = 4, duree_mudra = 0.6,
    },
    [2] = { degats = 22 },
    [3] = { degats = 24, hitbox = 46 },
    [4] = { degats = 26 },
    [5] = { degats = 28, recharge = 1.6, hitbox = 52 },
}

-- Fleur (server/mokuton/mokuton_fleur_sv.lua)
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

-- Protection de bois (server/mokuton/mokuton_protection_sv.lua) : duree = temps cocon FERMÉ ; recharge compte depuis la fin
NA_NIV_TECH.mokuton_protection = {
    [1] = { chakra = 25, recharge = 15, duree = 6, soin = 4, intervalle = 0.5, echelle = 1, duree_mudra = 0.6 },
    [2] = { soin = 5 },
    [3] = { recharge = 13, duree = 7 },
    [4] = { soin = 6 },
    [5] = { chakra = 20, recharge = 10, duree = 8, soin = 8 },
}

-- Mains de bois (server/mokuton/mokuton_wood_hand_sv.lua)
NA_NIV_TECH.mokuton_wood_hand = {
    [1] = { degats = 30, chakra = 30, recharge = 12, rayon = 200, souleve = 350, portee = 900, echelle = 1, duree_mudra = 0.5 },
    [2] = { degats = 35, recharge = 11 },
    [3] = { degats = 40, recharge = 10 },
    [4] = { degats = 46, rayon = 220, portee = 1000 },
    [5] = { degats = 55, chakra = 24, recharge = 8 },
}

-- Golem de bois (server/mokuton/mokuton_golem_sv.lua) : degats = attaque 1 ; duree = temps transformé ; recharge après la fin
NA_NIV_TECH.mokuton_golem = {
    [1] = { degats = 40, chakra = 60, recharge = 40, duree = 30, rayon = 200, reduction = 50, duree_mudra = 0.6 },
    [2] = { degats = 46 },
    [3] = { degats = 52, duree = 35, recharge = 36 },
    [4] = { degats = 60, rayon = 220 },
    [5] = { degats = 70, chakra = 50, duree = 45, recharge = 10, reduction = 60 },
}

-- Dragon (server/mokuton/mokuton_dragon_sv.lua) : aucune stat branchée par NA_Stat,
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
        etourdi = 2.5, delai_lancer = 0.6, portee = 1000, vitesse_fil = 3000,
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
        vitesse = 1500, duree_vie = 1, echelle = 0.6, ecart = 28, devant = 50,
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
    [2] = { degats = 43,duree = 1.7 },
    [3] = { degats = 47, hitbox = 24,duree = 2 },
    [4] = { degats = 50 ,duree = 2.5},
    [5] = { degats = 55, chakra = 24, hitbox = 28,duree = 3 ,intervalle = 0.5},
}

-- Bouclier Jinton (sv_jinton_bouclier.lua) : degats = explosion du bouclier
NA_NIV_TECH.jinton_bouclier = {
    [1] = {
        degats = 70, chakra = 25, recharge = 20,
        explo_hauteur = 140, explo_rayon = 500, pourcent_vie = 20, echelle = 1.35, duree = 10,
        resistance = 25, explosions = 3,
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
        portee = 1000, hauteur = 600, rayon = 700, ralenti = 0.75, intervalle = 0.5,
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
-- HYUGA
--========================================================
-- Byakugan (server/hyuga/sv_hyuga_byakugan.lua) : à activer / désactiver
--   chakra = PAR SECONDE, rayon = distance de détection à travers les murs
NA_NIV_TECH.hyuga_byakugan = {
    [1] = {
        chakra = 1, chakra_mini = 15, recharge = 15, duree_mudra = 0.3, rayon = 1000,
    },
    [2] = { rayon = 1200 },
    [3] = { chakra = 2, rayon = 1400 },
    [4] = { rayon = 1700 },
    [5] = { chakra = 3, recharge = 12, rayon = 2000 },
}

-- Paume du Hakke (server/hyuga/sv_hyuga_paume.lua)
--   portee/rayon = portée du bras et zone d'impact, recul/souleve = projection
NA_NIV_TECH.hyuga_paume = {
    [1] = {
        degats = 32, chakra = 12, recharge = 8, portee = 500, rayon = 60,
        recul = 550, souleve = 80, delai_impact = 0.65,
    },
    [2] = { degats = 35 },
    [3] = { degats = 38, recharge = 7 },
    [4] = { degats = 41 },
    [5] = { degats = 45, chakra = 10, recharge = 6 },
}

-- Coup de pied tournoyant (server/taijutsu/sv_taijutsu_pied.lua)
--   etourdi = secondes d'étourdissement de la cible
NA_NIV_TECH.taijutsu_pied = {
    [1] = {
        degats = 28, chakra = 10, recharge = 8, portee = 130, recul = 350, souleve = 60,
        etourdi = 1.5, delai_impact = 0.4,
    },
    [2] = { degats = 31 },
    [3] = { degats = 34, recharge = 7, etourdi = 1.8 },
    [4] = { degats = 38 },
    [5] = { degats = 42, chakra = 8, recharge = 6, etourdi = 2.2 },
}

-- Coup de pied descendant (server/taijutsu/sv_taijutsu_descendant.lua) : dégâts seulement
NA_NIV_TECH.taijutsu_descendant = {
    [1] = { degats = 35, chakra = 8, recharge = 6, portee = 130, delai_impact = 0.4 },
    [2] = { degats = 39 },
    [3] = { degats = 43, recharge = 5.5 },
    [4] = { degats = 48 },
    [5] = { degats = 54, chakra = 6, recharge = 5 },
}

-- Enchaînement aérien (server/taijutsu/sv_taijutsu_combo.lua)
--   degats = 1er coup, degats_final = coup de talon, lancer = hauteur de l'envol
NA_NIV_TECH.taijutsu_combo = {
    [1] = {
        degats = 15, degats_final = 40, chakra = 30, recharge = 18, portee = 150,
        lancer = 450, delai_impact = 0.35, delai_sommet = 0.45, delai_final = 0.5,
    },
    [2] = { degats = 17, degats_final = 45 },
    [3] = { degats = 19, degats_final = 50, recharge = 16 },
    [4] = { degats = 21, degats_final = 56 },
    [5] = { degats = 24, degats_final = 64, chakra = 25, recharge = 14 },
}

-- Coup de pied relevé (server/taijutsu/sv_taijutsu_releve.lua) : 2 coups dans l'animation
--   degats = 1er coup (dégâts seulement), degats_envol = 2e coup (dégâts + la cible monte), lancer = vitesse verticale,
--   delai_impact / delai_envol = secondes entre le lancement de l'animation et chaque coup
NA_NIV_TECH.taijutsu_releve = {
    [1] = { degats = 25, degats_envol = 25, chakra = 20, recharge = 14, portee = 140, lancer = 220, delai_impact = 0.3, delai_envol = 0.7 },
    [2] = { degats = 28, degats_envol = 28 },
    [3] = { degats = 31, degats_envol = 31, recharge = 12 },
    [4] = { degats = 34, degats_envol = 34, lancer = 240 },
    [5] = { degats = 38, degats_envol = 38, chakra = 16, recharge = 10 },
}

-- 32 Points du Hakke (server/hyuga/sv_hyuga_32points.lua)
--   degats = PAR TICK de la rafale, intervalle = secondes entre 2 ticks,
--   etourdi = secondes d'étourdissement de la cible (= durée totale de la rafale)
NA_NIV_TECH.hyuga_32points = {
    [1] = {
        degats = 6, chakra = 35, recharge = 20, portee = 300, rayon = 50,
        intervalle = 0.25, etourdi = 1,
    },
    [2] = { degats = 7 },
    [3] = { degats = 8, recharge = 18, etourdi = 2 },
    [4] = { degats = 9 },
    [5] = { degats = 10, chakra = 30, recharge = 5, etourdi = 2.5 },
}

-- 64 Points du Hakke (server/hyuga/sv_hyuga_64points.lua)
--   degats = PAR TICK de la rafale, intervalle = secondes entre 2 ticks,
--   etourdi = secondes d'étourdissement de la cible (= durée totale de la rafale)
NA_NIV_TECH.hyuga_64points = {
    [1] = {
        degats = 8, chakra = 45, recharge = 26, portee = 600, rayon = 50,
        intervalle = 0.2, etourdi = 4,
    },
    [2] = { degats = 9 },
    [3] = { degats = 10, recharge = 23, etourdi = 4.5 },
    [4] = { degats = 11 },
    [5] = { degats = 13, chakra = 38, recharge = 2, etourdi = 5 },
}

-- Tourbillon Divin (server/hyuga/sv_hyuga_tourbillon.lua)
--   degats = PAR IMPULSION, intervalle = secondes entre 2 impulsions,
--   duree = durée totale de la rotation
NA_NIV_TECH.hyuga_tourbillon = {
    [1] = {
        degats = 15, chakra = 35, recharge = 16, duree = 2.5, intervalle = 0.5,
        rayon = 200, recul = 700, souleve = 150,
    },
    [2] = { degats = 17 },
    [3] = { degats = 19, recharge = 14, duree = 3 },
    [4] = { degats = 21 },
    [5] = { degats = 24, chakra = 30, recharge = 12, duree = 3.5 },
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
        rayon = 150, portee = 1500, montee = 1000, fin_vol = 0.5, duree_mudra = 0.3, anim_coupe = 0.4,
    },
    [2] = { degats = 9 },
    [3] = { degats = 10, boules = 12, recharge = 20 },
    [4] = { degats = 11, rayon = 150 },
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
    [5] = { degats = 13, duree = 8, chakra = 25, recharge = 14, ralenyti = 0.5 },
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

--========================================================
-- SENJU
--========================================================
-- Renforcement (sv_senju_renfo.lua) : à activer / désactiver
--   chakra = coût au lancement (une fois), duree = secondes d'effet, bonus_degats / reduction / bonus_vitesse = en %,
--   regen_vie = points de vie par seconde,
--   recharge = secondes avant de pouvoir le réactiver (après la fin)
NA_NIV_TECH.senju_renfo = {
    [1] = {
        chakra = 25, recharge = 15, duree = 12, duree_mudra = 0.5,
        bonus_degats = 10,bonus_vitesse = 5,
    },
    [2] = { bonus_degats = 17, duree = 13 },
    [3] = { chakra = 22, duree = 15, bonus_degats = 20, bonus_vitesse = 8 },
    [4] = { bonus_degats = 22, duree = 17 },
    [5] = { chakra = 20, recharge = 12, duree = 20, bonus_degats = 25, bonus_vitesse = 12 },
}

-- Soin (sv_senju_soin.lua) : vie rendue = soin_pourcent % de la vie MAX, étalés sur "duree" secondes
NA_NIV_TECH.senju_soin = {
    [1] = { soin_pourcent = 25, duree = 5, chakra = 30, recharge = 25, duree_mudra = 0.5 },
    [2] = { soin_pourcent = 27 },
    [3] = { soin_pourcent = 30, chakra = 27, recharge = 23 },
    [4] = { soin_pourcent = 33 },
    [5] = { soin_pourcent = 35, chakra = 24, recharge = 20 },
}

-- Frappe terrestre (sv_senju_frappe.lua) : coup de poing au sol, onde de choc devant le lanceur
--   degats = dégâts de l'onde, rayon = taille de la zone, projection / proj_haut = force de projection,
--   delai_impact = secondes entre le début de l'animation et le coup au sol
NA_NIV_TECH.senju_frappe = {
    [1] = { degats = 60, chakra = 30, recharge = 12, rayon = 200, projection = 350, proj_haut = 200, delai_impact = 0.6 },
    [2] = { degats = 75 },
    [3] = { degats = 83, chakra = 27, recharge = 11 },
    [4] = { degats = 95, rayon = 230 },
    [5] = { degats = 107, chakra = 24, recharge = 9, projection = 420 },
}

-- Coup de pied céleste (sv_senju_pied.lua) : saut puis plongeon là où regarde le joueur, onde de choc à l'atterrissage
--   degats / rayon / projection / proj_haut = comme la Frappe terrestre, saut = force du saut,
--   vitesse = vitesse du plongeon, delai_plongee = secondes de saut avant de foncer
NA_NIV_TECH.senju_pied = {
    [1] = { degats = 60, chakra = 45, recharge = 20, rayon = 320, projection = 500, proj_haut = 300, saut = 550, vitesse = 1500, delai_plongee = 0.45 },
    [2] = { degats = 65 },
    [3] = { degats = 72, chakra = 40, recharge = 18 },
    [4] = { degats = 80, rayon = 360 },
    [5] = { degats = 180, chakra = 35, recharge = 5, projection = 600 },
}

-- Ermite naturel (sv_senju_ermite.lua) : à activer / désactiver ; chakra = PAR SECONDE, chakra_mini = requis pour l'activer,
--   bonus_degats / reduction / bonus_vitesse = en %, regen_vie = PV par seconde,
--   recharge = secondes avant de pouvoir la réactiver (après l'arrêt)
NA_NIV_TECH.senju_ermite = {
    [1] = { chakra = 4, chakra_mini = 30, recharge = 5, duree_mudra = 1, bonus_degats = 20, reduction = 15, bonus_vitesse = 10, regen_vie = 3 },
    [2] = { bonus_degats = 23 },
    [3] = { chakra = 3.5, reduction = 18, regen_vie = 4 },
    [4] = { bonus_degats = 27 },
    [5] = { chakra = 3, bonus_degats = 32, reduction = 22, bonus_vitesse = 14, regen_vie = 6 },
}

--========================================================
-- UCHIHA
--========================================================
-- Dragons de feu (server/uchiha/sv_uchiha_dragons.lua) : degats = par tick, zone au sol la où tu regardes
NA_NIV_TECH.katon_dragons = {
    [1] = {
        degats = 8, recharge = 15, delai = 0.9,
        duree = 6, rayon = 250, portee = 1500, intervalle = 0.5,
        brulure_duree = 3, brulure_dps = 3,
    },
    [2] = { degats = 9 },
    [3] = { degats = 11, rayon = 290, brulure_dps = 4 },
    [4] = { degats = 13, duree = 7 },
    [5] = { degats = 15, rayon = 330, duree = 8, recharge = 12, brulure_duree = 4, brulure_dps = 5 },
}

-- Genjutsu du Sharingan (server/uchiha/sv_uchiha_genjutsu.lua) : stun pur, duree = secondes d'étourdissement
NA_NIV_TECH.uchiha_genjutsu = {
    [1] = { chakra = 30, recharge = 20, duree = 3, portee = 800, hitbox = 20, duree_mudra = 0.5 },
    [2] = { duree = 3.5 },
    [3] = { duree = 4, hitbox = 24, chakra = 26 },
    [4] = { duree = 4.5, recharge = 17 },
    [5] = { duree = 5, chakra = 22, recharge = 15, portee = 1000 },
}

-- Shuriken géant (server/uchiha/sv_uchiha_shuriken.lua) : projectile enflammé, brûlure à l'impact
NA_NIV_TECH.uchiha_shuriken = {
    [1] = {
        degats = 50, chakra = 25, recharge = 8, vitesse = 1800, duree_vie = 3, echelle = 1.5,
        brulure_duree = 4, brulure_dps = 4, duree_mudra = 0.5,
    },
    [2] = { degats = 56 },
    [3] = { degats = 63, chakra = 22, brulure_dps = 5 },
    [4] = { degats = 70, recharge = 7 },
    [5] = { degats = 80, chakra = 20, recharge = 6, echelle = 1.8, brulure_duree = 5, brulure_dps = 6 },
}

-- Chiens d'encre (server/inkuton/sv_inkuton_chiens.lua) : trois chiens partent en ligne droite
NA_NIV_TECH.inkuton_chiens = {
    [1] = {
        degats = 35, chakra = 25, recharge = 8, vitesse = 900, duree_vie = 1.5, echelle = 1,
        ecart = 40, devant = 60, duree_mudra = 0, delai_chiens = 0.6,
    },
    [2] = { degats = 40 },
    [3] = { degats = 46, chakra = 22 },
    [4] = { degats = 52, recharge = 7 },
    [5] = { degats = 60, chakra = 20, recharge = 6, duree_vie = 1.8 },
}

-- Singes d'encre (server/inkuton/sv_inkuton_singes.lua) : singes à tête chercheuse, ralentissent
-- la cible, la blessent chaque seconde (degats = par tick) et la marquent (marque = secondes après l'effet)
NA_NIV_TECH.inkuton_singes = {
    [1] = {
        degats = 10, intervalle = 1, duree = 1.5, marque = 8, ralenti = 0.4,
        chakra = 30, recharge = 14, vitesse = 420, nombre = 3, ecart = 40, devant = 60,
        duree_mudra = 0, delai_singes = 0.6, portee = 1000,
    },
    [2] = { degats = 12 },
    [3] = { degats = 14, chakra = 27, duree = 2.5 },
    [4] = { degats = 16, recharge = 12, ralenti = 0.35 },
    [5] = { degats = 20, chakra = 24, recharge = 10, duree = 3, marque = 10, ralenti = 0.3 },
}

-- Serpents d'encre (server/inkuton/sv_inkuton_serpents.lua) : rampent vers la cible, dégâts au contact
--   rotation = degrés/s de virage (plus bas = plus facile à esquiver)
NA_NIV_TECH.inkuton_serpents = {
    [1] = {
        degats = 25, chakra = 30, recharge = 12, vitesse = 700, rotation = 220, duree_vie = 3,
        nombre = 3, decalage = 0.25, ecart = 40, devant = 60, duree_mudra = 0, delai = 0.6, portee = 1000,
    },
    [2] = { degats = 30 },
    [3] = { degats = 30, chakra = 27 },
    [4] = { degats = 35, recharge = 10, rotation = 260 },
    [5] = { degats = 40, chakra = 24, recharge = 8, nombre = 4, rotation = 300 },
}

-- Moine d'encre (server/inkuton/sv_inkuton_moine.lua) : bouclier = % des PV max du lanceur, frappe à portée
NA_NIV_TECH.inkuton_moine = {
    [1] = { bouclier = 30, degats = 20, portee = 200, duree = 20, recharge = 25, chakra = 35, duree_mudra = 0, delai = 0.6 },
    [2] = { bouclier = 35, degats = 24 },
    [3] = { bouclier = 40, degats = 28, duree = 25, chakra = 32 },
    [4] = { bouclier = 45, degats = 34, portee = 250, recharge = 22 },
    [5] = { bouclier = 55, degats = 42, duree = 30, chakra = 28, recharge = 18 },
}

-- Dieux d'encre (server/inkuton/sv_inkuton_dieux.lua) : deux dieux courent tout droit et frappent au contact
NA_NIV_TECH.inkuton_dieux = {
    [1] = { degats = 80, chakra = 45, recharge = 20, vitesse = 1200, duree_vie = 3, etourdi = 2, ecart = 100, devant = 60, duree_mudra = 0, delai = 0.6 },
    [2] = { degats = 95 },
    [3] = { degats = 110, chakra = 40 },
    [4] = { degats = 130, recharge = 17, vitesse = 1200, etourdi = 2.5 },
    [5] = { degats = 160, chakra = 35, recharge = 14, duree_vie = 4, etourdi = 3 },
}

-- Dragon d'encre (server/inkuton/sv_inkuton_dragon.lua) : vol puis charge (clic droit)
--   vitesse_vol = vitesse en vol, vitesse = vitesse de la charge, duree = secondes de la charge,
--   rayon = zone qui blesse, recul / souleve = projection de la cible, recharge = secondes avant de le réinvoquer
NA_NIV_TECH.inkuton_dragon = {
    [1] = { degats = 250, rayon = 130, vitesse = 2800, vitesse_vol = 1200, duree = 1.2, recul = 700, souleve = 250, recharge = 3, duree_mudra = 1 },
    [2] = { degats = 300, duree_mudra = 0.9 },
    [3] = { degats = 330, duree_mudra = 0.8, recharge = 2.5 },
    [4] = { degats = 350, duree_mudra = 0.7, rayon = 150 },
    [5] = { degats = 400, duree_mudra = 0.5, recharge = 2, rayon = 170, duree = 1.5 },
}

-- Oiseaux explosifs (server/bakuton/sv_bakuton_oiseaux.lua) : un oiseau visible à la fois, clic gauche pour le lancer
--   nombre = oiseaux à lancer (le cooldown démarre quand tous sont lancés), retour = secondes avant le suivant
NA_NIV_TECH.bakuton_oiseaux = {
    [1] = { degats = 25, rayon = 130, vitesse = 1000, chakra = 30, nombre = 2, intervalle = 0.4, retour = 0.5, recharge = 15 },
    [2] = { degats = 30 },
    [3] = { degats = 30, nombre = 3, chakra = 27 },
    [4] = { degats = 40, recharge = 13 },
    [5] = { degats = 40, nombre = 4, chakra = 24, recharge = 10, rayon = 160 },
}

-- Mignons d'argile (server/bakuton/sv_bakuton_mignons.lua) : courent vers la cible et explosent au contact
--   rotation = degrés/s de virage (plus bas = plus facile à esquiver)
NA_NIV_TECH.bakuton_mignons = {
    [1] = { degats = 50, rayon = 130, chakra = 30, recharge = 12, vitesse = 450, rotation = 220, duree_vie = 4, nombre = 3, decalage = 0.3, ecart = 40, devant = 60, duree_mudra = 0, delai = 0.6, detection = 500 },
    [2] = { degats = 58 },
    [3] = { degats = 66, chakra = 27 },
    [4] = { degats = 76, recharge = 10, rotation = 260 },
    [5] = { degats = 90, chakra = 24, recharge = 8, nombre = 4, rotation = 300 },
}

-- Araignées explosives (server/bakuton/sv_bakuton_araignees.lua) : stun de la cible visée, puis explosion
--   duree = secondes de stun, degats = par araignée à l'explosion, nombre = araignées lancées
NA_NIV_TECH.bakuton_araignees = {
    [1] = { degats = 15, duree = 0.5, vitesse = 600, nombre = 6, decalage = 0.08, chakra = 35, recharge = 14, duree_mudra = 0, delai = 0.6, portee = 900, hitbox = 20 },
    [2] = {  duree = 0.8 },
    [3] = { duree = 1.2, chakra = 32 },
    [4] = {  duree = 1.5, recharge = 12 },
    [5] = { duree = 1.8, chakra = 28, recharge = 10, nombre = 8 },
}

-- Meute d'araignées (server/bakuton/sv_bakuton_meute.lua) : comme les serpents d'encre, elles courent vers la cible
--   et explosent au contact ; rotation = degrés/s de virage (plus bas = plus facile à esquiver)
NA_NIV_TECH.bakuton_meute = {
    [1] = { degats = 10, rayon = 110, chakra = 35, recharge = 13, vitesse = 650, rotation = 240, duree_vie = 4, nombre = 5, decalage = 0.15, ecart = 30, devant = 60, duree_mudra = 0, delai = 0.6, detection = 500 },
    [2] = { degats = 12 },
    [3] = { degats = 13, chakra = 32 },
    [4] = { degats = 14, recharge = 11, rotation = 280 },
    [5] = { degats = 15, chakra = 28, recharge = 9, nombre = 7, rotation = 320 },
}

-- Dragon d'argile (server/bakuton/sv_bakuton_dragon.lua) : vol sur le dragon (pilotage des ailes de papier)
--   duree = secondes de vol (E ou relancer pour descendre avant)
NA_NIV_TECH.bakuton_dragon = {
    [1] = { duree = 20, chakra = 40, recharge = 45, duree_mudra = 0.6 },
    [2] = { duree = 24 },
    [3] = { duree = 28, chakra = 36 },
    [4] = { duree = 32, recharge = 38 },
    [5] = { duree = 40, chakra = 30, recharge = 1 },
}

-- Déflagration (server/bakuton/sv_bakuton_bombe.lua) : le lanceur monte dans le ciel, puis une bombe géante
--   tombe sur le point visé ; hauteur = montée (unités), vitesse = vitesse de montée, attente = secondes en l'air
--   avant de lâcher la bombe, degats = au centre (moitié en bordure), rayon = de l'explosion
NA_NIV_TECH.bakuton_bombe = {
    [1] = { degats = 500, rayon = 700, chakra = 70, recharge = 60, hauteur = 700, vitesse = 900, attente = 1.0, duree_mudra = 0.6 },
    [2] = { degats = 600, rayon = 780 },
    [3] = { degats = 700, chakra = 65, recharge = 54 },
    [4] = { degats = 900, rayon = 880, recharge = 48 },
    [5] = { degats = 1000, rayon = 980, chakra = 55, recharge = 5 },
}

-- Émanation de vapeur (server/futton/sv_futton_vapeur.lua) : buff de vitesse (multiplicateur) + dégâts par tick autour du lanceur
--   duree = secondes du buff, vitesse = multiplicateur de vitesse, degats = par tick, intervalle = secondes entre ticks, rayon = de la vapeur
NA_NIV_TECH.futton_vapeur = {
    [1] = { duree = 8, vitesse = 1.3, degats = 6, intervalle = 0.5, rayon = 220, chakra = 30, recharge = 20, duree_mudra = 0.4 },
    [2] = { vitesse = 1.35, degats = 7 },
    [3] = { duree = 9, degats = 8, chakra = 27 },
    [4] = { vitesse = 1.4, degats = 9, recharge = 17 },
    [5] = { duree = 11, vitesse = 1.5, degats = 11, rayon = 260, chakra = 24, recharge = 14 },
}

-- Tornade de vapeur (server/futton/sv_futton_tornade.lua) : nombre tornades partent devant le lanceur en éventail
--   degats = par tick, intervalle = secondes entre ticks, rayon = de chaque tornade, vitesse, duree_vie = secondes (portée = vitesse x durée), ecart = degrés entre tornades
NA_NIV_TECH.futton_tornade = {
    [1] = { degats = 70, intervalle = 0.3, rayon = 90, vitesse = 800, duree_vie = 3, nombre = 1, ecart = 10, devant = 60, chakra = 35, recharge = 14, duree_mudra = 0.3 },
    [2] = { degats = 80 },
    [3] = { degats = 90, chakra = 32 },
    [4] = { degats = 100, recharge = 12, duree_vie = 3.5 },
    [5] = { degats = 113, chakra = 28, recharge = 10, rayon = 110, duree_vie = 4 },
}

-- Cage de vapeur (server/futton/sv_futton_cage.lua) : zone posée là où le lanceur regarde ; ceux dedans ne sortent plus, personne d'autre n'entre
--   rayon / hauteur = taille de la cage, duree = secondes, portee = distance de visée maximale, degats = par tick (toutes les intervalle s) à ceux dedans
NA_NIV_TECH.futton_cage = {
    [1] = { rayon = 300, hauteur = 400, duree = 6, portee = 1500, degats = 5, intervalle = 0.5, chakra = 50, recharge = 30, duree_mudra = 0.4 },
    [2] = { duree = 7, degats = 6 },
    [3] = { duree = 8, degats = 7, chakra = 45 },
    [4] = { duree = 9, degats = 8, rayon = 340, recharge = 26 },
    [5] = { duree = 10, degats = 10, rayon = 380, chakra = 40, recharge = 22 },
}

-- Monde de vapeur (server/futton/sv_futton_monde.lua) : grande zone sur le lanceur ; les ennemis dedans sont ralentis et subissent des dégâts par tick
--   rayon / hauteur = taille de la zone, duree = secondes, degats = par tick, intervalle = secondes entre ticks, ralenti = multiplicateur de vitesse des ennemis
NA_NIV_TECH.futton_monde = {
    [1] = { rayon = 920, hauteur = 400, duree = 10, degats = 8, intervalle = 0.5, ralenti = 0.6, chakra = 70, recharge = 60, duree_mudra = 0.6 },
    [2] = { degats = 10 },
    [3] = { duree = 12, degats = 12, chakra = 64 },
    [4] = { degats = 14, recharge = 52, ralenti = 0.55 },
    [5] = { duree = 15, degats = 18,chakra = 56, recharge = 10, ralenti = 0.5 },
}

-- Dôme de glace (server/hyoton/sv_hyoton_dome.lua) : zone sur le lanceur ; les ennemis dedans sont ralentis et subissent des dégâts par tick
--   rayon / hauteur = taille de la zone, duree = secondes, degats = par tick, intervalle = secondes entre ticks, ralenti = multiplicateur de vitesse des ennemis
NA_NIV_TECH.hyoton_dome = {
    [1] = { rayon = 400, hauteur = 300, duree = 8, degats = 15, intervalle = 0.5, ralenti = 0.7, chakra = 50, recharge = 30, duree_mudra = 0.6 },
    [2] = { degats =  20},
    [3] = { duree = 10, degats = 8, chakra = 46 },
    [4] = { degats = 22, recharge = 26, ralenti = 0.65 },
    [5] = { duree = 15, degats = 25, chakra = 42, recharge = 22, ralenti = 0.6 },
}

-- Pics de glace (server/hyoton/sv_hyoton_pics.lua) : des pics sortent du sol en éventail devant le lanceur
--   rangees = nombre de rangées (3 pics chacune), rayon = zone touchée autour d'un pic, degats = par ennemi (une fois), stun = secondes,
--   echelle = taille des pics, duree_vie = secondes avant qu'ils disparaissent
NA_NIV_TECH.hyoton_pics = {
    [1] = { rangees = 8, rayon = 70, degats = 60, stun = 0, echelle = 0.6, duree_vie = 0.8, chakra = 40, recharge = 14, duree_mudra = 0.4 },
    [2] = { degats = 75 },
    [3] = { rangees = 10, degats = 84, chakra = 36 },
    [4] = { degats = 87, stun = 0, recharge = 12 },
    [5] = { rangees = 12, degats = 96, stun = 0, chakra = 32, recharge = 10 },
}

-- Vague de glace (server/hyoton/sv_hyoton_vague.lua) : un bouquet de pics avance tout droit au ras du sol, touche le premier ennemi
--   portee = distance max, vitesse = unités/s, rayon = demi-largeur qui touche, degats, stun = secondes, echelle = taille du modèle
NA_NIV_TECH.hyoton_vague = {
    [1] = { portee = 900, vitesse = 1100, rayon = 90, degats = 50, stun = 1, echelle = 0.8, chakra = 45, recharge = 16, duree_mudra = 0.4 },
    [2] = { degats = 60 },
    [3] = { portee = 1200, degats = 70, chakra = 40 },
    [4] = { degats = 85, stun = 1.5, recharge = 14 },
    [5] = { portee = 1400, vitesse = 1300, degats = 100, stun = 2, chakra = 36, recharge = 3 },
}

-- Loups de glace (server/hyoton/sv_hyoton_loup.lua) : rampent vers la cible, dégâts au contact (comme les serpents d'encre)
--   rotation = degrés/s de virage (plus bas = plus facile à esquiver)
NA_NIV_TECH.hyoton_loup = {
    [1] = {
        degats = 45, chakra = 40, recharge = 14, vitesse = 700, rotation = 220, duree_vie = 3,
        nombre = 2, decalage = 0.25, ecart = 60, devant = 60, duree_mudra = 0.4, portee = 1000,
    },
    [2] = { degats = 55 },
    [3] = { degats = 65, chakra = 36 },
    [4] = { degats = 75, recharge = 12, rotation = 260 },
    [5] = { degats = 90, chakra = 32, recharge = 10, nombre = 3, rotation = 300 },
}

-- Prison de glace (server/hyoton/sv_hyoton_prison.lua) : stun de la cible visée dans une arène de miroirs, dégâts par tick
--   duree = secondes de stun, degats = par tick, intervalle = secondes entre ticks, portee = distance de visée maximale, hitbox = demi-taille de la hitbox de visée
NA_NIV_TECH.hyoton_prison = {
    [1] = { duree = 2.5, degats = 5, intervalle = 0.5, portee = 900, hitbox = 25, chakra = 45, recharge = 18, duree_mudra = 0.3 },
    [2] = { degats = 6 },
    [3] = {  degats = 8, chakra = 40 },
    [4] = {  degats = 10, recharge = 15 },
    [5] = { duree =3, degats = 12, chakra = 36, recharge = 12 },
}

-- Cristal (server/shoton/sv_shoton_cristal.lua) : un projectile invisible avance, le premier ennemi touché est enfermé dans un cristal (stun)
--   duree = secondes de stun, portee = distance max du projectile, vitesse = unités/s, rayon = demi-largeur de sa hitbox
NA_NIV_TECH.shoton_cristal = {
    [1] = { duree = 3, portee = 900, vitesse = 1500, rayon = 30, chakra = 40, recharge = 18, duree_mudra = 0.3 },
    [2] = { duree = 3.5 },
    [3] = { duree = 4, chakra = 36 },
    [4] = { duree = 4.5, recharge = 15 },
    [5] = { duree = 5, chakra = 32, recharge = 1 },
}

-- Armure de cristal (server/shoton/sv_shoton_armure.lua) : armure rose pendant "duree" secondes
--   duree = secondes, reduction = % de dégâts subis en moins, chakra = coût
NA_NIV_TECH.shoton_armure = {
    [1] = { duree = 15, reduction = 35, chakra = 40, recharge = 30, duree_mudra = 0.4 },
    [2] = { duree = 16, reduction = 38 },
    [3] = { duree = 18, reduction = 42, chakra = 36 },
    [4] = { duree = 20, reduction = 46, recharge = 26 },
    [5] = { duree = 22, reduction = 50, chakra = 32, recharge = 22 },
}

-- Roquettes (server/shoton/sv_shoton_rockets.lua) : le lanceur s'élève et tire "nombre" roquettes de cristal
--   degats = par roquette (zone), explosion = rayon de zone, nombre, intervalle = secondes entre tirs, hauteur = montée, vitesse
NA_NIV_TECH.shoton_rockets = {
    [1] = { degats = 60, explosion = 120, nombre = 3, intervalle = 0.45, hauteur = 450, montee = 0.9, vitesse = 1600, chakra = 60, recharge = 25, duree_mudra = 0.3 },
    [2] = { degats = 70 },
    [3] = { degats = 80, chakra = 54 },
    [4] = { degats = 90, recharge = 22 },
    [5] = { degats = 105, chakra = 48, recharge = 18 , nombre = 5 },
}

-- Pics de cristal (server/shoton/sv_shoton_pics.lua) : une forêt de cristaux sort du sol en éventail devant le lanceur
--   rangees = nombre de rangées, par_rangee = cristaux par rangée, rayon = zone touchée autour d'un cristal,
--   degats = par ennemi (une fois), stun = secondes, echelle = taille des cristaux, duree_vie = secondes avant qu'ils disparaissent
NA_NIV_TECH.shoton_pics = {
    [1] = { rangees = 6, par_rangee = 6, rayon = 90, degats = 280, stun = 0.5, echelle = 0.8, duree_vie = 1.8, chakra = 55, recharge = 20, duree_mudra = 0.4 },
    [2] = { degats = 300 },
    [3] = { rangees = 7, degats = 330, chakra = 50 },
    [4] = { degats = 380, recharge = 17 },
    [5] = { rangees = 8, par_rangee = 7, degats = 170, chakra = 45, recharge = 14 },
}

-- Chute de cristal (server/shoton/sv_shoton_chute.lua) : un gros cristal tombe du ciel sur le point visé
--   portee = distance de visée max, hauteur = hauteur de départ, degats = dégâts de zone, explosion = rayon de zone,
--   stun = secondes d'étourdissement, echelle = taille du cristal
NA_NIV_TECH.shoton_chute = {
    [1] = { portee = 800, hauteur = 700, degats = 120, explosion = 150, stun = 0.8, echelle = 0.8, chakra = 70, recharge = 25, duree_mudra = 0.4 },
    [2] = { degats = 135 },
    [3] = { degats = 150, chakra = 63 },
    [4] = { degats = 170, recharge = 22, explosion = 170 },
    [5] = { degats = 195, chakra = 56, recharge = 18, explosion = 190 },
}

-- Prison de vapeur (server/futton/sv_futton_prison.lua) : stun de la cible visée, dans une cage de vapeur
--   duree = secondes de stun, portee = distance de visée maximale, hitbox = demi-taille de la hitbox de visée
NA_NIV_TECH.futton_prison = {
    [1] = { duree = 2.5, portee = 900, hitbox = 25, chakra = 40, recharge = 18, duree_mudra = 0.3 },
    [2] = { duree = 3 },
    [3] = { duree = 3.5, chakra = 36 },
    [4] = { duree = 4, recharge = 15 },
    [5] = { duree = 5, chakra = 32, recharge = 12 },
}

-- Projectile de vapeur (server/futton/sv_futton_projectile.lua) : un projectile droit, dégâts au premier ennemi touché
--   degats = dégâts, rayon = demi-largeur de la hitbox, vitesse, duree_vie = secondes (portée = vitesse x durée), devant = distance de départ
NA_NIV_TECH.futton_projectile = {
    [1] = { degats = 80, rayon = 30, vitesse = 1800, duree_vie = 2, devant = 50, chakra = 45, recharge = 10, duree_mudra = 0.3 },
    [2] = { degats = 90 },
    [3] = { degats = 100, chakra = 40 },
    [4] = { degats = 115, recharge = 8 },
    [5] = { degats = 130, chakra = 35, recharge = 6, duree_vie = 2.5 },
}

-- Sharingan (server/uchiha/sv_uchiha_sharingan.lua) : à activer / désactiver
--   tomoe = 1 à 3 (niveaux 1-2 : 1 tomoe, niveau 3 : 2 tomoe, niveaux 4-5 : 3 tomoe),
--   chakra = PAR SECONDE, chakra_mini = requis pour l'activer,
--   rayon = détection à travers les murs, bonus_degats / reduction = en %
NA_NIV_TECH.uchiha_sharingan = {
    [1] = { tomoe = 1, chakra = 1.5, chakra_mini = 15, recharge = 10, duree_mudra = 0.3, rayon = 800, bonus_degats = 5, reduction = 5 },
    [2] = { bonus_degats = 8, reduction = 8, rayon = 950 },
    [3] = { tomoe = 2, chakra = 2, bonus_degats = 12, reduction = 12, rayon = 1200 },
    [4] = { tomoe = 3, chakra = 2.5, bonus_degats = 18, reduction = 16, rayon = 1500 },
    [5] = { chakra = 3, recharge = 8, bonus_degats = 25, reduction = 20, rayon = 1800 },
}
