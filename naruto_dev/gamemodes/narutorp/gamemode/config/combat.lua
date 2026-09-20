--[[
    Configuration : combat
]]

NRP.Config.Combat = {
    -- Dégâts entre membres d'un même village (hors duel)
    SameVillageDamage = false,
    -- Appliquer aussi les règles de village aux dégâts des armes / techniques d'autres addons
    -- (ex. les jutsu de lua/autorun de naruto_dev). false = seuls zones sûres et protection d'apparition.
    ExternalDamageVillageRules = false,
    -- Un coup donné/reçu place le joueur "en combat" pendant X s
    CombatTagDuration = 8,
    -- Temps de recharge global entre deux actions offensives (anti-spam)
    GlobalCooldown = 0.35,

    Melee = {
        Range = 72,
        HullSize = 14,
        LightDamage = { 8, 9, 13 },        -- combo 1-2-3
        LightDelay = 0.38,
        ComboWindow = 0.9,
        LightStamina = 4,
        LightKnockback = 90,
        FinisherKnockback = 320,
        FinisherStun = 0.35,
        HeavyDamage = 24,
        HeavyWindup = 0.45,
        HeavyDelay = 1.3,
        HeavyStamina = 14,
        HeavyKnockback = 480,
        HeavyGuardMultiplier = 2.5,        -- dégâts d'endurance sur la garde
        NPCDamageMultiplier = 1.5,
    },

    Block = {
        Angle = 70,                         -- demi-angle de garde (degrés)
        MeleeReduction = 0.85,
        JutsuReduction = 0.5,
        ToolReduction = 0.9,
        StaminaPerDamage = 1.2,
        MoveSpeedMultiplier = 0.45,
        ParryWindow = 0.2,
        ParryStun = 1.0,
        GuardBreakStun = 1.4,
        ReleaseCooldown = 0.3,
        MinStamina = 5,
    },

    Dodge = {
        Stamina = 18,
        Cooldown = 0.9,
        Force = 520,
        UpForce = 120,
        IFrames = 0.3,
    },

    Dash = {
        Stamina = 25,
        Cooldown = 2.5,
        Force = 900,
        UpForce = 160,
        AllowInAir = false,
    },

    Substitution = {
        Chakra = 25,
        Cooldown = 20,
        Distance = 320,
        RequireRecentHit = true,
        RecentHitWindow = 1.5,
        IFrames = 0.6,
        LogModel = "models/props_docks/dock01_pole01a_128.mdl",
        LogLifetime = 3,
    },

    -- Duels (dégâts autorisés entre deux joueurs, même village)
    Duel = {
        Duration = 180,
        MaxDistance = 1500,
        RequestTimeout = 30,
    },

    -- Zones sûres par carte : aucun dégât joueur
    SafeZones = {
        -- ["rp_konoha_v2"] = {
        --     { name = "Hôpital", min = Vector(-500, -500, 0), max = Vector(500, 500, 300) },
        -- },
    },

    -- Mannequin d'entraînement
    TrainingDummy = {
        Model = "models/props_docks/dock01_pole01a_128.mdl",
        Health = 1000000,
    },
}
