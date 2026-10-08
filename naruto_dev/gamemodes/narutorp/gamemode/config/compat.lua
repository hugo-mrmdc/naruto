--[[
    Configuration : compatibilité avec l'addon naruto_dev (lua/autorun, lua/weapons)

    L'addon construit l'apparence (tenue sans tête + tête et cheveux collés au squelette),
    déclenche ses techniques par touches directes et fournit ses propres armes.
    Le gamemode s'adapte à lui au lieu de le remplacer.
]]

NRP.Config.Compat = {
    NarutoDev = {
        -- Détection automatique : hook "PlayerSpawn" / "NA_SetHeadAndHair" de l'addon
        Enabled = true,

        -- Après la mise en place de l'addon (0,1 s), réappliquer la tenue choisie à la création.
        -- La tête et les cheveux de l'addon restent attachés (fusion de squelette).
        KeepCharacterOutfit = true,
        ReapplyDelay = 0.3,

        -- Parties ajoutées par l'addon, reproduites dans l'aperçu de création
        PreviewParts = {
            { model = "models/head_03.mdl", color = Color(255, 210, 180) },
            { model = "models/hairs1_head.mdl", color = Color(0, 0, 0) },
        },
    },

    -- Armes que tous les joueurs peuvent prendre dans le menu Q (les autres restent réservées au staff)
    PlayerWeapons = {
        hand = true,
        hiramekarei = true,
        katana_basique = true,
        kabutowari = true,
        shibuki = true,
        shuriken_fuma = true,
        zabuza = true,
    },
    -- Ouvre le menu Q à tous les joueurs (le serveur refuse tout ce qui n'est pas dans PlayerWeapons)
    SpawnMenuForPlayers = true,
}
