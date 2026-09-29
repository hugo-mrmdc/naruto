--[[
    Configuration de l'API web externe (SERVEUR UNIQUEMENT - jamais envoyé aux clients)

    Sert à synchroniser le serveur GMod avec le site web (naruto_api/, PHP + MySQL,
    base séparée de celle du jeu) : fiches personnage, sessions de connexion,
    journal d'actions, relations entre villages.
    Voir modules/api_sync/sv_api_sync.lua pour l'utilisation, et naruto_api/README.md
    pour l'installation du côté PHP.
]]

NRP.Config.Api = {
    -- Passe à true une fois l'API PHP en ligne et BaseUrl/ApiKey renseignés.
    Enabled = false,

    -- URL du point d'entrée de l'API (public/index.php), avec ou sans le
    -- fichier selon que le mod_rewrite (.htaccess fourni) est actif.
    BaseUrl = "https://tonsite.exemple/naruto_api/public/index.php",

    -- Doit être IDENTIQUE à API_KEY dans naruto_api/.env
    ApiKey = "change_me_avec_une_longue_cle_aleatoire",

    Timeout = 5,   -- secondes avant d'abandonner une requête HTTP

    -- Intervalle (s) auquel les relations entre villages sont renvoyées en
    -- entier (plus simple/robuste qu'un suivi coup par coup).
    SyncInterval = 60,

    -- Affiche les erreurs de requête dans la console serveur.
    Debug = false,
}
