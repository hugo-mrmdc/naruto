--========================================================
-- Liste des attaques + équipement de la barre (CLIENT)
-- Ouvre avec F2, ou la commande console : attaques
--
-- Fond : materials/ui/main_menu/fond.png. Onglets à gauche (ONGLETS plus bas),
-- techniques au centre, barre en bas, détail de la technique à droite.
--
-- Équiper une technique dans la barre (touches 1 à 6) :
--   - glisse la technique sur un emplacement de la barre ;
--   - ou clique sur la technique, puis sur un emplacement ;
--   - ou double-clic (premier emplacement libre).
--   Clic droit sur un emplacement pour le vider.
--
-- Pour ajouter une technique : une ligne dans TECHNIQUES ci-dessous.
--   key   = code de touche (KEY_*) -> le vrai nom de la touche est affiché,
--           ou texte ("Clic gauche") -> affiché tel quel
--   id    = identifiant NA_Cast de la technique (la rend équipable dans la barre)
--   court = nom court affiché dans l'emplacement de la barre
--   rang  = rang de la technique : "C", "B", "A" ou "S" (affiché dans les menus)
--   cd       = recharge en secondes comptée côté client dès le lancement (bloque la touche)
--   cooldown = vrai cooldown du serveur, AFFICHÉ dans les menus (ne bloque rien)
--   icone = image de la technique, chemin RELATIF au dossier materials/
--           ex : "ui/icon/kami_aile_papier.png"  (vide "" = nom court affiché à la place)
--========================================================

local OPEN_KEY = KEY_F2

local TECHNIQUES = {
    -- ===== KATON =====
    { cat = "Katon", name = "Boule de feu", key = KEY_Y, id = "katon_boule", rang = "C", icone = "ui/icon/katon_boule_feu.png", court = "Feu", cooldown = 1, cd = 3,
      desc = "Projette une boule de feu qui suit la direction du regard." },
   
    { cat = "Katon", name = "Dôme de feu", key = "", id = "katon_dome", rang = "C", icone = "ui/icon/shakuton_zone_ardente.png", court = "Dôme feu", cooldown = 10,
      desc = "Un dôme de flammes surgit au sol autour de toi pendant 5 secondes : il blesse et brûle tous les ennemis dedans. Coûte 20 de chakra.",
      dmg = "6 par tick (toutes les 0,5 s) + brûlure" },
    { cat = "Katon", name = "Souffle katon", key = "", id = "katon_souffle", rang = "C", icone = "ui/icon/katon_souffle_feu.png", court = "Souffle", cooldown = 8,
      desc = "Souffle un jet de flammes devant toi pendant 3 secondes, dans la direction de ton regard : il blesse et brûle tous les ennemis dans le cône. Coûte 25 de chakra.",
      dmg = "5 par tick (toutes les 0,25 s) + brûlure" },
     { cat = "Uchiha", name = "Boule de feu sautée", key = KEY_J, id = "katon_saut", rang = "C", icone = "ui/icon/uchiha_boule_feu_supreme.png", court = "Saut feu", cooldown = 1, cd = 2,
      desc = "Charge de chakra puis boule de feu avec un bond." },
    { cat = "Uchiha", name = "Dragons de feu", key = KEY_COMMA, id = "katon_dragons", rang = "B", icone = "ui/icon/uchiha_flamme_infernal.png", court = "Dragons", cooldown = 15,
      desc = "Une zone de flammes s'ouvre au sol là où tu regardes : des dragons de feu en jaillissent pendant 6 secondes, blessent et brûlent tous les ennemis dans la zone.",
      dmg = "8 par tick (toutes les 0,5 s) + brûlure" },

    -- ===== SUITON =====
    { cat = "Suiton", name = "Requin d'eau", key = KEY_R, id = "suiton_requin", rang = "B", icone = "", court = "Requin", cooldown = 5, cd = 5.3,
      desc = "Envoie un requin d'eau sur la cible visée." },
    { cat = "Suiton", name = "Boule d'eau", key = "", id = "suiton_waterball", rang = "C", icone = "ui/icon/suiton_bombe_eau.png", court = "Boule d'eau", cooldown = 6,
      desc = "Lance une boule d'eau droit devant toi : elle blesse et repousse le premier ennemi touché. Coûte 20 de chakra.",
      dmg = "30 à l'impact + projection" },
    { cat = "Suiton", name = "Prison aqueuse", key = "", id = "suiton_prison", rang = "C", icone = "ui/icon/suiton_prison_aqueuse.png", court = "Prison", cooldown = 12,
      desc = "Enferme l'ennemi visé (800 unités max) dans une prison d'eau : maintiens le CLIC DROIT pour la garder : il est soulevé dans les airs, étourdi et immobilisé (5 secondes maximum), et subit des dégâts à chaque tick. Il ne peut recevoir aucun autre dégât tant qu'il est dans la prison. Relâche pour le libérer. Coûte 30 de chakra.",
      dmg = "4 par tick (toutes les 0,5 s), étourdi tant que tu maintiens (5 s max)" },

    { cat = "Suiton", name = "Bulles", key = "", id = "suiton_bulle", rang = "C", icone = "ui/icon/suiton_douche_aqueuse.png", court = "Bulles", cooldown = 8,
      desc = "Souffle une salve de bulles d'eau en éventail devant toi : chaque bulle qui touche un ennemi éclate et lui fait mal, donc plus il en prend, plus ça fait mal. Coûte 25 de chakra.",
      dmg = "8 par bulle (10 bulles)" },

    -- ===== FUTON =====
    { cat = "Futon", name = "Wind Slash", key = "", id = "futon_windslash", rang = "C", icone = "ui/icon/futon_lamelle_air.png", court = "Wind Slash", cooldown = 5,
      desc = "Lance une lame de vent en forme de croissant droit devant toi : elle fonce en ligne droite et blesse le premier ennemi touché. Coûte 20 de chakra.",
      dmg = "35 à l'impact" },
    { cat = "Futon", name = "Tornade", key = "", id = "futon_tornade", rang = "C", icone = "ui/icon/futon_tornade_vent.png", court = "Tornade", cooldown = 12,
      desc = "Fait surgir une tornade de vent devant toi : elle avance dans la direction de ton regard pendant 4 secondes, blesse tout ce qu'elle touche et le projette en l'air. Elle se dissipe contre un mur. Coûte 30 de chakra.",
      dmg = "6 par tick (toutes les 0,25 s)" },
    { cat = "Futon", name = "Wind Ball", key = "", id = "futon_windball", rang = "C", icone = "ui/icon/futon_balle_vent.png", court = "Wind Ball", cooldown = 6,
      desc = "Lance une boule de vent droit devant toi : elle blesse le premier ennemi touché et le projette violemment en arrière et vers le haut. Coûte 20 de chakra.",
      dmg = "25 à l'impact + projection" },

    -- ===== RAITON =====
    { cat = "Raiton", name = "Jugement de l'éclair", key = "", id = "raiton_jugement", rang = "C", icone = "ui/icon/raiton_jugement_eclair.png", court = "Jugement", cooldown = 14,
      desc = "La foudre s'abat là où tu regardes (900 unités max) : tous les ennemis proches du point d'impact prennent des dégâts et sont étourdis un instant. Coûte 30 de chakra.",
      dmg = "30 dégâts + étourdi 1,5 s" },
    { cat = "Raiton", name = "Cercle de foudre", key = "", id = "raiton_cercle", rang = "C", icone = "ui/icon/raiton_cercle_de_foudre.png", court = "Cercle", cooldown = 15,
      desc = "Déploie un cercle de foudre autour de toi : à chaque impulsion (3 en tout), tous les ennemis dans la zone prennent des dégâts et sont repoussés vers l'extérieur. Coûte 35 de chakra.",
      dmg = "12 par impulsion (3 impulsions) + projection" },

    { cat = "Raiton", name = "Boule de foudre", key = "", id = "raiton_boule", rang = "C", icone = "ui/icon/raiton_boule_electrique.png", court = "Boule", cooldown = 10,
      desc = "Lance une boule de foudre droit devant toi : elle blesse le premier ennemi touché et l'étourdit un instant. Coûte 25 de chakra.",
      dmg = "30 dégâts + étourdi 1,5 s" },

    -- ===== DOTON =====
    { cat = "Doton", name = "Boule de roche", key = "", id = "doton_pierre", rang = "C", icone = "ui/icon/doton_boule_de_roche.png", court = "Roche", cooldown = 8,
      desc = "Lance un rocher droit devant toi : il roule en ligne droite, blesse le premier ennemi touché et le projette en arrière. Coûte 20 de chakra.",
      dmg = "40 à l'impact + projection" },
    { cat = "Doton", name = "Séisme", key = "", id = "doton_seisme", rang = "C", icone = "ui/icon/doton_tremblement_de_terre.png", court = "Séisme", cooldown = 10,
      desc = "Fait trembler le sol autour de toi pendant 5 secondes : tous les ennemis dans la zone prennent des dégâts à chaque impulsion. Coûte 20 de chakra.",
      dmg = "5 par impulsion (toutes les 0,5 s, pendant 5 s)" },
    { cat = "Doton", name = "Voyage souterrain", key = "", id = "doton_taupe", rang = "C", icone = "ui/icon/doton_taupe.png", court = "Taupe", cooldown = 15,
      desc = "Tu passes sous terre pendant 6 secondes : tu deviens invisible et tu ne peux plus subir aucun dégât, mais tu ne peux ni sauter ni faire la course de chakra. Appuie sur E pour ressortir plus tôt ; aucun jutsu possible sous terre. Coûte 30 de chakra.",
      dmg = "Invulnérable 6 s" },

    -- ===== MOKUTON =====
    { cat = "Mokuton", name = "Arche", key = KEY_K, id = "mokuton_arche", rang = "C", icone = "ui/icon/arche.png", court = "Arche", cd = 2,
      desc = "Fait jaillir une arche de bois devant toi." },
    --{ cat = "Mokuton", name = "Fleur", key = KEY_O, id = "mokuton_fleur", rang = "C", icone = "", court = "Fleur", cd = 1.5,
      --desc = "Fait pousser une fleur de bois à l'endroit visé." },
    { cat = "Mokuton", name = "Protection de bois", key = "", id = "mokuton_protection", rang = "C", icone = "ui/icon/protection_mokuton.png", court = "Protection", cooldown = 15,
      desc = "Un cocon de bois se referme autour de toi pendant 6 secondes : tu es invincible et tu te soignes à chaque impulsion, mais tu ne peux lancer aucun jutsu. Coûte 25 de chakra.",
      dmg = "Soigne 4 toutes les 0,5 s + invincible" },
    { cat = "Mokuton", name = "Mains de bois", key = "", id = "mokuton_wood_hand", rang = "B", icone = "ui/icon/mokuton_mains.png", court = "Mains", cooldown = 12,
      desc = "Les mains du Bouddha rieur surgissent du sol là où tu regardes (900 unités max) et frappent : tous les ennemis proches sont blessés et projetés en l'air, puis les mains disparaissent. Coûte 30 de chakra.",
      dmg = "30 dégâts + projection en l'air" },
 
    { cat = "Mokuton", name = "Dragon", key = "B / L", id = "mokuton_dragon", rang = "B", icone = "ui/icon/dragon_mokuton.png", court = "Dragon", cooldown = 1,
      desc = "Invoque le dragon et monte dessus (B), ou le renvoie (L). En vol, le CLIC DROIT (ou l'emplacement de la barre) lance le dragon comme un projectile dans la direction de ton regard. En vol : Espace pour monter, Ctrl pour descendre." },
         { cat = "Mokuton", name = "Golem de bois", key = "", id = "mokuton_golem", rang = "A", icone = "ui/icon/golem_mokuton.png", court = "Golem", cooldown = 40,
      desc = "Tu deviens un golem de bois géant pendant 30 secondes et tu résistes à 50 % des dégâts : le clic gauche lance un combo de trois attaques qui blessent et projettent tout devant toi. Tu ne peux ni lancer de jutsu ni dasher sous cette forme. Rappuie pour redevenir normal. Coûte 60 de chakra.",
      dmg = "40 / 52 / 80 par coup du combo" },
  --  { cat = "Mokuton", name = "Dragon : attraper", key = KEY_E,
    --  desc = "En vol, attrape la cible devant toi dans la gueule. Rappuie pour la lâcher." },

    -- ===== SALAMANDRE =====
    { cat = "Salamandre", name = "Invocation", key = KEY_U,
      desc = "Fait apparaître la salamandre, ou la renvoie. E sur elle pour la monter." },
    { cat = "Salamandre", name = "Dôme de brume", key = KEY_T, id = "salamandre_dome", rang = "B", icone = "ui/icon/salamandre_nuage_poison.png", court = "Dôme", cooldown = 6,
      desc = "Pose au sol un dôme de brume toxique pendant 5 secondes : il blesse et empoisonne tous ceux qui sont dedans, sauf toi. Coûte 15 de chakra.",
      dmg = "5 par demi-seconde + poison" },
    { cat = "Salamandre", name = "Crachat de poison", key = KEY_I, id = "salamandre_poison", rang = "C", icone = "ui/icon/salamandre_tir_poison.png", court = "Poison", cooldown = 1, cd = 2.5,
      desc = "Crache un projectile empoisonné : dégâts à l'impact puis poison pendant quelques secondes. Coûte 10 de chakra.",
      dmg = "50 + 10 par seconde" },
    { cat = "Salamandre", name = "Typhon de poison", key = "Barre", id = "salamandre_tornade", rang = "A", icone = "ui/icon/salamandre_tornade_poison.png", court = "Typhon", cooldown = 12,
      desc = "Fait naître un typhon là où tu regardes (900 unités max) pendant 6 secondes : il aspire les ennemis vers son cœur, qui les blesse et les empoisonne. Un cercle au sol montre l'endroit pendant l'incantation. Uniquement depuis la barre. Coûte 25 de chakra.",
      dmg = "8 par demi-seconde au cœur + poison" },
    { cat = "Salamandre", name = "Corps de poison", key = "Barre", id = "salamandre_corps", rang = "B", icone = "ui/icon/salamandre_corp_poison.png", court = "Corps", cooldown = 15,
      desc = "Ton corps suinte le poison pendant 10 secondes : ceux qui te collent sont brûlés et empoisonnés, ceux qui te frappent de près sont empoisonnés, et tu es immunisé contre le poison. Uniquement depuis la barre. Coûte 20 de chakra.",
      dmg = "4 par demi-seconde au contact + poison" },

    -- ===== FUMA =====
    { cat = "Fuma", name = "Téléportation", key = "", id = "fuma_tp", rang = "C", icone = "ui/icon/fuma_shuriken.png", court = "TP", cooldown = 2,
      desc = "Lance un shuriken : rappuie pour te téléporter dessus. S'il touche un mur, tu y es téléporté automatiquement ; s'il touche un ennemi, il explose. S'il ne touche rien, il disparaît.",
      dmg = "60 (explosion sur un ennemi)" },
    { cat = "Fuma", name = "Jugement des Quatre Lames", key = "", id = "fuma_jugement", rang = "B", icone = "ui/icon/fuma_jugement_shuriken.png", court = "Jugement", cooldown = 18,
      desc = "Lance un fil d'acier là où tu vises. S'il touche un ennemi, il est étourdi 2,5 secondes : quatre shurikens apparaissent au-dessus de lui, un de chaque côté, et foncent sur lui. Coûte 25 de chakra.",
      dmg = "4 x 20" },
    { cat = "Fuma", name = "Aura Fuma", key = "", id = "fuma_aura", rang = "B", icone = "ui/icon/fuma_morsure_sanglante.png", court = "Aura", cooldown = 25,
      desc = "Une aura t'entoure pendant 12 secondes : tu infliges 30 % de dégâts en plus et tu en encaisses 25 % de moins. Coûte 20 de chakra.",
      dmg = "+30 % de dégâts, -25 % de dégâts subis" },
    { cat = "Fuma", name = "Shuriken Céleste", key = "", id = "fuma_ciel", rang = "A", icone = "ui/icon/fuma_shuriken_acier.png", court = "Céleste", cooldown = 28,
      desc = "Un shuriken géant tombe du ciel sur le point que tu vises et explose en fumée au sol : dégâts de zone et projection. Coûte 35 de chakra.",
      dmg = "70 au centre" },
    { cat = "Fuma", name = "Invisibilité", key = "", id = "fuma_invisibilite", rang = "C", icone = "ui/icon/fuma_invisible.png", court = "Invisible", cooldown = 8,
      desc = "Te rend invisible 10 secondes après une seconde d'incantation, dans un nuage de fumée. Rappuie pour réapparaître plus tôt ; lancer un autre jutsu te fait aussi réapparaître." },

    -- ===== KAMI =====
    { cat = "Kami", name = "Kami Circle", key = "", id = "kami_circle", rang = "B", icone = "ui/icon/kami_tornade_papier.png", court = "Cercle", cooldown = 12,
      desc = "Zone de dégâts posée au sol. Touche tout le monde sauf toi. Réglable en console (kami_circle_damage, kami_circle_tick).",
      dmg = "20 par tick" },
    { cat = "Kami", name = "Shuriken de papier", key = "", id = "kami_shuriken", rang = "C", icone = "ui/icon/kami_shuriken_papier.png", court = "Shuriken", cooldown = 1.5, cd = 25,
      desc = "Lance un shuriken de papier tournoyant dans la direction du regard. Coûte 8 de chakra.",
      dmg = "35 (70 à la tête)" },
    { cat = "Kami", name = "Paper Shield", key = "", id = "kami_bouclier", rang = "B", icone = "ui/icon/kami_bouclier_papier.png", court = "Bouclier", cooldown = 15,
      desc = "Enveloppe ton corps de papier : tu encaisses moitié moins de dégâts. Coûte 25 de chakra.",
      dmg = "-50 % de dégâts reçus" },
    { cat = "Kami", name = "Ailes de papier", key = "", id = "kami_ailes", rang = "A", icone = "ui/icon/kami_aile_papier.png", court = "Ailes", cooldown = 3,
      desc = "Fait apparaître des ailes dans ton dos et te permet de voler. Direction avec ZQSD, Espace pour monter, Ctrl pour descendre, rappuie pour te poser.",
      dmg = "6 chakra par seconde" },

    { cat = "Kami", name = "Roue de papier", key = "", id = "kami_roue", rang = "B", icone = "ui/icon/kami_tornade_papier.png", court = "Roue", cooldown = 10,
      desc = "Deux roues de papier partent côte à côte devant toi et roulent au sol dans la direction de ton regard, en projetant des feuilles, puis reviennent vers toi. Elles blessent et repoussent ceux qu'elles touchent (à l'aller comme au retour) ; un mur les fait revenir. Coûte 30 de chakra.",
      dmg = "30 par roue et par cible" },

    -- ===== JINTON =====
    { cat = "Jinton", name = "Cube de confinement", key = "", id = "jinton_cube", rang = "C", icone = "ui/icon/jinton_cube_confinement.png", court = "Cube", cooldown = 1,
      desc = "Vise un ennemi à portée : un cube l'enferme, l'immobilise 4 secondes et le ronge à chaque tick. Coûte 30 de chakra.",
      dmg = "8 par tick (toutes les 0,5 s)" },
    { cat = "Jinton", name = "Bouclier Jinton", key = "", id = "jinton_bouclier", rang = "C", icone = "ui/icon/jinton_bulle_poussiere.png", court = "Bouclier", cooldown = 20,
      desc = "Une sphère de poussière t'entoure pendant 10 secondes : un bouclier égal à 20 % de ta vie max encaisse les dégâts à ta place. Appuie sur E pour le faire exploser avant la fin. Coûte 25 de chakra.",
      dmg = "Bouclier de 20 % de la vie" },
    { cat = "Jinton", name = "Rayon de dissolution", key = "", id = "jinton_laser", rang = "A", icone = "ui/icon/jinton_rayon_dissolution.png", court = "Rayon", cooldown = 30,
      desc = "Pendant 15 secondes, tu t'envoles et un laser part de ta main vers là où tu vises. Il traverse tout jusqu'au premier mur et ronge ce qu'il touche. Vol : ZQSD, Espace pour monter, Ctrl pour descendre. Coûte 40 de chakra.",
      dmg = "6 par tick (toutes les 0,25 s)" },

    -- ===== KAGUYA =====
    { cat = "Kaguya", name = "Armure d'os", key = "", id = "kaguya_armure", rang = "C", icone = "ui/icon/kaguya_armure_os.png", court = "Armure", cooldown = 10,
      desc = "Fais pousser une armure d'os sur ton corps (rappuie pour la retirer) : tant qu'elle est active, tu encaisses 40 % de dégâts en moins. Consomme 4 de chakra par seconde (tu peux recharger avec R en même temps) ; elle se brise quand le chakra est vide. Il faut 20 de chakra pour l'activer.",
      dmg = "-40 % de dégâts subis" },
    { cat = "Kaguya", name = "Légion d'os", key = "", id = "kaguya_legion", rang = "A", icone = "ui/icon/kaguya_legion_os.png", court = "Légion", cooldown = 25,
      desc = "Des os jaillissent autour de toi pendant 8 secondes et blessent tous les ennemis proches à chaque tick. Coûte 30 de chakra.",
      dmg = "12 par tick (toutes les 0,5 s)" },
    { cat = "Kaguya", name = "Danse des os", key = "", id = "kaguya_danse", rang = "C", icone = "ui/icon/kaguya_danse_des_os.png", court = "Danse", cooldown = 20,
      desc = "Vise un ennemi : un lien s'accroche entre ton torse et lui pendant 6 secondes. Il perd de la vie à chaque tick et tu la récupères. Coûte 30 de chakra.",
      dmg = "12 par tick, +8 de vie pour toi" },

    -- ===== SENJU =====
    { cat = "Senju", name = "Renforcement Senju", key = "", id = "senju_renfo", rang = "B", icone = "ui/icon/senju_renfo.png", court = "Renfo", cooldown = 15,
      desc = "Un chakra vert t'entoure pendant 12 secondes (rappuie pour l'arrêter avant) : tu infliges 10 % de dégâts en plus et tu cours 5 % plus vite. Coûte 25 de chakra, une seule fois : la durée ne dépend pas du chakra restant.",
      dmg = "+10 % de dégâts, +5 % de vitesse pendant 12 s" },
    { cat = "Senju", name = "Soin Senju", key = "", id = "senju_soin", rang = "B", icone = "ui/icon/senju_soin.png", court = "Soin", cooldown = 25,
      desc = "Une aura de chakra t'entoure et te soigne : tu récupères 25 % de ta vie maximale, répartis sur 5 secondes. Tu peux te déplacer et te battre pendant le soin. Coûte 30 de chakra.",
      dmg = "+25 % de la vie max sur 5 secondes" },
    { cat = "Senju", name = "Frappe terrestre", key = "", id = "senju_frappe", rang = "B", icone = "ui/icon/senju_frappe_terrestre.png", court = "Frappe", cooldown = 12,
      desc = "Tu frappes le sol du poing devant toi : une onde de choc blesse et projette tous les ennemis proches. Coûte 30 de chakra.",
      dmg = "35 de dégâts + projection" },
    { cat = "Senju", name = "Coup de pied céleste", key = "", id = "senju_pied", rang = "A", icone = "ui/icon/senju_choc_sismique.png", court = "Pied", cooldown = 20,
      desc = "Tu sautes puis fonces dans la direction où tu regardes. À l'atterrissage, une énorme onde de choc blesse et projette tous les ennemis proches. Coûte 45 de chakra.",
      dmg = "60 de dégâts + projection" },
    { cat = "Senju", name = "Ermite naturel", key = "", id = "senju_ermite", rang = "S", icone = "ui/icon/senju_ermite_naturel.png", court = "Ermite", cooldown = 5,
      desc = "Active l'Ermite naturel (rappuie pour le couper) : tu infliges 20 % de dégâts en plus, tu subis 15 % de dégâts en moins, tu cours 10 % plus vite et ta vie se régénère de 3 points par seconde. Consomme 4 de chakra par seconde (tu peux recharger avec R en même temps) ; elle s'éteint quand le chakra est vide. Il faut 30 de chakra pour l'activer.",
      dmg = "+20 % de dégâts, -15 % de dégâts subis, +10 % de vitesse tant qu'elle est active" },

    -- ===== CHINOIKE =====
    { cat = "Chinoike", name = "Ketsuryugan", key = "", id = "chinoike_ketsuryugan", rang = "C", icone = "ui/icon/chinoike_ketsuryugan.png", court = "Ketsu", cooldown = 5,
      desc = "Active ton Ketsuryugan (rappuie pour le couper) : tant qu'il est actif, tu infliges 20 % de dégâts en plus, tu cours 15 % plus vite et chaque coup porté te rend 20 % des dégâts infligés en vie. Consomme 5 de chakra par seconde (tu peux recharger avec R en même temps) ; il s'éteint quand le chakra est vide. Il faut 20 de chakra pour l'activer.",
      dmg = "+20 % de dégâts, +15 % de vitesse, 20 % de vol de vie" },
    { cat = "Chinoike", name = "Genjutsu du Ketsuryugan", key = "", id = "chinoike_genjutsu", rang = "C", icone = "ui/icon/chinoike_ketsuryugan.png", court = "Genjutsu", cooldown = 25,
      desc = "Vise un ennemi à portée (800 unités) : ton Ketsuryugan s'allume et le piège dans un genjutsu pendant 3 secondes. Il est paralysé, le sang tourne autour de lui et il perd de la vie à chaque tick. Coûte 30 de chakra.",
      dmg = "6 par tick (toutes les 0,5 s)" },
    { cat = "Chinoike", name = "Pluie de sang", key = "", id = "chinoike_pluie", rang = "B", icone = "ui/icon/chinoike_zone_de_sang.png", court = "Pluie", cooldown = 22,
      desc = "Une pluie de sang s'abat sur l'endroit que tu vises pendant 8 secondes : tout ennemi qui reste dessous est blessé et ralenti. Coûte 35 de chakra.",
      dmg = "8 par tick (toutes les 0,5 s)" },
    { cat = "Chinoike", name = "Vortex de sang", key = "", id = "chinoike_vortex", rang = "B", icone = "ui/icon/typhon_chinoike.png", court = "Vortex", cd = 20,
      desc = "Un vortex de sang s'ouvre au sol là où tu vises (900 unités max) pendant 3,5 secondes : il aspire les ennemis vers son cœur, qui les blesse. Coûte 30 de chakra.",
      dmg = "10 par tick (toutes les 0,5 s)" },

    -- ===== HYUGA =====
    { cat = "Hyuga", name = "Byakugan", key = "", id = "hyuga_byakugan", rang = "C", icone = "ui/icon/hyuga_byakugan.png", court = "Byakugan", cooldown = 15,
      desc = "Active ton Byakugan (rappuie pour le couper) : tant qu'il est actif, tu détectes les ennemis proches à travers les murs. Consomme 1 de chakra par seconde (tu peux recharger avec R en même temps) ; il s'éteint quand le chakra est vide. Il faut 15 de chakra pour l'activer.",
      dmg = "détection à travers les murs (1000 unités)" },
    { cat = "Hyuga", name = "Paume du Hakke", key = "", id = "hyuga_paume", rang = "C", icone = "ui/icon/hyuga_128_poing_hakke.png", court = "Paume", cooldown = 8,
      desc = "Une frappe instantanée au corps à corps : projette de la chakra dans la cible touchée, la blesse et l'expulse en arrière. Coûte 12 de chakra.",
      dmg = "32 dégâts + projection" },
    { cat = "Hyuga", name = "32 Points du Hakke", key = "", id = "hyuga_32points", rang = "B", icone = "ui/icon/hyuga_poing_chakra.png", court = "32 Points", cooldown = 20,
      desc = "Un déluge de frappes devant toi : la cible touchée est étourdie et encaisse des dégâts à chaque tick pendant toute la durée de l'étourdissement. Pendant toute la technique, tu es invulnérable et totalement immobilisé (si tu es en l'air, tu ne retombes pas avant la fin). Coûte 35 de chakra.",
      dmg = "6 par tick (toutes les 0,25 s) + étourdi 3 s" },
    { cat = "Hyuga", name = "64 Points du Hakke", key = "", id = "hyuga_64points", rang = "A", icone = "ui/icon/hyuga_64_poing_hakke.png", court = "64 Points", cooldown = 26,
      desc = "Le déluge de frappes ultime : la cible touchée est étourdie et encaisse des dégâts à chaque tick pendant toute la durée de l'étourdissement. Pendant toute la technique, tu es invulnérable et totalement immobilisé (si tu es en l'air, tu ne retombes pas avant la fin). Coûte 45 de chakra.",
      dmg = "8 par tick (toutes les 0,2 s) + étourdi 4 s" },
    { cat = "Hyuga", name = "Tourbillon Divin", key = "", id = "hyuga_tourbillon", rang = "A", icone = "ui/icon/hyuga_tourbillion_divin_hakke.png", court = "Tourbillon", cooldown = 16,
      desc = "Une rotation défensive de chakra autour de toi pendant 2,5 secondes : tous les ennemis proches sont blessés et repoussés à chaque impulsion. Coûte 35 de chakra.",
      dmg = "15 par impulsion (toutes les 0,5 s) + projection" },

    -- ===== UCHIHA =====
    { cat = "Uchiha", name = "Sharingan", key = "", id = "uchiha_sharingan", rang = "C", icone = "ui/icon/uchiha_sharingan.png", court = "Sharingan", cooldown = 10,
      desc = "Active ton Sharingan (rappuie pour le couper) : tes yeux passent au rouge et tu détectes les ennemis proches à travers les murs. Les niveaux 1 et 2 donnent 1 tomoe, le niveau 3 en donne 2 et les niveaux 4 et 5 en donnent 3 : plus il y a de tomoe, plus tes dégâts, ta défense et ta vision augmentent. Consomme 1,5 de chakra par seconde (tu peux recharger avec R en même temps) ; il s'éteint quand le chakra est vide. Il faut 15 de chakra pour l'activer.",
      dmg = "1 tomoe : +5 % de dégâts, -5 % de dégâts subis, détection (800 unités)" },

    -- ===== KIMINARI =====
    { cat = "Kiminari", name = "Frappe noire", key = "", id = "kiminari_frappe", rang = "C", icone = "ui/icon/kiminari_frappe_noir.png", court = "Frappe", cooldown = 18,
      desc = "Une frappe électrique tombe instantanément là où tu regardes (500 unités max) : tous les ennemis dans la zone (250 unités) sont blessés et étourdis 2 secondes. Coûte 25 de chakra.",
      dmg = "15 + étourdissement 2 s" },
    { cat = "Kiminari", name = "Prison noire", key = "", id = "kiminari_prison", rang = "C", icone = "ui/icon/kiminari_prison_noir.png", court = "Prison", cooldown = 24,
      desc = "Une tornade électrique se pose autour de toi pendant 8 secondes (la zone reste où tu l'as lancée) : tout ennemi qui entre dans la zone (250 unités) OU qui en sort est blessé et étourdi 1,5 seconde. Coûte 35 de chakra.",
      dmg = "12 + étourdissement 1,5 s à chaque passage du bord" },
    { cat = "Kiminari", name = "Laser Circus", key = "", id = "kiminari_laser", rang = "B", icone = "ui/icon/kiminari_cercle_noir.png", court = "Laser", cooldown = 26,
      desc = "Tire 3 salves de lasers électriques depuis ta main : chaque laser part là où tu regardes (1200 unités max), sans visée automatique. Coûte 40 de chakra.",
      dmg = "14 par laser (3 salves)" },
    { cat = "Kiminari", name = "Boulets noirs", key = "", id = "kiminari_boulets", rang = "A", icone = "ui/icon/kiminari_boulet_noir.png", court = "Boulets", cooldown = 22,
      desc = "Tu bondis et flottes sur place : dix boules noires apparaissent dans ton dos, puis partent une par une vers là où tu vises (1500 unités max). Chacune explose à l'impact et blesse les ennemis autour. Coûte 30 de chakra.",
      dmg = "8 par boule (10 boules)" },

    -- ===== JITON =====
    { cat = "Jiton", name = "Sarcophage de sable", key = "", id = "jiton_sarcophage", rang = "C", icone = "ui/icon/jiton_sarcophage_de_sable.png", court = "Sarcophage", cooldown = 20,
      desc = "Vise un ennemi à portée (800 unités) : un sarcophage de sable se referme sur lui, le blesse une seule fois et l'étourdit 3 secondes. Coûte 30 de chakra.",
      dmg = "20 (une fois) + étourdissement 3 s" },
    { cat = "Jiton", name = "Émergence de sable", key = "", id = "jiton_emergence", rang = "C", icone = "ui/icon/jiton_emergence_de_sable.png", court = "Émergence", cooldown = 18,
      desc = "Le sable jaillit du sol à l'endroit où tu te trouves pendant 6 secondes : tout ennemi qui reste dans la zone (200 unités) est blessé à chaque tick et ralenti de 40 %. Coûte 30 de chakra.",
      dmg = "8 par tick (toutes les 0,5 s) + ralenti" },
    { cat = "Jiton", name = "Vortex de sable", key = "", id = "jiton_vortex", rang = "B", icone = "ui/icon/jiton_vortex_de_sable.png", court = "Vortex", cooldown = 20,
      desc = "Un vortex de sable s'ouvre au sol là où tu vises (900 unités max) pendant 3,5 secondes : il aspire les ennemis vers son cœur, qui les blesse. Coûte 30 de chakra.",
      dmg = "10 par tick (toutes les 0,5 s)" },
    { cat = "Jiton", name = "Tornade de sable", key = "", id = "jiton_tornade", rang = "B", icone = "ui/icon/jiton_tornade_de_sable.png", court = "Tornade", cooldown = 24,
      desc = "Une tornade de sable part tout droit devant toi, collée au sol (1500 unités) : chaque ennemi qu'elle traverse est blessé une fois et projeté en l'air. Coûte 40 de chakra.",
      dmg = "25 (une fois par ennemi) + projection" },
    { cat = "Jiton", name = "Nuage de sable", key = "", id = "jiton_nuage", rang = "A", icone = "ui/icon/jiton_suspension_du_desert.png", court = "Nuage", cooldown = 45,
      desc = "Un nuage de sable te porte : tu voles (ZQSD, Espace pour monter, Ctrl pour descendre) pendant 20 secondes. Appuie sur E pour en descendre avant. Coûte 35 de chakra.",
      dmg = "Vol pendant 20 s" },

    -- ===== ARMES =====
    --[[{ cat = "Armes", name = "Zabuza", key = "Clic gauche / droit",
      desc = "Kubikiribocho. Clic gauche pour trancher, clic droit pour la double explosion." },
    { cat = "Armes", name = "Shibuki", key = "Clic gauche / droit",
      desc = "Épée explosive : coups au corps à corps et déclenchement des parchemins." },
    { cat = "Armes", name = "Kabutowari", key = "Clic gauche / droit",
      desc = "Hache et marteau : attaque lourde à deux temps." },
    { cat = "Armes", name = "Hiramekarei", key = "Clic gauche / droit",
      desc = "Double sabre de chakra." },
    { cat = "Armes", name = "Shuriken Fuma", key = "Clic gauche / droit",
      desc = "Coups de lame, et lancer du shuriken géant au clic droit." },

    -- ===== DÉPLACEMENT =====
    { cat = "Déplacement", name = "Course", key = "Maj (Shift)",
      desc = "Course normale, sans coût de chakra." },
    { cat = "Déplacement", name = "Course de chakra", key = "Maj x2",
      desc = "Double appui rapide sur Maj puis maintiens : course très rapide et saut renforcé. Consomme du chakra et s'arrête quand la jauge est vide.",
      dmg = "18 chakra par seconde" },

    -- ===== DIVERS =====
    { cat = "Divers", name = "Caméra 3e personne", key = KEY_V,
      desc = "Bascule la vue devant / derrière le personnage." },
    { cat = "Divers", name = "Menu / inventaire", key = KEY_F4,
      desc = "Ouvre ton menu personnel." },
    { cat = "Divers", name = "Techniques et barre", key = KEY_F2,
      desc = "Ouvre ce menu. Les techniques se lancent uniquement avec les touches 1 à 6 de la barre." }, ]]--
}

-- Affichage trié par rang : C, puis B, puis A, puis S (F2 et bibliothèque F6).
-- À rang égal, l'ordre de la liste ci-dessus est gardé ; sans rang = à la fin.
local ORDRE_RANG = { C = 1, B = 2, A = 3, S = 4 }
do
    local place = {}
    for i, t in ipairs(TECHNIQUES) do place[t] = i end
    table.sort(TECHNIQUES, function(a, b)
        local ra, rb = ORDRE_RANG[a.rang] or 99, ORDRE_RANG[b.rang] or 99
        if ra ~= rb then return ra < rb end
        return place[a] < place[b]
    end)
end

-- Accès pour la barre de techniques (cl_skillbar.lua)
local parId = {}
for _, t in ipairs(TECHNIQUES) do
    if t.id then parId[t.id] = t end
end

NA_TechniquesListe = TECHNIQUES
function NA_TechniqueParId(id)
    return parId[id]
end

-- Rangs des techniques, du plus faible au plus fort : image (materials/ui/main_menu/)
-- et largeur / hauteur de l'image (pour garder ses proportions)
NA_RANGS = {
    C = { "ui/main_menu/icon_rank_c.png", 30 / 38 },
    B = { "ui/main_menu/icon_rank_b.png", 30 / 36 },
    A = { "ui/main_menu/icon_rank_a.png", 28 / 40 },
    S = { "ui/main_menu/icon_rank_s.png", 33 / 39 },   -- aucune technique pour l'instant
}

-- Dessine l'image du rang de la technique, "haut" pixels de haut.
-- ax = 0 : x est le bord gauche ; ax = 0.5 : x est le centre.
-- Renvoie la largeur dessinée (0 si la technique n'a pas de rang).
function NA_DessinerRang(t, x, y, haut, ax, a)
    local r = t and t.rang and NA_RANGS[t.rang]
    if not r then return 0 end
    local larg = haut * r[2]
    r.mat = r.mat or Material(r[1], "smooth mips")
    surface.SetMaterial(r.mat)
    surface.SetDrawColor(255, 255, 255, a or 255)
    surface.DrawTexturedRect(x - larg * (ax or 0), y, larg, haut)
    return larg
end

-- Cooldown de base affiché dans les menus (nil = pas de cooldown connu)
function NA_CooldownBase(t)
    return t and (t.cooldown or t.cd)
end

-- Cooldown affiché au niveau "niveau" de la technique (_na_niveaux.lua).
-- Technique verrouillée (niveau 0) : cooldown du niveau 1.
function NA_CooldownAuNiveau(t, niveau)
    local base = NA_CooldownBase(t)
    if not base then return nil end
    if t.id and NA_NIV and NA_NIV.Existe(t.id) then
        return NA_NIV.Valeur(t.id, "recharge", niveau, base)
    end
    return base
end

----------------------------------------------------------
-- Onglets du menu (panneau gauche)
--   icone = pastille ronde posée sur la plaque (dossier ui/main_menu/)
--   cats  = catégories de TECHNIQUES affichées dans l'onglet, une section chacune.
--   Un onglet sans cats est grisé ("Bientôt disponible").
----------------------------------------------------------
local DOSSIER = "ui/main_menu/"

local ONGLETS = {
    { nom = "Stats",         icone = "stat.png" },
    { nom = "Jutsus",        icone = "jutsu.png",       cats = { "Katon", "Suiton", "Futon", "Raiton", "Doton" },
      desc = "Cette catégorie répertorie les techniques des natures du chakra" },
    { nom = "Kekkei Genkai", icone = "kekei.png",      cats = { "Mokuton", "Jinton", "Kiminari", "Jiton" },
      desc = "Cette catégorie répertorie les techniques héritées par le sang" },
    { nom = "Clan",          icone = "clan.png",            cats = { "Salamandre", "Fuma", "Kami", "Kaguya", "Chinoike", "Hyuga", "Senju", "Uchiha" },
      desc = "Cette catégorie répertorie les techniques secrètes des clans" },
    { nom = "Arts Ninja",    icone = "kentai.png",    cats = { "Armes", "Déplacement", "Divers" },
      desc = "Cette catégorie répertorie toutes les techniques des arts ninja" },
    { nom = "Sub Jutsu",     icone = "sub.png" },
    { nom = "Jutsu Class",   icone = "classe.png" },
}

----------------------------------------------------------
-- Apparence
----------------------------------------------------------
local FOND = DOSSIER .. "fond.png"
local FOND_W, FOND_H = 1672, 941

-- Zones intérieures des panneaux, mesurées dans fond.png (x1, y1, x2, y2)
local ZONE_GAUCHE = { 81, 153, 198, 764 }
local ZONE_CENTRE = { 276, 172, 1230, 746 }
local ZONE_DROITE = { 1310, 152, 1589, 765 }

-- Plaques des onglets (en pixels de fond.png) : grandes, elles débordent à gauche
-- du fond, dans une marge ajoutée au menu (MARGE_G)
local PLAQUE_W = 280
local MARGE_G  = 120

local C_OR         = Color(232, 196, 120)
local C_CREME      = Color(240, 226, 196)
local C_DOUX       = Color(175, 155, 125)
local C_TEXTE      = Color(74, 52, 40)      -- sur le parchemin
local C_TEXTE_DOUX = Color(125, 100, 80)
local C_CHAKRA     = Color(90, 170, 255)
local C_RECHARGE   = Color(185, 110, 255)
local C_DEGATS     = Color(255, 130, 100)
local C_OK         = Color(120, 200, 110)

-- Polices recréées à l'ouverture, à la taille du menu (f = 1 pour un fond de 941 px de haut)
-- recréées seulement si la taille du menu change (CreateFont coûte cher)
local taillePolices
local function CreerPolices(f)
    f = math.max(f, 0.6)
    if taillePolices and math.abs(taillePolices - f) < 0.01 then return end
    taillePolices = f
    local function P(nom, taille, poids)
        surface.CreateFont(nom, { font = "Roboto", size = math.Round(taille * f), weight = poids, extended = true })
    end
    P("NA.Jutsu.Titre",     50, 700)
    P("NA.Jutsu.SousTitre", 18, 700)
    P("NA.Jutsu.Onglet",    17, 900)
    P("NA.Jutsu.Section",   26, 800)
    P("NA.Jutsu.Nom",       22, 800)
    P("NA.Jutsu.Texte",     17, 600)
    P("NA.Jutsu.Petit",     17, 700)
    P("NA.Jutsu.Court",     13, 700)
end

local mats = {}
local function M(chemin)
    local m = mats[chemin]
    if not m then
        m = Material(chemin, "smooth mips")
        mats[chemin] = m
    end
    return m
end

local function Image(chemin, x, y, w, h, a, lum)
    lum = lum or 255
    surface.SetMaterial(M(chemin))
    surface.SetDrawColor(lum, lum, lum, a or 255)
    surface.DrawTexturedRect(x, y, w, h)
end

local function KeyLabel(key)
    if isstring(key) then return key end
    local name = input.GetKeyName(key)
    return name and string.upper(name) or "?"
end

local function Equipable(tech)
    return tech.id ~= nil and NA_Cast ~= nil and NA_Cast[tech.id] ~= nil
        and (not NA_Debloquee or NA_Debloquee(LocalPlayer(), tech.id))
end

-- Technique à débloquer dans la bibliothèque (F6)
local function Verrouillee(tech)
    return tech.id ~= nil and NA_Debloquee ~= nil and not NA_Debloquee(LocalPlayer(), tech.id)
end

-- Coût en chakra, lu dans la description ("Coûte 25 de chakra")
local function Chakra(tech)
    return tonumber(string.match(tech.desc or "", "Coûte (%d+) de chakra")) or 0
end

-- Emplacement de la barre où se trouve une technique (ou nil)
local function EmplacementDe(id)
    if not NA_SkillBar or not id then return nil end
    for i = 1, NA_SkillBar.NB do
        if NA_SkillBar.Get(i) == id then return i end
    end
end

local function EmplacementLibre()
    if not NA_SkillBar then return nil end
    for i = 1, NA_SkillBar.NB do
        if not NA_SkillBar.Get(i) then return i end
    end
end

-- Cercle plein
local function Disque(cx, cy, r)
    local pts = {}
    for i = 0, 31 do
        local a = math.rad(i / 32 * 360)
        pts[#pts + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    draw.NoTexture()
    surface.DrawPoly(pts)
end

-- Découpe un texte en lignes qui tiennent dans une largeur
local function Couper(texte, police, largeur)
    surface.SetFont(police)
    local lignes, ligne = {}, ""
    for mot in string.gmatch(texte or "", "%S+") do
        local essai = ligne == "" and mot or (ligne .. " " .. mot)
        if ligne ~= "" and surface.GetTextSize(essai) > largeur then
            lignes[#lignes + 1] = ligne
            ligne = mot
        else
            ligne = essai
        end
    end
    if ligne ~= "" then lignes[#lignes + 1] = ligne end
    return lignes
end

-- Icône ronde d'une technique (ou son nom court) dans une case
local function DessinerCaseTechnique(tech, x, y, t, lum)
    Image(DOSSIER .. "jutsu/case_jutsu.png", x, y, t, t)
    if not tech then return end
    local icone = tech.id and NA_SkillBar and NA_SkillBar.Icone(tech.id)
    local ti = t * 0.84
    if icone then
        surface.SetMaterial(icone)
        surface.SetDrawColor(lum or 255, lum or 255, lum or 255, 255)
        surface.DrawTexturedRect(x + t / 2 - ti / 2, y + t / 2 - ti / 2, ti, ti)
    else
        surface.SetDrawColor(60, 40, 30, 40)
        Disque(x + t / 2, y + t / 2, ti / 2)
        draw.SimpleText(tech.court or tech.name, "NA.Jutsu.Court", x + t / 2, y + t / 2, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

-- Recharge restante d'une technique (vraie valeur du serveur, _na_registre.lua)
local function Recharge(id)
    return (id and NA_ResteRecharge) and NA_ResteRecharge(id) or 0
end

local function TexteRecharge(reste)
    return string.format(reste >= 1 and "%d" or "%.1f", reste)
end

-- Voile de recharge sur une case : secteur sombre qui se vide + secondes restantes
local function DessinerRecharge(id, x, y, t, police)
    local reste = Recharge(id)
    if reste <= 0 then return end
    local total = NA_DureeRecharge and NA_DureeRecharge(id) or reste
    if total <= 0 then total = reste end

    local cx, cy, r = x + t / 2, y + t / 2, t * 0.84 / 2
    local frac = math.Clamp(reste / total, 0, 1)
    local pts = { { x = cx, y = cy } }
    for i = 0, 32 do
        local a = math.rad(-90 + frac * 360 * (i / 32))
        pts[#pts + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    draw.NoTexture()
    surface.SetDrawColor(0, 0, 0, 170)
    surface.DrawPoly(pts)

    draw.SimpleTextOutlined(TexteRecharge(reste), police, cx, cy, color_white,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
end

-- Cadre sombre semi-transparent à liseré doré (liste des techniques, barre)
local function CadreSombre(w, h)
    surface.SetDrawColor(10, 6, 6, 190)
    surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, 150)
    surface.DrawOutlinedRect(0, 0, w, h, 2)
    surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, 40)
    surface.DrawOutlinedRect(4, 4, w - 8, h - 8, 1)
end

-- Petite pastille numérotée en bas à droite d'une case
-- en haut à droite (le bas à droite est pour le rang)
local function Pastille(n, w, h)
    local r = w * 0.16
    surface.SetDrawColor(90, 40, 25, 255)
    Disque(w - r, r, r)
    draw.SimpleText(n, "NA.Jutsu.Court", w - r, r, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local frame
local selection        -- technique choisie (table de TECHNIQUES)
local ongletActif = 5  -- "Arts Ninja" à la première ouverture
local filtreEquipables = false

if NA_EnregistrerMenu then
    NA_EnregistrerMenu("techniques", function() if IsValid(frame) then frame:Remove() end end)
end

local function Open()
    if IsValid(frame) then
        frame:Remove()
        return
    end
    if NA_FermerAutresMenus then NA_FermerAutresMenus("techniques") end   -- un seul menu à la fois

    selection = nil
    local survol -- technique sous la souris

    -- Taille : fond + marge des plaques à gauche, proportions gardées
    local totalW = FOND_W + MARGE_G
    local W = math.min(ScrW() * 0.92, ScrH() * 0.92 * totalW / FOND_H)
    local S = W / totalW
    local H = FOND_H * S
    local fX = MARGE_G * S   -- bord gauche du fond dans le menu
    CreerPolices(H / FOND_H)

    local function Zone(z)
        return fX + z[1] * S, z[2] * S, (z[3] - z[1]) * S, (z[4] - z[2]) * S
    end

    frame = vgui.Create("DPanel")
    frame:SetSize(W, H)
    frame:Center()
    frame:MakePopup()
    -- le clavier reste au jeu : on peut bouger (ZQSD, saut...) avec le menu ouvert
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(pan, w, h)
        Image(FOND, fX, 0, FOND_W * S, h)
    end
    -- Échap ferme le menu (sans ouvrir le menu du jeu)
    frame.Think = function(pan)
        if input.IsKeyDown(KEY_ESCAPE) then
            pan:Remove()
            gui.HideGameUI()
        end
    end

    local Rafraichir -- reconstruit le contenu de l'onglet

    ------------------------------------------------------
    -- Gauche : plaques des onglets, pastille ronde à gauche
    ------------------------------------------------------
    local gX, gY, gW, gH = Zone(ZONE_GAUCHE)
    local bW = PLAQUE_W * S
    local bH = bW * 76 / 258
    local marge = 14 * S                        -- place pour l'ombre et le décalage au survol
    local haut, bas = gY - 30 * S, gY + gH + 30 * S
    local pas = (bas - haut - bH) / (#ONGLETS - 1)
    local decalageX = 40 * S                   -- plaques un peu vers la droite

    for i, o in ipairs(ONGLETS) do
        local actif = o.cats ~= nil
        local b = vgui.Create("DButton", frame)
        b:SetText("")
        b:SetPos(decalageX, haut + (i - 1) * pas - marge / 2)
        b:SetSize(bW + marge * 2, bH + marge)
        b.Decalage = 0

        b.Paint = function(pan, w, h)
            local choisi = ongletActif == i
            local sur = actif and pan:IsHovered()
            local lum = actif and 255 or 140

            -- l'onglet choisi ou survolé glisse un peu vers la droite
            local cible = (choisi and marge or 0) + (sur and marge * 0.5 or 0)
            pan.Decalage = Lerp(FrameTime() * 12, pan.Decalage, cible)
            local x, y = 4 * S + pan.Decalage, marge / 2

            -- ombre portée : détache la plaque du cadre sombre
            Image(DOSSIER .. "btn_base_refont.png", x + 4 * S, y + 5 * S, bW, bH, 170, 0)

            local plaque = (choisi or sur) and "btn_base_refont_hover.png" or "btn_base_refont.png"
            Image(DOSSIER .. plaque, x, y, bW, bH, 255, lum)

            -- pastille sur le rond de la plaque (un peu plus grande que lui)
            local t = bH * 1.12
            Image(DOSSIER .. o.icone, x + bH / 2 - t / 2, y + bH / 2 - t / 2, t, t, 255, lum)

            -- texte : gros, contouré pour rester lisible sur la plaque
            local tx = x + bH + (bW * 0.8 - bH) / 2
            if choisi then
                draw.SimpleTextOutlined(string.upper(o.nom), "NA.Jutsu.Onglet", tx, y + bH / 2,
                    Color(70, 30, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(255, 235, 170, 120))
            else
                local col = actif and (sur and C_OR or Color(255, 245, 225)) or Color(190, 175, 155)
                draw.SimpleTextOutlined(string.upper(o.nom), "NA.Jutsu.Onglet", tx, y + bH / 2,
                    col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(20, 10, 5, 230))
            end
        end

        if actif then
            b.DoClick = function()
                if ongletActif == i then return end
                ongletActif = i
                selection = nil
                surface.PlaySound("ui/buttonclick.wav")
                Rafraichir()
            end
        else
            b:SetTooltip("Bientôt disponible")
            b.DoClick = function() surface.PlaySound("buttons/button10.wav") end
        end
    end

    ------------------------------------------------------
    -- Centre : titre, cadre des techniques, barre
    ------------------------------------------------------
    local cX, cY, cW, cH = Zone(ZONE_CENTRE)
    local px = cW * 0.05

    local centre = vgui.Create("DPanel", frame)
    centre:SetPos(cX, cY)
    centre:SetSize(cW, cH)
    centre.Paint = function(pan, w, h)
        local o = ONGLETS[ongletActif]
        draw.SimpleText(o.nom, "NA.Jutsu.Titre", px, h * 0.075, C_OR, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(string.upper(o.desc or ""), "NA.Jutsu.SousTitre", px, h * 0.155, C_CREME, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        Image(DOSSIER .. "jutsu/title_vector.png", px, h * 0.19, w - px * 2, 2)
    end

    -- croix de fermeture, sur le coin haut droit du menu
    local fermer = vgui.Create("DButton", frame)
    fermer:SetText("")
    fermer:SetSize(56 * S, 56 * S)
    fermer:SetPos(W - 62 * S, 46 * S)
    fermer.Paint = function(pan, w, h)
        local m = pan:IsHovered() and 0 or 3 * S   -- grossit un peu au survol
        Image(DOSSIER .. "btn_base_close.png", m, m, w - m * 2, h - m * 2)
    end
    fermer.DoClick = function()
        surface.PlaySound("ui/buttonclick.wav")
        frame:Remove()
    end

    -- case à cocher "Jutsu équipables", à droite du titre
    local coche = vgui.Create("DButton", centre)
    coche:SetText("")
    surface.SetFont("NA.Jutsu.SousTitre")
    local libelle = "JUTSU ÉQUIPABLES"
    local lw, lh = surface.GetTextSize(libelle)
    local tc = lh * 1.1
    coche:SetSize(tc + 8 + lw, tc)
    coche:SetPos(cW - px - coche:GetWide(), cH * 0.075 - tc / 2)
    coche.Paint = function(pan, w, h)
        Image(DOSSIER .. (filtreEquipables and "checkbox_on.png" or "checkbox_off.png"), 0, 0, h, h)
        draw.SimpleText(libelle, "NA.Jutsu.SousTitre", h + 8, h / 2,
            (filtreEquipables or pan:IsHovered()) and C_OR or C_DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    coche.DoClick = function()
        filtreEquipables = not filtreEquipables
        surface.PlaySound("ui/buttonclick.wav")
        Rafraichir()
    end

    -- cadre des techniques
    local cadreY, cadreH = cH * 0.215, cH * 0.565
    local cadre = vgui.Create("DPanel", centre)
    cadre:SetPos(px, cadreY)
    cadre:SetSize(cW - px * 2, cadreH)
    cadre.Paint = function(pan, w, h)
        CadreSombre(w, h)
    end

    local defil = vgui.Create("DScrollPanel", cadre)
    defil:Dock(FILL)
    defil:DockMargin(cW * 0.012, cH * 0.015, cW * 0.008, cH * 0.015)

    local vbar = defil:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(pan, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(232, 196, 120, 120)) end

    local tailleCase = math.floor(cW * 0.075)
    local ecart = math.floor(cW * 0.014)

    -- Une technique dans la grille
    local function CaseTechnique(parent, tech)
        local equipable = Equipable(tech) and NA_SkillBar ~= nil

        local b = parent:Add("DButton")
        b:SetText("")
        b:SetSize(tailleCase, tailleCase)
        b.Tech = tech
        if equipable then b:Droppable("NA_Jutsu") end

        b.Paint = function(pan, w, h)
            local choisie = selection == tech
            local sur = pan:IsHovered()
            if choisie then
                local p = 0.5 + 0.5 * math.sin(CurTime() * 5)
                surface.SetDrawColor(255, 190, 80, 110 + p * 100)
                Disque(w / 2, h / 2, w / 2)
            end
            local m = choisie and 3 or 0
            -- technique verrouillée : case grisée ; en recharge : assombrie
            local lum = Verrouillee(tech) and 90 or (Recharge(tech.id) > 0 and 110) or ((sur or choisie) and 255 or 215)
            DessinerCaseTechnique(tech, m, m, w - m * 2, lum)
            DessinerRecharge(tech.id, m, m, w - m * 2, "NA.Jutsu.Nom")
        end

        b.PaintOver = function(pan, w, h)
            -- rang (C, B, A, S) en bas à droite de l'icône
            local haut = h * 0.4
            NA_DessinerRang(tech, w, h - haut, haut, 1)

            local n = tech.id and EmplacementDe(tech.id)
            if n then Pastille(n, w, h) end
        end

        b.OnCursorEntered = function() survol = tech end
        b.OnCursorExited = function() if survol == tech then survol = nil end end

        b.DoClick = function()
            selection = (selection == tech) and nil or tech
            surface.PlaySound("ui/buttonclick.wav")
        end
        b.DoDoubleClick = function()
            if not equipable or EmplacementDe(tech.id) then return end
            local libre = EmplacementLibre()
            if libre then
                NA_SkillBar.Equiper(libre, tech.id)
                selection = nil
            end
        end
    end

    -- Une section : titre souligné + rangée d'icônes
    local function Section(cat)
        local liste = {}
        for _, t in ipairs(TECHNIQUES) do
            if t.cat == cat and (not filtreEquipables or Equipable(t)) then liste[#liste + 1] = t end
        end
        if #liste == 0 then return end

        local titreH = cH * 0.08
        local espace = cH * 0.03

        local sec = defil:Add("DPanel")
        sec:Dock(TOP)
        sec:DockMargin(0, 0, 0, cH * 0.035)
        sec.Paint = function(pan, w, h)
            draw.SimpleText(string.upper(cat), "NA.Jutsu.Section", 6, titreH / 2, C_OR, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            Image(DOSSIER .. "jutsu/title_vector.png", 0, titreH, w * 0.4, 2)
        end

        local grille = vgui.Create("DIconLayout", sec)
        grille:Dock(TOP)
        grille:DockMargin(6, titreH + espace, 0, 0)
        grille:SetSpaceX(ecart)
        grille:SetSpaceY(ecart)
        for _, t in ipairs(liste) do CaseTechnique(grille, t) end

        -- la hauteur suit le nombre de lignes de la grille
        sec.PerformLayout = function(pan, w, h)
            local parLigne = math.max(1, math.floor((w - 6 + ecart) / (tailleCase + ecart)))
            local lignes = math.ceil(#liste / parLigne)
            local voulu = titreH + espace + lignes * tailleCase + (lignes - 1) * ecart + 4
            if math.abs(h - voulu) > 1 then pan:SetTall(voulu) end
        end
    end

    Rafraichir = function()
        survol = nil
        defil:Clear()
        for _, cat in ipairs(ONGLETS[ongletActif].cats or {}) do
            Section(cat)
        end
        defil:GetVBar():SetScroll(0)
    end

    -- barre de techniques (cercles clairs, centrés)
    local barreY = cadreY + cadreH + cH * 0.03
    local barre = vgui.Create("DPanel", centre)
    barre:SetPos(px, barreY)
    barre:SetSize(cW - px * 2, cH - barreY - cH * 0.025)
    barre.Paint = function(pan, w, h)
        CadreSombre(w, h)
    end

    local nb = NA_SkillBar and NA_SkillBar.NB or 6
    local tSlot = barre:GetTall() * 0.72
    local eSlot = tSlot * 0.55
    local debut = barre:GetWide() / 2 - (nb * tSlot + (nb - 1) * eSlot) / 2
    for i = 1, nb do
        local slot = vgui.Create("DButton", barre)
        slot:SetText("")
        slot:SetSize(tSlot, tSlot)
        slot:SetPos(debut + (i - 1) * (tSlot + eSlot), barre:GetTall() / 2 - tSlot / 2)
        slot:SetTooltip("Emplacement " .. i .. " (touche " .. i .. ")  •  clic droit : vider")

        slot.Paint = function(pan, w, h)
            local id = NA_SkillBar and NA_SkillBar.Get(i)
            local tech = id and NA_TechniqueParId(id)
            if selection and Equipable(selection) and pan:IsHovered() then
                surface.SetDrawColor(255, 190, 80, 170)
                Disque(w / 2, h / 2, w / 2)
            end
            DessinerCaseTechnique(tech, 0, 0, w, Recharge(id) > 0 and 110 or 255)
            DessinerRecharge(id, 0, 0, w, "NA.Jutsu.Nom")
        end
        slot.PaintOver = function(pan, w, h) Pastille(i, w, h) end

        slot.OnCursorEntered = function()
            local id = NA_SkillBar and NA_SkillBar.Get(i)
            survol = id and NA_TechniqueParId(id) or nil
        end
        slot.OnCursorExited = function() survol = nil end

        slot.DoClick = function()
            if NA_SkillBar and selection and Equipable(selection) then
                NA_SkillBar.Equiper(i, selection.id)
                selection = nil
            end
        end
        slot.DoRightClick = function()
            if NA_SkillBar and NA_SkillBar.Get(i) then NA_SkillBar.Vider(i) end
        end

        slot:Receiver("NA_Jutsu", function(pan, panneaux, lache)
            if not lache or not NA_SkillBar then return end
            local t = panneaux[1] and panneaux[1].Tech
            if t and Equipable(t) then NA_SkillBar.Equiper(i, t.id) end
        end)
    end

    ------------------------------------------------------
    -- Droite : détail de la technique survolée ou choisie
    ------------------------------------------------------
    local dX, dY, dW, dH = Zone(ZONE_DROITE)
    local droite = vgui.Create("DPanel", frame)
    droite:SetPos(dX, dY)
    droite:SetSize(dW, dH)

    local cache = {}
    droite.Paint = function(pan, w, h)
        local t = survol or selection
        if not t then
            draw.SimpleText("Survole une", "NA.Jutsu.Texte", w / 2, h * 0.45, C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("technique", "NA.Jutsu.Texte", w / 2, h * 0.485, C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        -- découpage des textes gardé en mémoire pour chaque technique
        local c = cache[t]
        if not c then
            c = {
                nom  = Couper(string.upper(t.name), "NA.Jutsu.Nom", w * 0.92),
                desc = Couper(string.upper(t.desc or ""), "NA.Jutsu.Texte", w * 0.84),
            }
            cache[t] = c
        end

        -- icône ronde en haut
        local ti = math.min(w * 0.5, h * 0.2)
        local y = h * 0.035
        local icone = t.id and NA_SkillBar and NA_SkillBar.Icone(t.id)
        if icone then
            surface.SetMaterial(icone)
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(w / 2 - ti / 2, y, ti, ti)
        else
            DessinerCaseTechnique(t, w / 2 - ti / 2, y, ti)
        end
        -- rang (C, B, A, S) en bas à droite de l'icône
        NA_DessinerRang(t, w / 2 + ti / 2, y + ti * 0.6, ti * 0.4, 1)
        y = y + ti + h * 0.03

        surface.SetFont("NA.Jutsu.Nom")
        local _, hn = surface.GetTextSize("A")
        surface.SetFont("NA.Jutsu.Texte")
        local _, hd = surface.GetTextSize("A")

        -- voile sombre derrière le texte, pour le lire par-dessus le décor du fond
        local nbLignes = Recharge(t.id) > 0 and 4 or 3
        local hauteur = #c.nom * hn + h * 0.047 + #c.desc * (hd + 2) + h * 0.04 + nbLignes * (hd + 4)
        draw.RoundedBox(6, w * 0.04, y - h * 0.015, w * 0.92, hauteur + h * 0.03, Color(8, 5, 5, 175))

        -- nom
        for _, l in ipairs(c.nom) do
            draw.SimpleText(l, "NA.Jutsu.Nom", w / 2, y, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            y = y + hn
        end
        y = y + h * 0.012
        Image(DOSSIER .. "jutsu/right_vector.png", w * 0.1, y, w * 0.8, 3)
        y = y + h * 0.035

        -- description, centrée
        for _, l in ipairs(c.desc) do
            draw.SimpleText(l, "NA.Jutsu.Texte", w / 2, y, C_CREME, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            y = y + hd + 2
        end
        y = y + h * 0.04

        -- caractéristiques, centrées
        local function Ligne(texte, col)
            draw.SimpleText(texte, "NA.Jutsu.Petit", w / 2, y, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            y = y + hd + 4
        end
        Ligne("CHAKRA : " .. Chakra(t), C_CHAKRA)
        -- affiché même si la technique est verrouillée (valeur du niveau 1)
        local cd = NA_CooldownAuNiveau(t, t.id and NA_Niveau and NA_Niveau(LocalPlayer(), t.id) or 1)
        Ligne("COOLDOWN : " .. (cd and (string.format(cd == math.floor(cd) and "%d" or "%.1f", cd) .. " S") or "-"), C_RECHARGE)
        local reste = Recharge(t.id)
        if reste > 0 then
            Ligne("EN RECHARGE : " .. TexteRecharge(reste) .. " S", Color(255, 110, 90))
        end
        if Verrouillee(t) then
            -- rien : la case grisée suffit
        elseif Equipable(t) then
            local n = EmplacementDe(t.id)
            Ligne(n and ("ÉQUIPÉE : TOUCHE " .. n) or "NON ÉQUIPÉE", n and C_OK or C_DOUX)
        elseif t.key and t.key ~= "" then
            Ligne("TOUCHE : " .. string.upper(KeyLabel(t.key)), C_OR)
        end
    end

    -- option de la Prison aqueuse : case "sans bulle d'eau" (retire le modèle, garde la particule).
    -- Visible quand la technique est choisie (clic dessus). Réglage : na_prison_sans_modele (cl_suiton_prison.lua)
    local optModele = vgui.Create("DButton", droite)
    optModele:SetText("")
    surface.SetFont("NA.Jutsu.Petit")
    local libOpt = "SANS BULLE D'EAU"
    local ow, oh = surface.GetTextSize(libOpt)
    local oc = oh * 1.3
    optModele:SetSize(oc + 8 + ow, oc)
    optModele:SetPos((dW - optModele:GetWide()) / 2, dH - oc - dH * 0.03)
    optModele:SetVisible(false)
    local function SansModele()
        local cv = GetConVar("na_prison_sans_modele")
        return cv and cv:GetBool() or false
    end
    optModele.Think = function(pan)
        pan:SetVisible(selection ~= nil and selection.id == "suiton_prison")
    end
    optModele.Paint = function(pan, w, h)
        local coche = SansModele()
        Image(DOSSIER .. (coche and "checkbox_on.png" or "checkbox_off.png"), 0, 0, h, h)
        draw.SimpleText(libOpt, "NA.Jutsu.Petit", h + 8, h / 2,
            (coche or pan:IsHovered()) and C_OR or C_DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    optModele.DoClick = function()
        RunConsoleCommand("na_prison_sans_modele", SansModele() and "0" or "1")
        surface.PlaySound("ui/buttonclick.wav")
    end

    Rafraichir()
end

----------------------------------------------------------
-- Préchargement : les images (grandes) sont chargées une par une (une tous les quarts de seconde) après
-- l'arrivée en jeu, pour que la première ouverture du menu ne fige pas le jeu.
----------------------------------------------------------
hook.Add("InitPostEntity", "NA_TechniquesUI_Precharger", function()
    local liste = {
        FOND, DOSSIER .. "btn_base_refont.png", DOSSIER .. "btn_base_refont_hover.png",
        DOSSIER .. "btn_base_close.png", DOSSIER .. "checkbox_on.png", DOSSIER .. "checkbox_off.png",
        DOSSIER .. "jutsu/case_jutsu.png", DOSSIER .. "jutsu/title_vector.png", DOSSIER .. "jutsu/right_vector.png",
    }
    for _, o in ipairs(ONGLETS) do liste[#liste + 1] = DOSSIER .. o.icone end
    local ids = {}
    for _, t in ipairs(TECHNIQUES) do if t.id then ids[#ids + 1] = t.id end end

    local i = 0
    timer.Create("NA_TechniquesUI_Precharger", 0.25, #liste + #ids, function()
        i = i + 1
        if liste[i] then M(liste[i])
        elseif NA_SkillBar then NA_SkillBar.Icone(ids[i - #liste]) end
    end)
end)

concommand.Add("attaques", Open)
concommand.Add("techniques", Open)


----------------------------------------------------------
-- Touche d'ouverture
----------------------------------------------------------
local wasDown = false

hook.Add("Think", "NA_TechniquesUI_Key", function()
    -- la fenêtre ouverte capte le clavier : on laisse quand même F2 la refermer
    if (vgui.GetKeyboardFocus() and not IsValid(frame)) or gui.IsGameUIVisible() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(OPEN_KEY)
    if down and not wasDown then
        Open()
    end
    wasDown = down
end)
