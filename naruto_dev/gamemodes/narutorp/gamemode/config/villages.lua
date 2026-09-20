--[[
    Configuration : villages, relations, réputation, déserteurs, primes

    Les points d'apparition sont placés en jeu :  !spawn add <village>
]]

NRP.Config.Villages = {
    konoha = {
        name = "Konoha", fullName = "Konohagakure no Sato", country = "Pays du Feu",
        kage = "Hokage", color = Color(90, 170, 80), order = 1, selectable = true,
    },
    suna = {
        name = "Suna", fullName = "Sunagakure no Sato", country = "Pays du Vent",
        kage = "Kazekage", color = Color(215, 175, 90), order = 2, selectable = true,
    },
    kiri = {
        name = "Kiri", fullName = "Kirigakure no Sato", country = "Pays de l'Eau",
        kage = "Mizukage", color = Color(90, 150, 210), order = 3, selectable = true,
    },
    kumo = {
        name = "Kumo", fullName = "Kumogakure no Sato", country = "Pays de la Foudre",
        kage = "Raikage", color = Color(230, 220, 120), order = 4, selectable = true,
    },
    iwa = {
        name = "Iwa", fullName = "Iwagakure no Sato", country = "Pays de la Terre",
        kage = "Tsuchikage", color = Color(160, 120, 90), order = 5, selectable = true,
    },
    -- Pseudo-village des déserteurs (non sélectionnable)
    nukenin = {
        name = "Nukenin", fullName = "Ninja déserteur", country = "Aucun",
        kage = "Aucun", color = Color(150, 60, 60), order = 99, selectable = false, deserter = true,
    },
}

NRP.Config.VillageSettings = {
    -- Statuts de relation possibles
    RelationTypes = {
        ally = { name = "Alliance", color = Color(90, 200, 110), canHarm = false, order = 1 },
        neutral = { name = "Neutre", color = Color(200, 200, 200), canHarm = true, order = 2 },
        tension = { name = "Tensions", color = Color(250, 180, 50), canHarm = true, order = 3 },
        war = { name = "Guerre", color = Color(230, 60, 60), canHarm = true, order = 4 },
    },
    DefaultRelation = "neutral",
    -- Relations au premier lancement (ensuite stockées en base)
    InitialRelations = {
        { "konoha", "suna", "ally" },
        { "kumo", "iwa", "tension" },
    },

    Reputation = {
        Min = -1000,
        Max = 1000,
        KillSameVillage = -40,
        KillAlly = -25,
        KillAtWar = 10,
        KillDeserter = 15,
        Titles = {
            { min = -1000, name = "Traître" },
            { min = -200, name = "Suspect" },
            { min = 0, name = "Neutre" },
            { min = 100, name = "Respecté" },
            { min = 300, name = "Honoré" },
            { min = 600, name = "Héros du village" },
        },
    },

    Deserters = {
        AllowSelfDesert = true,       -- commande !deserter (avec confirmation)
        AutoBounty = 3000,            -- prime automatique du village d'origine
        MinLevel = 10,
    },

    Bounty = {
        PlayerCanPlace = true,
        MinAmount = 500,
        MaxAmount = 1000000,
        TaxPercent = 10,
        ExpireDays = 14,
        ClaimSameVillage = false,     -- un membre du village de la cible peut-il encaisser ?
        MaxActivePerIssuer = 3,
    },
}
