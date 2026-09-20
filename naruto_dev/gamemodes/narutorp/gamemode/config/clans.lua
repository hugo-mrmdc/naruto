--[[
    Configuration : clans

    Champs :
        name, description, color, icon
        selectable     : choisissable à la création (sinon attribué par un admin / en RP)
        villages       : villages autorisés (nil = tous)
        maxMembers     : nombre max de personnages dans ce clan (nil = illimité)
        affinity       : affinité offerte par le clan
        stats          : bonus plats de statistiques { control = 3 }
        derived        : modificateurs de valeurs dérivées { maxChakra = { mul = 0.1 } }
        passives       : { { id = "element_mastery", element = "katon", mul = 0.15 } }
                         (voir modules/clans/sh_passives.lua pour la liste)
        dojutsu        : dojutsu héréditaire (config/dojutsu.lua)
        tree           : arbre de progression, chaque nœud :
            { id, name, description, cost = points de clan, level = niveau requis,
              requires = { "noeud_parent" }, pos = { x, y } (colonne, ligne dans l'UI),
              rewards = { stats = {}, derived = {}, passives = {}, jutsu = "id",
                          dojutsuStage = { sharingan = 2 }, affinity = "katon" } }
]]

NRP.Config.ClanSettings = {
    AllowNoClan = true,
    NoClanName = "Sans clan",
    -- Changer de clan rembourse les points de clan dépensés
    RefundOnChange = true,
}

NRP.Config.Clans = {
    uchiha = {
        name = "Uchiha",
        description = "Clan légendaire maître du feu, porteur du Sharingan.",
        color = Color(200, 30, 40),
        selectable = false,
        villages = { "konoha" },
        maxMembers = 6,
        affinity = "katon",
        stats = { control = 2, ninjutsu = 3 },
        passives = { { id = "element_mastery", element = "katon", mul = 0.15 } },
        dojutsu = "sharingan",
        tree = {
            { id = "uchiha_flame", name = "Flamme des Uchiha", description = "+10% dégâts Katon.", cost = 1, level = 1, pos = { 1, 1 },
                rewards = { passives = { { id = "element_mastery", element = "katon", mul = 0.10 } } } },
            { id = "uchiha_eyes_1", name = "Éveil du Sharingan", description = "Débloque le Sharingan (1 tomoe).", cost = 1, level = 8, pos = { 2, 1 },
                rewards = { dojutsuStage = { sharingan = 1 } } },
            { id = "uchiha_eyes_2", name = "Deux tomoe", description = "Sharingan 2 tomoe.", cost = 2, level = 20, requires = { "uchiha_eyes_1" }, pos = { 2, 2 },
                rewards = { dojutsuStage = { sharingan = 2 } } },
            { id = "uchiha_eyes_3", name = "Trois tomoe", description = "Sharingan 3 tomoe.", cost = 2, level = 35, requires = { "uchiha_eyes_2" }, pos = { 2, 3 },
                rewards = { dojutsuStage = { sharingan = 3 } } },
            { id = "uchiha_chakra", name = "Réserves du clan", description = "+10% chakra maximum.", cost = 2, level = 15, requires = { "uchiha_flame" }, pos = { 1, 2 },
                rewards = { derived = { maxChakra = { mul = 0.10 } } } },
            { id = "uchiha_amaterasu", name = "Amaterasu", description = "Technique du Mangekyō (nécessite le stade 4, attribué en RP).", cost = 3, level = 50,
                requires = { "uchiha_eyes_3" }, pos = { 2, 4 }, rewards = { jutsu = "uchiha_amaterasu" } },
        },
    },

    hyuga = {
        name = "Hyūga",
        description = "Maîtres du Jūken, porteurs du Byakugan.",
        color = Color(210, 210, 240),
        selectable = true,
        villages = { "konoha" },
        maxMembers = 10,
        stats = { control = 3, taijutsu = 2 },
        passives = { { id = "gentle_fist", drain = 4 } },
        dojutsu = "byakugan",
        tree = {
            { id = "hyuga_eyes_1", name = "Byakugan", description = "Débloque le Byakugan.", cost = 1, level = 1, pos = { 1, 1 },
                rewards = { dojutsuStage = { byakugan = 1 } } },
            { id = "hyuga_eyes_2", name = "Vision étendue", description = "Byakugan : portée accrue.", cost = 2, level = 20, requires = { "hyuga_eyes_1" }, pos = { 1, 2 },
                rewards = { dojutsuStage = { byakugan = 2 } } },
            { id = "hyuga_juken", name = "Jūken avancé", description = "+15% dégâts au corps à corps.", cost = 2, level = 10, pos = { 2, 1 },
                rewards = { derived = { meleePower = { mul = 0.15 } } } },
        },
    },

    nara = {
        name = "Nara",
        description = "Stratèges manipulant les ombres.",
        color = Color(70, 90, 60),
        selectable = true,
        stats = { control = 2, genjutsu = 1 },
        derived = { castSpeed = { mul = 0.08 } },
        tree = {
            { id = "nara_mind", name = "Esprit stratège", description = "+10% vitesse d'incantation.", cost = 1, level = 5, pos = { 1, 1 },
                rewards = { derived = { castSpeed = { mul = 0.10 } } } },
            { id = "nara_shadow", name = "Ombre tenace", description = "-15% coût des jutsu.", cost = 2, level = 15, requires = { "nara_mind" }, pos = { 1, 2 },
                rewards = { derived = { jutsuCost = { mul = -0.15 } } } },
        },
    },

    akimichi = {
        name = "Akimichi",
        description = "Clan robuste qui transforme les calories en chakra.",
        color = Color(220, 120, 60),
        selectable = true,
        stats = { vitality = 4, strength = 3 },
        passives = { { id = "damage_reduction", kind = "melee", mul = 0.15 } },
        tree = {
            { id = "akimichi_body", name = "Corps massif", description = "+15% vie maximum.", cost = 1, level = 5, pos = { 1, 1 },
                rewards = { derived = { maxHealth = { mul = 0.15 } } } },
            { id = "akimichi_food", name = "Métabolisme", description = "+30% régénération d'endurance.", cost = 2, level = 12, pos = { 2, 1 },
                rewards = { derived = { staminaRegen = { mul = 0.30 } } } },
        },
    },

    yamanaka = {
        name = "Yamanaka",
        description = "Spécialistes des techniques mentales.",
        color = Color(240, 210, 90),
        selectable = true,
        stats = { genjutsu = 4 },
        derived = { genjutsuResist = { add = 0.1 } },
        tree = {
            { id = "yamanaka_mind", name = "Esprit acéré", description = "+20% puissance des genjutsu.", cost = 1, level = 5, pos = { 1, 1 },
                rewards = { derived = { genjutsuPower = { mul = 0.20 } } } },
        },
    },

    aburame = {
        name = "Aburame",
        description = "Hôtes d'insectes dévoreurs de chakra.",
        color = Color(60, 70, 60),
        selectable = true,
        stats = { control = 2, chakra = 2 },
        passives = { { id = "chakra_leech", amount = 3 } },
        tree = {
            { id = "aburame_hive", name = "Ruche", description = "+10% chakra maximum.", cost = 1, level = 5, pos = { 1, 1 },
                rewards = { derived = { maxChakra = { mul = 0.10 } } } },
        },
    },

    inuzuka = {
        name = "Inuzuka",
        description = "Combattants sauvages aux sens aiguisés.",
        color = Color(170, 60, 50),
        selectable = true,
        stats = { speed = 3, taijutsu = 2 },
        passives = { { id = "keen_senses", radius = 900 } },
        tree = {
            { id = "inuzuka_speed", name = "Instinct animal", description = "+8% vitesse de course.", cost = 1, level = 5, pos = { 1, 1 },
                rewards = { derived = { runSpeed = { mul = 0.08 } } } },
        },
    },
}
