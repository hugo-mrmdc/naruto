--[[
    Configuration : objets et inventaire

    Champs d'un objet :
        name, description, icon, model, category, rarity, weight (kg), stack (quantité max transportable), price
        tradeable (défaut true), droppable (défaut true), missionItem (objet de mission : non échangeable)
        use      = { heal, chakra, stamina, cure = { "burn" }, regen = { amount, duration },
                     buff = { duration, modifiers }, cooldown, consume (défaut true) }
        learnJutsu = "id"   -- parchemin d'apprentissage
        equip    = { slot = "tool" | "armor" | "accessory", modifiers = { ... } }
        throw    = { damage, speed, gravity, radius, count, spread, cooldown, knockback, effects, fx }
]]

NRP.Config.InventorySettings = {
    MaxStacks = 40,              -- nombre de types d'objets différents
    OverweightSlow = -0.4,       -- modificateur de vitesse en surpoids
    DropLifetime = 300,
    MaxDropsPerPlayer = 6,
    PickupDistance = 120,
    UseCooldown = 0.8,

    TradeDistance = 300,
    TradeRequestTimeout = 30,
    TradeMaxItems = 12,

    Rarities = {
        common = { name = "Commun", color = Color(200, 200, 200), order = 1 },
        uncommon = { name = "Peu commun", color = Color(90, 210, 110), order = 2 },
        rare = { name = "Rare", color = Color(80, 150, 255), order = 3 },
        epic = { name = "Épique", color = Color(180, 90, 240), order = 4 },
        legendary = { name = "Légendaire", color = Color(255, 160, 40), order = 5 },
    },

    Categories = {
        tool = { name = "Outils ninja", order = 1 },
        scroll = { name = "Parchemins", order = 2 },
        food = { name = "Nourriture", order = 3 },
        medicine = { name = "Médicaments", order = 4 },
        equipment = { name = "Équipement", order = 5 },
        mission = { name = "Objets de mission", order = 6 },
        misc = { name = "Divers", order = 7 },
    },

    EquipSlots = {
        tool = { name = "Outil (lancer)", order = 1 },
        armor = { name = "Tenue", order = 2 },
        accessory = { name = "Accessoire", order = 3 },
    },
}

-- Boutiques (PNJ nrp_shop_npc, choisies avec !shopnpc <id>)
NRP.Config.Shops = {
    general = {
        name = "Marchand d'équipement",
        sellRatio = 0.4,   -- revente : 40 % du prix
        items = { "kunai", "shuriken", "explosive_kunai", "onigiri", "ramen", "medical_kit", "antidote", "flak_jacket" },
    },
    library = {
        name = "Bibliothèque ninja",
        items = { "scroll_water_dragon", "scroll_chidori", "scroll_first_gate", "scroll_heal", "soldier_pill", "chakra_band" },
    },
}

NRP.Config.Items = {
    ---------------------------------------------------------------- OUTILS
    kunai = {
        name = "Kunai",
        description = "Couteau de lancer polyvalent. Équipez-le puis utilisez la touche de lancer.",
        category = "tool", rarity = "common", weight = 0.3, stack = 30, price = 15,
        model = "models/weapons/w_knife_t.mdl",
        equip = { slot = "tool" },
        throw = { damage = 16, speed = 2600, gravity = 250, radius = 6, cooldown = 0.6, knockback = 40, fx = "kunai" },
    },
    shuriken = {
        name = "Shuriken",
        description = "Étoiles de lancer : trois projectiles en éventail.",
        category = "tool", rarity = "common", weight = 0.1, stack = 60, price = 8,
        equip = { slot = "tool" },
        throw = { damage = 7, speed = 2800, gravity = 150, radius = 5, count = 3, spread = 5, cooldown = 0.8, fx = "shuriken" },
    },
    explosive_kunai = {
        name = "Kunai explosif",
        description = "Un kunai muni d'un parchemin explosif.",
        category = "tool", rarity = "uncommon", weight = 0.4, stack = 10, price = 80,
        equip = { slot = "tool" },
        throw = { damage = 30, speed = 2200, gravity = 300, radius = 6, cooldown = 1.5, knockback = 300,
            explosion = { radius = 160, falloff = 0.5 }, fx = "kunai" },
    },

    ---------------------------------------------------------------- PARCHEMINS
    scroll_water_dragon = {
        name = "Parchemin : Suiryūdan",
        description = "Enseigne le Suiton : Suiryūdan no Jutsu (conditions requises).",
        category = "scroll", rarity = "rare", weight = 0.2, stack = 1, price = 4000,
        learnJutsu = "suiton_water_dragon",
    },
    scroll_chidori = {
        name = "Parchemin : Chidori",
        description = "Enseigne le Raiton : Chidori (conditions requises).",
        category = "scroll", rarity = "epic", weight = 0.2, stack = 1, price = 6000,
        learnJutsu = "raiton_chidori",
    },
    scroll_first_gate = {
        name = "Parchemin : Hachimon",
        description = "Enseigne la Porte de l'Ouverture (conditions requises).",
        category = "scroll", rarity = "epic", weight = 0.2, stack = 1, price = 5000,
        learnJutsu = "tai_first_gate",
    },
    scroll_heal = {
        name = "Parchemin : Shōsen",
        description = "Enseigne la technique médicale Shōsen Jutsu.",
        category = "scroll", rarity = "rare", weight = 0.2, stack = 1, price = 3000,
        learnJutsu = "special_heal",
    },

    ---------------------------------------------------------------- NOURRITURE
    onigiri = {
        name = "Onigiri",
        description = "Boule de riz. Restaure un peu de vie et d'endurance.",
        category = "food", rarity = "common", weight = 0.2, stack = 20, price = 10,
        use = { heal = 15, stamina = 40, cooldown = 8 },
    },
    ramen = {
        name = "Ramen Ichiraku",
        description = "Un bol réconfortant qui régénère la vie pendant 10 secondes.",
        category = "food", rarity = "uncommon", weight = 0.5, stack = 5, price = 40,
        use = { regen = { amount = 60, duration = 10 }, cooldown = 30 },
    },

    ---------------------------------------------------------------- MÉDICAMENTS
    soldier_pill = {
        name = "Pilule du soldat",
        description = "Restaure une grande quantité de chakra.",
        category = "medicine", rarity = "rare", weight = 0.05, stack = 5, price = 250,
        use = { chakra = 80, cooldown = 45 },
    },
    medical_kit = {
        name = "Trousse de soins",
        description = "Soigne 50 points de vie et les saignements.",
        category = "medicine", rarity = "uncommon", weight = 0.8, stack = 5, price = 120,
        use = { heal = 50, cure = { "bleed" }, cooldown = 20 },
    },
    antidote = {
        name = "Antidote",
        description = "Soigne les poisons et les brûlures.",
        category = "medicine", rarity = "uncommon", weight = 0.1, stack = 10, price = 60,
        use = { cure = { "poison", "burn" }, cooldown = 5 },
    },
    military_pill = {
        name = "Pilule de combat",
        description = "Augmente la puissance des ninjutsu pendant 30 secondes.",
        category = "medicine", rarity = "epic", weight = 0.05, stack = 3, price = 800,
        use = { buff = { duration = 30, modifiers = { jutsuPower = { mul = 0.15 } } }, cooldown = 120 },
    },

    ---------------------------------------------------------------- ÉQUIPEMENT
    flak_jacket = {
        name = "Gilet de Chūnin",
        description = "Protection standard : +30 vie, légère perte de vitesse.",
        category = "equipment", rarity = "uncommon", weight = 4, stack = 1, price = 900,
        equip = { slot = "armor", modifiers = { maxHealth = { add = 30 }, runSpeed = { mul = -0.03 } } },
    },
    anbu_armor = {
        name = "Armure ANBU",
        description = "Armure légère des forces spéciales.",
        category = "equipment", rarity = "epic", weight = 3, stack = 1, price = 5000,
        equip = { slot = "armor", modifiers = { maxHealth = { add = 20 }, damageReduction = { add = 0.08 }, runSpeed = { mul = 0.04 } } },
    },
    training_weights = {
        name = "Poids d'entraînement",
        description = "Ralentit, mais augmente l'XP gagnée de 10%.",
        category = "equipment", rarity = "rare", weight = 8, stack = 1, price = 1500,
        equip = { slot = "accessory", modifiers = { runSpeed = { mul = -0.12 }, walkSpeed = { mul = -0.1 }, xpMultiplier = { mul = 0.10 } } },
    },
    chakra_band = {
        name = "Bracelet de chakra",
        description = "+10% régénération de chakra.",
        category = "equipment", rarity = "rare", weight = 0.2, stack = 1, price = 2000,
        equip = { slot = "accessory", modifiers = { chakraRegen = { mul = 0.10 } } },
    },

    ---------------------------------------------------------------- MISSIONS
    mission_scroll = {
        name = "Parchemin scellé",
        description = "Document confidentiel à livrer. Ne l'ouvrez pas.",
        category = "mission", rarity = "common", weight = 0.1, stack = 5,
        missionItem = true,
    },
    mission_package = {
        name = "Colis récupéré",
        description = "Objet à rapporter au donneur de mission.",
        category = "mission", rarity = "uncommon", weight = 1, stack = 5,
        missionItem = true,
    },
}
