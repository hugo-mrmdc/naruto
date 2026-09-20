--[[
    Configuration : création de personnage et affinités élémentaires
]]

NRP.Config.Character = {
    NameMinLength = 2,
    NameMaxLength = 16,
    -- Noms interdits (comparaison en minuscules, prénom OU nom)
    BlacklistedNames = {
        "naruto", "sasuke", "sakura", "kakashi", "itachi", "madara", "hashirama",
        "tobirama", "minato", "jiraiya", "tsunade", "orochimaru", "pain", "obito",
        "admin", "moderateur", "staff",
    },
    -- Combinaison prénom + nom unique sur le serveur
    UniqueFullName = true,

    StartLevel = 1,
    StartRank = "academy",
    StartRyo = 500,
    StartItems = { onigiri = 3, kunai = 10 },

    -- Nombre d'affinités choisies à la création
    CreationAffinities = 1,
    -- Affinités proposées à la création (les autres s'obtiennent en jeu)
    SelectableAffinities = { "katon", "suiton", "raiton", "doton", "fuuton" },

    -- Apparence : modèles proposés par sexe.
    -- Les modèles absents du serveur/client sont masqués automatiquement.
    -- hasHead = true : le modèle a déjà une tête -> la tête/les cheveux de l'addon naruto_dev sont retirés.
    -- skins / bodygroups : le serveur borne toujours les valeurs au modèle réel.
    Genders = {
        male = {
            name = "Homme",
            models = {
                { model = "models/tenue/senju/senju_a.mdl", name = "Tenue Senju" },
                { model = "models/tenue/m_fuma_tkj.mdl", name = "Tenue Fuma" },
                { model = "models/player/group01/male_02.mdl", name = "Civil 1", hasHead = true },
                { model = "models/player/group01/male_07.mdl", name = "Civil 2", hasHead = true },
            },
        },
        female = {
            name = "Femme",
            models = {
                { model = "models/tenue/senju/senju_a.mdl", name = "Tenue Senju" },
                { model = "models/player/group01/female_01.mdl", name = "Civile 1", hasHead = true },
                { model = "models/player/group01/female_02.mdl", name = "Civile 2", hasHead = true },
                { model = "models/player/group03/female_06.mdl", name = "Civile 3", hasHead = true },
            },
        },
    },

    -- Couleur de tenue personnalisable (modèles compatibles "player color")
    AllowPlayerColor = true,
    -- Nombre max de bodygroups modifiables envoyés par le client
    MaxBodygroups = 12,
}

--[[
    Éléments (affinités). Cycle canonique : Katon > Fuuton > Raiton > Doton > Suiton > Katon
    strongAgainst : bonus de dégâts contre une cible dont l'affinité principale est cet élément.
]]
NRP.Config.Elements = {
    katon = { name = "Katon", description = "Feu", color = Color(255, 110, 40), strongAgainst = "fuuton", order = 1 },
    suiton = { name = "Suiton", description = "Eau", color = Color(60, 150, 255), strongAgainst = "katon", order = 2 },
    raiton = { name = "Raiton", description = "Foudre", color = Color(170, 200, 255), strongAgainst = "doton", order = 3 },
    doton = { name = "Doton", description = "Terre", color = Color(170, 120, 70), strongAgainst = "suiton", order = 4 },
    fuuton = { name = "Fuuton", description = "Vent", color = Color(150, 230, 170), strongAgainst = "raiton", order = 5 },
}

NRP.Config.ElementSettings = {
    StrongMultiplier = 1.2,        -- élément fort contre l'affinité principale de la cible
    PrimaryAffinityBonus = 1.1,    -- jutsu de son affinité principale
    MaxAffinities = 3,
}
