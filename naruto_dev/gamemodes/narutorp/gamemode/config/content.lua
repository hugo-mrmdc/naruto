--[[
    Contenu requis (modèles, textures, animations)

    Le gamemode et l'addon naruto_dev utilisent des modèles et des animations qui
    vivent dans des addons workshop. Si un joueur ne les a pas (ou les a désactivés
    dans son menu Addons), il voit des modèles roses et noirs et les animations de
    jutsu ne partent pas.

    Ce fichier sert à deux choses :
      1. le serveur fait télécharger ces addons aux joueurs (resource.AddWorkshop) ;
      2. le client vérifie ce qui manque réellement et le dit clairement,
         au lieu de laisser le joueur deviner.

    Pour ajouter un addon : son id workshop, un nom lisible, et au moins un fichier
    caractéristique (files) pour savoir s'il est bien monté chez le joueur.
]]

NRP.Config.Content = {
    -- Le serveur déclare les addons en téléchargement automatique pour les joueurs
    AutoDownload = true,
    -- Avertir le joueur dans le chat quand il lui manque du contenu
    WarnPlayers = true,
    -- Délai avant la vérification côté client (laisse le temps aux montages de se faire)
    CheckDelay = 12,

    Addons = {
        {
            id = 2916561591,
            name = "[wOS] DynaBase - Dynamic Animation Manager",
            note = "ajoute les animations de jutsu au modèle du joueur",
            required = true,
            files = { "models/player/wiltos/anim_dynamic_pointer.mdl" },
            -- Séquence présente uniquement quand DynaBase s'applique vraiment au joueur
            sequence = "_dynamic_wiltos_enabled_",
        },
        {
            id = 848953359,
            name = "[wOS] Animation Extension - Blade Symphony",
            files = { "models/player/wiltos/anim_extension_bs.mdl" },
        },
        {
            -- Pas d'id workshop : addon de contenu local (addons/naruto_content),
            -- qui regroupe les textures autrefois éparpillées dans les addons ATG.
            -- Un joueur qui a les addons ATG d'origine passe aussi ce test.
            id = 0,
            name = "Contenu Naruto RP (addon naruto_content, ou les addons ATG)",
            note = "textures des tenues, têtes, cheveux, sabres et invocations",
            required = true,
            files = {
                "materials/models/godio/senju_a/senju_a.vmt",
                "materials/models/daichi/w_fuma_tkj/fuma_tkj.vmt",
                "materials/models/kaesar/solve/naruto_head/t_chr_face_bc.vmt",
                "materials/models/skylyxx/ctg/props/swords/shibuki.vmt",
                "materials/models/warwax/salamandre/body.vmt",
            },
        },
    },

    -- Animations indispensables (fournies par les extensions montées dans DynaBase).
    -- Elles sont cherchées sur le modèle du joueur : c'est le seul test fiable.
    Sequences = {
        "nrp_ninjutsu_defend_dragonflamebombs_start",
        "nrp_ninjutsu_trow_fireball_lv3",
        "nrp_lobby_shikamaru_etc_team_type1_wait_loop",
    },
}
