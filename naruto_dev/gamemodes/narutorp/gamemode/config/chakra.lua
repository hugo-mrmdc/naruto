--[[
    Configuration : chakra et endurance
]]

NRP.Config.Chakra = {
    -- Délai avant reprise de la régénération après une dépense (secondes)
    RegenDelay = 1.5,
    StaminaRegenDelay = 1.0,

    -- Concentration du chakra (touche maintenue)
    Focus = {
        RegenMultiplier = 4,       -- régénération x4
        MinChakraMissing = 1,      -- inutile de se concentrer si plein
        CombatLock = 4,            -- impossible dans les X s suivant un coup donné/reçu
        BreakOnDamage = true,
        Freeze = true,             -- immobilise le joueur pendant la concentration
    },

    -- Épuisement : chakra à 0 -> ralentissement
    Exhaustion = {
        Enabled = true,
        SpeedMultiplier = -0.35,   -- modificateur de vitesse (mul)
        Duration = 4,
    },
}
