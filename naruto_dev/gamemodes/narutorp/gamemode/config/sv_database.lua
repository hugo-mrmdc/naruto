--[[
    Configuration base de données (SERVEUR UNIQUEMENT - jamais envoyé aux clients)

    Driver :
        "sqlite"  -> sv.db intégré à Garry's Mod, aucune installation
        "mysqloo" -> MySQL/MariaDB via le module binaire MySQLOO 9
                     (garrysmod/lua/bin/gmsv_mysqloo_win32.dll ou _linux.dll)
]]

NRP.Config.Database = {
    Driver = "sqlite",

    MySQL = {
        Host = "127.0.0.1",
        Port = 3306,
        User = "narutorp",
        Password = "change-moi",
        Database = "narutorp",
    },

    TablePrefix = "nrp_",

    -- Sauvegarde périodique des personnages modifiés (secondes)
    SaveInterval = 120,
}
