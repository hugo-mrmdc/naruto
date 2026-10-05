--[[
    Configuration : Jutsu

    Équilibrage : modifiez uniquement les valeurs ci-dessous. Le comportement est fourni
    par l'"archetype" (modules/jutsu/archetypes). Pour un comportement totalement nouveau,
    créez un archetype ou ajoutez OnCast = function(ply, jutsu, ctx) ... end.

    Champs disponibles :
        name, description, icon (chemin material), category, element
        archetype      : projectile | aoe | cone | wall | dash_strike | strike | buff | heal
                         | genjutsu | bind | teleport
        chakra         : coût de base (modifié par la maîtrise du chakra)
        cooldown       : secondes
        castTime       : temps d'incantation (mudras), divisé par la vitesse d'incantation
        damage, range, speed, radius, knockback, knockup, stun
        count, spread  : projectiles multiples
        explosion      : { radius = , falloff = 0..1 }
        effects        : { { status = "burn", duration = 4, dps = 5 }, ... }
        duration       : durée (buff, bind, zone persistante)
        modifiers      : buff -> { stat = { add = , mul = } }
        animation      : { gesture = ACT_xxx } ou { sequence = "nom_sequence" } (lancement)
        castAnimation  : idem, pendant l'incantation
        sounds         : { cast = , fire = , impact = }
        fx, color      : visuel côté client (voir modules/jutsu/cl_fx.lua)
        particles      : { travel = "systeme_pcf", impact = "systeme_pcf" } (optionnel)
        requirements   : { level, rank, affinity, clan, stats = {}, dojutsu = { id, stage, active } }
        unlock         : "auto" (au niveau requis) | "scroll" | "tree" | "admin"
        rootWhileCasting (défaut true), interruptible (défaut true)
]]

NRP.Config.JutsuCategories = {
    katon = { name = "Katon", color = Color(255, 110, 40), order = 1 },
    suiton = { name = "Suiton", color = Color(60, 150, 255), order = 2 },
    raiton = { name = "Raiton", color = Color(170, 200, 255), order = 3 },
    doton = { name = "Doton", color = Color(170, 120, 70), order = 4 },
    fuuton = { name = "Fuuton", color = Color(150, 230, 170), order = 5 },
    taijutsu = { name = "Taijutsu", color = Color(230, 80, 80), order = 6 },
    genjutsu = { name = "Genjutsu", color = Color(190, 90, 220), order = 7 },
    clan = { name = "Techniques de clan", color = Color(250, 200, 60), order = 8 },
    special = { name = "Techniques spéciales", color = Color(200, 200, 200), order = 9 },
}

NRP.Config.JutsuSettings = {
    LoadoutSlots = 6,
    -- Part du chakra consommée si l'incantation est interrompue
    InterruptChakraRatio = 0.5,
    -- Nombre max de murs de terre par joueur
    MaxWallsPerPlayer = 2,
    -- Délai max entre deux notifications d'échec (anti-spam visuel)
    FailNotifyInterval = 0.8,
}

local SEALS = { gesture = ACT_GMOD_GESTURE_BECON }
local THROW = { gesture = ACT_GMOD_GESTURE_ITEM_THROW }
local PUNCH = { gesture = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST }
local PLACE = { gesture = ACT_GMOD_GESTURE_ITEM_PLACE }

NRP.Config.Jutsu = {
    ---------------------------------------------------------------- KATON
    katon_fireball = {
        name = "Katon : Gōkakyū no Jutsu",
        description = "Une grande boule de feu qui explose à l'impact et enflamme la cible.",
        category = "katon", element = "katon", archetype = "projectile",
        chakra = 25, cooldown = 7, castTime = 0.6,
        damage = 38, speed = 1300, range = 1800, radius = 28,
        explosion = { radius = 170, falloff = 0.5 },
        knockback = 260,
        effects = { { status = "burn", duration = 4, dps = 4 } },
        castAnimation = SEALS, animation = THROW,
        sounds = { fire = "geams/solve_jutsu/katon/solve_katon_arena_start.wav", impact = "geams/solve_jutsu/katon/solve_katon_fireball_02.wav" },
        fx = "fireball", color = Color(255, 120, 30),
        requirements = { level = 3, affinity = "katon" },
        unlock = "auto",
    },
    katon_phoenix = {
        name = "Katon : Hōsenka no Jutsu",
        description = "Plusieurs petites boules de feu tirées en éventail.",
        category = "katon", element = "katon", archetype = "projectile",
        chakra = 30, cooldown = 9, castTime = 0.5,
        damage = 12, speed = 1600, range = 1500, radius = 14, count = 5, spread = 7,
        knockback = 60,
        effects = { { status = "burn", duration = 2, dps = 3 } },
        castAnimation = SEALS, animation = THROW,
        sounds = { fire = "geams/solve_jutsu/katon/solve_katon_arena_start.wav" },
        fx = "fireball_small", color = Color(255, 150, 50),
        requirements = { level = 10, rank = "genin", affinity = "katon", stats = { ninjutsu = 5 } },
        unlock = "auto",
    },

    ---------------------------------------------------------------- SUITON
    suiton_water_bullet = {
        name = "Suiton : Teppōdama",
        description = "Un projectile d'eau compressée qui repousse violemment.",
        category = "suiton", element = "suiton", archetype = "projectile",
        chakra = 18, cooldown = 4, castTime = 0.35,
        damage = 22, speed = 1900, range = 1800, radius = 18,
        knockback = 420,
        effects = { { status = "slow", duration = 1.5, amount = 0.25 } },
        castAnimation = SEALS, animation = THROW,
        sounds = { fire = "naruto_sound/jutsu/senju/senju4.wav", impact = "naruto_sound/jutsu/senju/senju1.wav" },
        fx = "water", color = Color(70, 160, 255),
        requirements = { level = 3, affinity = "suiton" },
        unlock = "auto",
    },
    suiton_water_dragon = {
        name = "Suiton : Suiryūdan no Jutsu",
        description = "Un dragon aqueux lent mais dévastateur qui balaie tout sur son passage.",
        category = "suiton", element = "suiton", archetype = "projectile",
        chakra = 55, cooldown = 18, castTime = 1.4,
        damage = 60, speed = 900, range = 2200, radius = 48, pierce = true,
        explosion = { radius = 200, falloff = 0.3 },
        knockback = 700, knockup = 250,
        castAnimation = SEALS, animation = PLACE,
        sounds = { cast = "naruto_sound/jutsu/senju/senju2.wav", impact = "naruto_sound/jutsu/senju/senju3.wav" },
        fx = "water_dragon", color = Color(40, 120, 255),
        requirements = { level = 25, rank = "chunin", affinity = "suiton", stats = { ninjutsu = 15 } },
        unlock = "scroll",
    },

    ---------------------------------------------------------------- RAITON
    raiton_flash = {
        name = "Raiton : Raikō Senkō",
        description = "Une ruée électrique fulgurante qui paralyse les ennemis traversés.",
        category = "raiton", element = "raiton", archetype = "dash_strike",
        chakra = 22, cooldown = 8, castTime = 0.2,
        damage = 20, range = 520, radius = 36,
        stun = 0.8, knockback = 150,
        animation = PUNCH,
        sounds = { fire = "naruto_sound/jutsu/raiton/raiton3.wav", impact = "naruto_sound/jutsu/raiton/raiton4.wav" },
        fx = "lightning", color = Color(170, 210, 255),
        requirements = { level = 3, affinity = "raiton" },
        unlock = "auto",
    },
    raiton_chidori = {
        name = "Raiton : Chidori",
        description = "Une concentration de foudre dans la main pour une frappe perforante.",
        category = "raiton", element = "raiton", archetype = "dash_strike",
        chakra = 45, cooldown = 16, castTime = 1.0,
        damage = 65, range = 650, radius = 30,
        stun = 1.2, knockback = 500,
        castAnimation = SEALS, animation = PUNCH,
        sounds = { cast = "naruto_sound/jutsu/raiton/raiton5.wav", fire = "naruto_sound/jutsu/raiton/raiton12.wav" },
        fx = "lightning", color = Color(120, 180, 255),
        requirements = { level = 25, rank = "chunin", affinity = "raiton", stats = { ninjutsu = 10, control = 10 } },
        unlock = "scroll",
    },

    ---------------------------------------------------------------- DOTON
    doton_wall = {
        name = "Doton : Doryūheki",
        description = "Élève un mur de terre défensif qui bloque les projectiles.",
        category = "doton", element = "doton", archetype = "wall",
        chakra = 30, cooldown = 14, castTime = 0.5,
        range = 140, duration = 12, health = 400,
        model = "models/props_wasteland/rockcliff01b.mdl",
        castAnimation = SEALS, animation = PLACE,
        sounds = { fire = "naruto_sound/jutsu/doton/earth16.wav" },
        fx = "earth", color = Color(150, 110, 70),
        requirements = { level = 3, affinity = "doton" },
        unlock = "auto",
    },
    doton_spikes = {
        name = "Doton : Pics de terre",
        description = "Des pointes rocheuses jaillissent à l'endroit visé.",
        category = "doton", element = "doton", archetype = "aoe",
        chakra = 32, cooldown = 10, castTime = 0.7,
        damage = 34, range = 900, radius = 150, delay = 0.5,
        knockup = 380, stun = 0.6,
        castAnimation = SEALS, animation = PLACE,
        sounds = { impact = "naruto_sound/jutsu/doton/earth17.wav" },
        fx = "earth", color = Color(150, 110, 70),
        requirements = { level = 12, rank = "genin", affinity = "doton" },
        unlock = "auto",
    },

    ---------------------------------------------------------------- FUUTON
    fuuton_blade = {
        name = "Fuuton : Shinkūha",
        description = "Une lame de vent tranchante qui traverse ses cibles.",
        category = "fuuton", element = "fuuton", archetype = "projectile",
        chakra = 20, cooldown = 5, castTime = 0.3,
        damage = 24, speed = 2600, range = 1600, radius = 22, pierce = true,
        knockback = 120,
        effects = { { status = "bleed", duration = 3, dps = 3 } },
        castAnimation = SEALS, animation = THROW,
        sounds = { fire = "naruto_sound/jutsu/futon/futon4.wav" },
        fx = "wind", color = Color(170, 240, 190),
        requirements = { level = 3, affinity = "fuuton" },
        unlock = "auto",
    },
    fuuton_gale = {
        name = "Fuuton : Daitoppa",
        description = "Une bourrasque qui projette tout ce qui se trouve devant vous.",
        category = "fuuton", element = "fuuton", archetype = "cone",
        chakra = 28, cooldown = 11, castTime = 0.6,
        damage = 18, range = 520, angle = 35,
        knockback = 950, knockup = 180,
        castAnimation = SEALS, animation = PLACE,
        sounds = { fire = "naruto_sound/jutsu/futon/futon1.wav" },
        fx = "wind", color = Color(170, 240, 190),
        requirements = { level = 14, rank = "genin", affinity = "fuuton" },
        unlock = "auto",
    },

    ---------------------------------------------------------------- TAIJUTSU
    tai_senpu = {
        name = "Konoha Senpū",
        description = "Un coup de pied circulaire puissant qui repousse les adversaires proches.",
        category = "taijutsu", archetype = "strike",
        chakra = 8, cooldown = 6, castTime = 0,
        damage = 26, range = 110, angle = 70, scaling = "melee",
        knockback = 450, stun = 0.4,
        animation = { gesture = ACT_GMOD_GESTURE_MELEE_SHOVE_1HAND },
        sounds = { fire = "naruto_sound/jutsu/uchiha/uchiha7.wav", impact = "naruto_sound/jutsu/uchiha/uchiha8.wav" },
        fx = "impact", color = Color(255, 255, 255),
        requirements = { level = 2, stats = { taijutsu = 2 } },
        unlock = "auto",
    },
    tai_first_gate = {
        name = "Hachimon : Porte de l'Ouverture",
        description = "Libère les limites du corps : vitesse et force accrues, mais la vie s'épuise.",
        category = "taijutsu", archetype = "buff",
        chakra = 20, cooldown = 45, castTime = 0.8, duration = 15,
        modifiers = {
            meleePower = { mul = 0.35 },
            runSpeed = { mul = 0.25 },
            walkSpeed = { mul = 0.2 },
            staminaRegen = { mul = 0.5 },
        },
        healthDrain = 2,
        castAnimation = { gesture = ACT_GMOD_TAUNT_MUSCLE },
        sounds = { cast = "naruto_sound/jutsu/uchiha/uchiha9.wav" },
        fx = "aura", color = Color(90, 255, 120),
        requirements = { level = 20, rank = "chunin", stats = { taijutsu = 20, vitality = 10 } },
        unlock = "scroll",
    },

    ---------------------------------------------------------------- GENJUTSU
    gen_demonic_illusion = {
        name = "Magen : Narakumi no Jutsu",
        description = "Plonge la cible dans une illusion terrifiante qui la ralentit et la désoriente.",
        category = "genjutsu", archetype = "genjutsu",
        chakra = 25, cooldown = 14, castTime = 0.8,
        range = 900, duration = 4, scaling = "genjutsu",
        effects = { { status = "genjutsu", duration = 4 }, { status = "slow", duration = 4, amount = 0.4 } },
        castAnimation = SEALS,
        sounds = { cast = "naruto_sound/jutsu/mugen/1-01.wav" },
        fx = "genjutsu", color = Color(190, 90, 220),
        requirements = { level = 6, stats = { genjutsu = 5 } },
        unlock = "auto",
    },

    ---------------------------------------------------------------- SPÉCIAL
    special_shunshin = {
        name = "Shunshin no Jutsu",
        description = "Déplacement instantané dans un nuage de fumée.",
        category = "special", archetype = "teleport",
        chakra = 15, cooldown = 10, castTime = 0.15,
        range = 600,
        castAnimation = SEALS,
        sounds = { fire = "naruto_sound/jutsu/futon/futon5.wav" },
        fx = "smoke", color = Color(220, 220, 220),
        requirements = { level = 8, rank = "genin", stats = { control = 5 } },
        unlock = "auto",
    },
    special_heal = {
        name = "Shōsen Jutsu",
        description = "Technique médicale : soigne la cible visée (ou vous-même).",
        category = "special", archetype = "heal",
        chakra = 30, cooldown = 12, castTime = 1.2,
        heal = 40, range = 120, scaling = "control",
        castAnimation = SEALS,
        sounds = { fire = "naruto_sound/jutsu/futon/futon6.wav" },
        fx = "heal", color = Color(90, 255, 140),
        requirements = { level = 10, stats = { control = 12 } },
        unlock = "scroll",
    },

    ---------------------------------------------------------------- CLANS
    nara_shadow_bind = {
        name = "Kagemane no Jutsu",
        description = "Votre ombre capture la cible et l'immobilise tant que vous maintenez la technique.",
        category = "clan", archetype = "bind",
        chakra = 30, cooldown = 20, castTime = 0.6,
        range = 700, duration = 5, drain = 6,
        castAnimation = SEALS,
        sounds = { cast = "naruto_sound/jutsu/mugen/1-02.wav" },
        fx = "shadow", color = Color(20, 20, 20),
        requirements = { level = 5, clan = "nara" },
        unlock = "auto",
    },
    akimichi_expansion = {
        name = "Baika no Jutsu",
        description = "Votre corps grossit : plus de vie et de force, moins de vitesse.",
        category = "clan", archetype = "buff",
        chakra = 35, cooldown = 60, castTime = 0.8, duration = 20,
        modifiers = {
            maxHealth = { mul = 0.4 },
            meleePower = { mul = 0.3 },
            damageReduction = { add = 0.15 },
            runSpeed = { mul = -0.25 },
            walkSpeed = { mul = -0.2 },
        },
        scale = 1.35,
        castAnimation = { gesture = ACT_GMOD_TAUNT_CHEER },
        fx = "aura", color = Color(255, 170, 60),
        requirements = { level = 5, clan = "akimichi" },
        unlock = "auto",
    },
    inuzuka_fang = {
        name = "Gatsūga",
        description = "Une rotation foreuse qui transperce les ennemis sur votre trajectoire.",
        category = "clan", archetype = "dash_strike",
        chakra = 25, cooldown = 10, castTime = 0.3,
        damage = 30, range = 700, radius = 42, scaling = "melee",
        knockback = 380, knockup = 120,
        animation = PUNCH,
        sounds = { fire = "naruto_sound/jutsu/hyuga/hyuga1.wav" },
        fx = "wind", color = Color(200, 170, 120),
        requirements = { level = 5, clan = "inuzuka" },
        unlock = "auto",
    },
    aburame_swarm = {
        name = "Mushi Kame no Jutsu",
        description = "Un essaim d'insectes qui dévore le chakra de sa cible.",
        category = "clan", archetype = "projectile",
        chakra = 20, cooldown = 9, castTime = 0.5,
        damage = 10, speed = 700, range = 1200, radius = 40,
        effects = { { status = "chakra_drain", duration = 5, dps = 6 } },
        castAnimation = SEALS, animation = THROW,
        sounds = { fire = "naruto_sound/jutsu/senju/senju2.wav" },
        fx = "insects", color = Color(40, 40, 40),
        requirements = { level = 5, clan = "aburame" },
        unlock = "auto",
    },
    yamanaka_mind = {
        name = "Shintenshin no Jutsu",
        description = "Projette votre esprit dans la cible et la paralyse brièvement.",
        category = "clan", archetype = "genjutsu",
        chakra = 35, cooldown = 25, castTime = 1.0,
        range = 800, scaling = "genjutsu",
        effects = { { status = "stun", duration = 2.5 }, { status = "genjutsu", duration = 2.5 } },
        castAnimation = SEALS,
        fx = "genjutsu", color = Color(250, 220, 90),
        requirements = { level = 5, clan = "yamanaka" },
        unlock = "auto",
    },
    hyuga_rotation = {
        name = "Hakkeshō Kaiten",
        description = "Une rotation de chakra défensive qui repousse tout autour de vous. Byakugan requis.",
        category = "clan", archetype = "aoe", self = true,
        chakra = 35, cooldown = 16, castTime = 0.1,
        damage = 22, radius = 220,
        knockback = 800, knockup = 150,
        iframes = 0.6,
        animation = { gesture = ACT_GMOD_GESTURE_TAUNT_ZOMBIE },
        sounds = { fire = "naruto_sound/jutsu/hyuga/hyuga2.wav" },
        fx = "chakra_dome", color = Color(170, 200, 255),
        requirements = { level = 10, clan = "hyuga", dojutsu = { id = "byakugan", stage = 1, active = true } },
        unlock = "auto",
    },
    uchiha_amaterasu = {
        name = "Amaterasu",
        description = "Des flammes noires inextinguibles apparaissent là où vous regardez.",
        category = "clan", element = "katon", archetype = "aoe",
        chakra = 80, cooldown = 60, castTime = 0.4,
        damage = 20, range = 1200, radius = 90, delay = 0.2,
        effects = { { status = "burn", duration = 10, dps = 7, black = true } },
        sounds = { fire = "naruto_sound/jutsu/uchiha/uchiha1.wav" },
        fx = "black_flame", color = Color(20, 0, 30),
        requirements = { level = 50, clan = "uchiha", dojutsu = { id = "sharingan", stage = 4, active = true } },
        unlock = "tree",
    },
}
