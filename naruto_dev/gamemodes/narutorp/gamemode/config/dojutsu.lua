--[[
    Configuration : Dojutsu (pouvoirs oculaires)

    Champs :
        name, clan (restriction éventuelle)
        activationCost, cooldown, sounds = { on, off }
        eye = { color, material, size, offset = { right, forward, up } }  -- rendu des yeux
        stages = {
            {
                name, description,
                unlock      : "level" (automatique au niveau `level`) | "tree" | "admin"
                level       : niveau requis
                drain       : chakra consommé par seconde
                modifiers   : { stat_ou_derivee = { add, mul } }
                jutsus      : jutsu appris en débloquant ce stade
                hud         : { tint = Color, vision = "xray" | "track", radius = unités }
            },
        }
]]

NRP.Config.DojutsuSettings = {
    DeactivateOnStun = false,
    EyeDrawDistance = 1500,
    VisionMaxTargets = 12,
}

NRP.Config.Dojutsu = {
    sharingan = {
        name = "Sharingan",
        clan = "uchiha",
        activationCost = 10,
        cooldown = 4,
        sounds = { on = "naruto_sound/jutsu/uchiha/uchiha2.wav" },
        eye = { color = Color(230, 20, 30), size = 1.6 },
        stages = {
            { name = "Sharingan - 1 tomoe", unlock = "tree", level = 8, drain = 1.2,
                modifiers = { castSpeed = { mul = 0.05 } },
                hud = { tint = Color(255, 40, 40, 30), vision = "track", radius = 800 } },
            { name = "Sharingan - 2 tomoe", unlock = "tree", level = 20, drain = 1.6,
                modifiers = { castSpeed = { mul = 0.10 }, genjutsuResist = { add = 0.1 } },
                hud = { tint = Color(255, 40, 40, 35), vision = "track", radius = 1100 } },
            { name = "Sharingan - 3 tomoe", unlock = "tree", level = 35, drain = 2.0,
                modifiers = { castSpeed = { mul = 0.15 }, genjutsuResist = { add = 0.2 }, genjutsuPower = { mul = 0.2 } },
                hud = { tint = Color(255, 30, 30, 40), vision = "track", radius = 1400 } },
            { name = "Mangekyō Sharingan", unlock = "admin", level = 50, drain = 6,
                modifiers = { castSpeed = { mul = 0.25 }, jutsuPower = { mul = 0.2 }, genjutsuResist = { add = 0.35 } },
                hud = { tint = Color(200, 0, 0, 55), vision = "track", radius = 1800 } },
        },
    },

    byakugan = {
        name = "Byakugan",
        clan = "hyuga",
        activationCost = 8,
        cooldown = 3,
        sounds = { on = "naruto_sound/jutsu/hyuga/hyuga3.wav" },
        eye = { color = Color(235, 235, 255), size = 1.4 },
        stages = {
            { name = "Byakugan", unlock = "tree", level = 1, drain = 1.0,
                modifiers = { meleePower = { mul = 0.1 } },
                hud = { tint = Color(200, 200, 255, 30), vision = "xray", radius = 1200 } },
            { name = "Byakugan éveillé", unlock = "tree", level = 20, drain = 1.3,
                modifiers = { meleePower = { mul = 0.2 }, castSpeed = { mul = 0.05 } },
                hud = { tint = Color(200, 200, 255, 35), vision = "xray", radius = 2200 } },
        },
    },
}
