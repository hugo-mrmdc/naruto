--[[
    Configuration générale (partagée client/serveur)
    Ne mettez JAMAIS d'identifiants ici : ce fichier est envoyé aux clients.
    -> Base de données : config/sv_database.lua
]]

NRP.Config.General = {
    ServerName = "Naruto RP",

    -- Armes données à chaque apparition (la première est sélectionnée)
    DefaultWeapons = { "nrp_hands" },
    -- Physgun + toolgun pour les joueurs ayant la permission admin.sandbox
    AdminTools = true,

    DefaultModel = "models/player/group01/male_07.mdl",
    RespawnDelay = 6,
    FallDamageMultiplier = 0.6,

    -- Portée du chat vocal (0 = global)
    VoiceRange = 900,

    -- ply:Nick() renvoie le nom RP du personnage (SteamName() garde le pseudo Steam)
    OverrideNick = true,

    -- Temps de protection après apparition (secondes)
    SpawnProtection = 5,

    -- Addons workshop à faire télécharger (ids)
    Workshop = {},

    -- Couleurs de l'interface
    Theme = {
        Background = Color(18, 18, 22, 235),
        Panel = Color(30, 30, 36, 240),
        PanelLight = Color(44, 44, 52, 240),
        Accent = Color(255, 128, 32),
        AccentDark = Color(190, 90, 20),
        Text = Color(235, 235, 235),
        TextDim = Color(150, 150, 160),
        Health = Color(210, 50, 60),
        Chakra = Color(60, 140, 255),
        Stamina = Color(80, 200, 110),
        XP = Color(250, 200, 60),
        Ryo = Color(240, 210, 90),
        Success = Color(80, 200, 110),
        Error = Color(230, 70, 70),
        Warning = Color(250, 180, 50),
    },
}

-- Anti-abus réseau
NRP.Config.Net = {
    KickThreshold = 60,          -- nombre de requêtes rejetées avant expulsion
    FlagDecay = 10,              -- signalements retirés chaque minute
    KickMessage = "Trop de requêtes réseau (anti-spam Naruto RP)",
}

--[[
    Permissions par usergroup (utilisé si CAMI/ULX ne gère pas la permission).
    "*" = tout, "admin.*" = toutes les permissions admin.
    Les grades ninja peuvent aussi donner des permissions (config/progression.lua).
]]
NRP.Config.Permissions = {
    Groups = {
        superadmin = { permissions = { ["*"] = true } },
        admin = {
            inherits = "moderator",
            permissions = {
                ["admin.*"] = true,
                ["admin.character"] = false,
                ["admin.physgunplayers"] = false,
                ["rp.*"] = true,
            },
        },
        moderator = {
            inherits = "rp_manager",
            permissions = {
                ["admin.menu"] = true,
                ["admin.inspect"] = true,
                ["admin.noclip"] = true,
            },
        },
        -- Responsables RP : examens, promotions, événements
        rp_manager = {
            permissions = {
                ["admin.menu"] = true,
                ["rp.promote"] = true,
                ["rp.exam"] = true,
                ["rp.event"] = true,
            },
        },
        user = { permissions = {} },
    },
}
