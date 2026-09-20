--[[
    Configuration : progression (XP, niveaux, statistiques, grades)
]]

NRP.Config.Progression = {
    MaxLevel = 100,

    -- XP nécessaire pour passer du niveau L à L+1 : Base * L ^ Exponent
    XPBase = 120,
    XPExponent = 1.45,

    -- Multiplicateur global (les événements s'y ajoutent)
    XPMultiplier = 1,

    StatPointsPerLevel = 3,
    -- 1 point de clan tous les N niveaux (+ ClanPointsStart au niveau 1)
    ClanPointsEvery = 5,
    ClanPointsStart = 1,

    -- Sources d'XP
    XP = {
        KillPlayer = 60,
        KillNPC = 12,
        JutsuUse = 2,              -- entraînement en lançant des jutsu
        JutsuUseCooldown = 20,     -- secondes entre deux gains par jutsu
        TrainingHit = 1,           -- coup sur un mannequin d'entraînement
        TrainingHourlyCap = 250,   -- XP d'entraînement max par heure
        FocusTick = 1,             -- méditation (concentration du chakra)
        FocusInterval = 15,
        SameVictimCooldown = 600,  -- anti-farm : pas d'XP sur la même victime avant X s
    },

    -- Réinitialisation des stats (commande admin ou objet)
    ResetRefundsAll = true,
}

--[[
    Statistiques allouables. max = plafond de points investis.
]]
NRP.Config.Stats = {
    { id = "vitality", name = "Vie", description = "Augmente les points de vie maximum.", max = 100 },
    { id = "endurance", name = "Endurance", description = "Augmente l'endurance et sa régénération.", max = 100 },
    { id = "strength", name = "Force", description = "Dégâts au corps à corps et poids transportable.", max = 100 },
    { id = "speed", name = "Vitesse", description = "Vitesse de déplacement et de course.", max = 100 },
    { id = "chakra", name = "Réserve de chakra", description = "Augmente le chakra maximum.", max = 100 },
    { id = "control", name = "Maîtrise du chakra", description = "Régénération, coût et vitesse d'incantation.", max = 100 },
    { id = "ninjutsu", name = "Ninjutsu", description = "Puissance des ninjutsu.", max = 100 },
    { id = "taijutsu", name = "Taijutsu", description = "Puissance des techniques de corps à corps.", max = 100 },
    { id = "genjutsu", name = "Genjutsu", description = "Puissance et résistance aux illusions.", max = 100 },
}

--[[
    Valeurs dérivées : fonction des statistiques effectives s (points + bonus).
    Tous les modificateurs (clan, dojutsu, équipement, statuts) s'appliquent ensuite :
        valeur finale = (formule + add) * (1 + mul)
    percent = true  : multiplicateur affiché en % (1.2 -> +20%)
    absolute = true : fraction affichée telle quelle (0.15 -> 15%)
]]
NRP.Config.Derived = {
    maxHealth = { name = "Vie max", fn = function(s) return 100 + s.vitality * 8 end },
    maxChakra = { name = "Chakra max", fn = function(s) return 100 + s.chakra * 8 + s.control * 2 end },
    chakraRegen = { name = "Régén. chakra /s", fn = function(s) return 2 + s.control * 0.06 + s.chakra * 0.02 end },
    maxStamina = { name = "Endurance max", fn = function(s) return 100 + s.endurance * 5 end },
    staminaRegen = { name = "Régén. endurance /s", fn = function(s) return 14 + s.endurance * 0.2 end },
    walkSpeed = { name = "Vitesse de marche", fn = function(s) return 190 + s.speed * 1.0 end },
    runSpeed = { name = "Vitesse de course", fn = function(s) return 330 + s.speed * 2.2 end },
    jumpPower = { name = "Saut", fn = function(s) return 220 + s.speed * 1.2 end },
    jutsuCost = { name = "Coût des jutsu", percent = true, fn = function(s) return math.max(0.5, 1 - s.control * 0.004) end },
    jutsuPower = { name = "Puissance ninjutsu", percent = true, fn = function(s) return 1 + s.ninjutsu * 0.012 end },
    castSpeed = { name = "Vitesse d'incantation", percent = true, fn = function(s) return 1 + s.control * 0.005 end },
    meleePower = { name = "Puissance taijutsu", percent = true, fn = function(s) return 1 + s.strength * 0.008 + s.taijutsu * 0.01 end },
    genjutsuPower = { name = "Puissance genjutsu", percent = true, fn = function(s) return 1 + s.genjutsu * 0.015 end },
    genjutsuResist = { name = "Résistance genjutsu", percent = true, absolute = true, fn = function(s) return math.min(0.6, s.genjutsu * 0.004 + s.control * 0.001) end },
    damageReduction = { name = "Réduction de dégâts", percent = true, absolute = true, fn = function() return 0 end },
    carryWeight = { name = "Poids max (kg)", fn = function(s) return 30 + s.strength * 0.4 end },
    xpMultiplier = { name = "Bonus d'XP", percent = true, fn = function() return 1 end },
}

--[[
    Grades ninja, du plus bas au plus haut (order).
        minLevel        : niveau minimum pour être promu (ignoré par un admin avec forçage)
        maxMissionRank  : rang de mission maximum accessible
        promoteUpTo     : ce grade peut promouvoir jusqu'à ce grade (dans son village)
        permissions     : permissions supplémentaires (ex : organiser des examens)
        special         : grade spécial (non atteint par progression normale)
]]
NRP.Config.Ranks = {
    { id = "academy", name = "Académicien", order = 1, minLevel = 1, maxMissionRank = "D", color = Color(180, 180, 180) },
    { id = "genin", name = "Genin", order = 2, minLevel = 5, maxMissionRank = "C", color = Color(120, 200, 120) },
    { id = "chunin", name = "Chūnin", order = 3, minLevel = 15, maxMissionRank = "B", color = Color(90, 160, 240) },
    { id = "jonin", name = "Jōnin", order = 4, minLevel = 30, maxMissionRank = "A", color = Color(170, 110, 240),
        promoteUpTo = "genin", permissions = { ["rp.exam"] = true } },
    { id = "anbu", name = "ANBU", order = 5, minLevel = 40, maxMissionRank = "S", color = Color(90, 90, 110) },
    -- Grades spéciaux
    { id = "sannin", name = "Sannin", order = 6, minLevel = 60, maxMissionRank = "S", special = true, color = Color(240, 200, 80) },
    { id = "kage", name = "Kage", order = 7, minLevel = 50, maxMissionRank = "S", special = true, color = Color(255, 120, 40),
        promoteUpTo = "anbu", permissions = { ["rp.exam"] = true, ["rp.promote"] = false, ["rp.event"] = true } },
}

NRP.Config.Exams = {
    MaxCandidates = 20,
    -- Durée max d'une session d'examen (secondes)
    Timeout = 3600,
    XPReward = 200,
}
