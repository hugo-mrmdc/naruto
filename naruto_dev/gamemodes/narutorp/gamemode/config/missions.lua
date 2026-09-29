--[[
    Configuration : missions

    Les lieux de mission sont placés en jeu par les admins, par carte :
        !mpoint add <tag> [nom]      (ex : !mpoint add delivery "Maison du forgeron")
    Une mission dont le tag n'a aucun point n'est pas proposée.

    Types : delivery, retrieve, eliminate, escort, protect, recon, defend, boss
    (voir modules/missions/types/ pour ajouter un type)

    Champs d'une mission :
        name, description, rank (D..S), type, params (selon le type)
        villages      : villages pouvant la recevoir (nil = tous, "nukenin" pour les déserteurs)
        minLevel, minRank, party = { min, max }
        timeLimit (s), cooldown (s, par joueur)
        rewards = { xp, ryo, reputation, items = { id = qte }, statPoints,
                    custom = function(ply, instance) end }
]]

NRP.Config.MissionSettings = {
    NPCUseDistance = 160,
    CheckInterval = 1,
    InviteTimeout = 30,
    AbandonCooldown = 60,
    FailOnAllDead = true,
    LeaderDisconnectFail = false,
    WaypointColor = Color(255, 200, 60),
    NPCModel = "models/gman_high.mdl",

    Ranks = {
        D = { name = "Rang D", order = 1, color = Color(160, 160, 160) },
        C = { name = "Rang C", order = 2, color = Color(90, 200, 110) },
        B = { name = "Rang B", order = 3, color = Color(80, 150, 255) },
        A = { name = "Rang A", order = 4, color = Color(180, 90, 240) },
        S = { name = "Rang S", order = 5, color = Color(255, 90, 60) },
    },
}

-- Ennemis utilisables par les missions (PNJ Source classiques)
NRP.Config.MissionEnemies = {
    bandit = {
        name = "Bandit",
        class = "npc_metropolice",
        weapon = "weapon_stunstick",
        health = 90,
        damageScale = 0.8,
    },
    rogue_ninja = {
        name = "Ninja renégat",
        class = "npc_combine_s",
        weapon = "weapon_smg1",
        health = 180,
        damageScale = 0.5,
    },
    rogue_leader = {
        name = "Chef renégat",
        class = "npc_combine_s",
        weapon = "weapon_ar2",
        model = "models/combine_super_soldier.mdl",
        health = 1500,
        damageScale = 0.7,
        scalePerMember = 0.5,    -- +50% de vie par membre supplémentaire
    },
}

NRP.Config.Missions = {
    ---------------------------------------------------------------- RANG D
    d_delivery = {
        name = "Livraison de courrier",
        description = "Apportez ce parchemin scellé à son destinataire.",
        rank = "D", type = "delivery",
        params = { item = "mission_scroll", point = "delivery", radius = 150 },
        timeLimit = 600, cooldown = 300, party = { 1, 2 },
        rewards = { xp = 80, ryo = 120, reputation = 3 },
    },
    d_retrieve = {
        name = "Objet perdu",
        description = "Un habitant a perdu un colis. Retrouvez-le et rapportez-le.",
        rank = "D", type = "retrieve",
        params = { item = "mission_package", point = "retrieve", model = "models/props_junk/cardboard_box003a.mdl" },
        timeLimit = 600, cooldown = 300, party = { 1, 2 },
        rewards = { xp = 90, ryo = 140, reputation = 3 },
    },
    d_recon = {
        name = "Patrouille",
        description = "Inspectez plusieurs points autour du village.",
        rank = "D", type = "recon",
        params = { point = "recon", count = 3, radius = 200 },
        timeLimit = 900, cooldown = 300, party = { 1, 4 },
        rewards = { xp = 100, ryo = 100, reputation = 4, items = { onigiri = 2 } },
    },

    ---------------------------------------------------------------- RANG C
    c_bandits = {
        name = "Chasse aux bandits",
        description = "Des bandits menacent une route commerciale. Éliminez-les.",
        rank = "C", type = "eliminate", minLevel = 5,
        params = { point = "bandits", enemy = "bandit", count = 5 },
        timeLimit = 900, cooldown = 600, party = { 1, 4 },
        rewards = { xp = 250, ryo = 400, reputation = 8, items = { kunai = 5 } },
    },
    c_escort = {
        name = "Escorte d'un marchand",
        description = "Escortez le marchand jusqu'à destination sain et sauf.",
        rank = "C", type = "escort", minLevel = 5,
        params = { point = "escort", radius = 200, model = "models/Humans/Group01/male_09.mdl", health = 150,
            ambush = { enemy = "bandit", count = 3, delay = 40 } },
        timeLimit = 900, cooldown = 600, party = { 1, 4 },
        rewards = { xp = 280, ryo = 450, reputation = 8 },
    },

    ---------------------------------------------------------------- RANG B
    b_protect = {
        name = "Protection d'un dignitaire",
        description = "Un dignitaire est menacé. Protégez-le jusqu'à l'arrivée des renforts.",
        rank = "B", type = "protect", minLevel = 15,
        params = { point = "protect", duration = 150, enemy = "rogue_ninja", waveInterval = 30, waveSize = 3,
            model = "models/breen.mdl", health = 300 },
        timeLimit = 400, cooldown = 1200, party = { 2, 4 },
        rewards = { xp = 600, ryo = 1200, reputation = 15, items = { soldier_pill = 1 } },
    },
    b_defend = {
        name = "Défense d'un avant-poste",
        description = "Tenez la position face aux vagues ennemies.",
        rank = "B", type = "defend", minLevel = 15,
        params = { point = "defend", duration = 180, radius = 500, grace = 15, enemy = "rogue_ninja",
            waveInterval = 30, waveSize = 3 },
        timeLimit = 400, cooldown = 1200, party = { 1, 4 },
        rewards = { xp = 650, ryo = 1100, reputation = 15 },
    },

    ---------------------------------------------------------------- RANG A
    a_rogues = {
        name = "Traque des renégats",
        description = "Une cellule de ninjas renégats a été repérée. Neutralisez-la.",
        rank = "A", type = "eliminate", minLevel = 30,
        params = { point = "rogues", enemy = "rogue_ninja", count = 8 },
        timeLimit = 1200, cooldown = 2400, party = { 2, 5 },
        rewards = { xp = 1500, ryo = 3000, reputation = 25, statPoints = 1 },
    },

    ---------------------------------------------------------------- RANG S
    s_boss = {
        name = "Le chef renégat",
        description = "Éliminez le chef d'une organisation criminelle et ses gardes.",
        rank = "S", type = "boss", minLevel = 40,
        params = { point = "boss", boss = "rogue_leader", adds = "rogue_ninja", addCount = 4 },
        timeLimit = 1500, cooldown = 7200, party = { 3, 6 },
        rewards = { xp = 4000, ryo = 10000, reputation = 50, statPoints = 2, items = { anbu_armor = 1 } },
    },

    ---------------------------------------------------------------- DÉSERTEURS
    n_ambush = {
        name = "Embuscade",
        description = "Un contact paie pour éliminer des mercenaires concurrents.",
        rank = "C", type = "eliminate", villages = { "nukenin" },
        params = { point = "bandits", enemy = "bandit", count = 6 },
        timeLimit = 900, cooldown = 600, party = { 1, 3 },
        rewards = { xp = 260, ryo = 700 },
    },
}
