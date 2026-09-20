--[[
    Module : base de données - commandes de diagnostic
]]

NRP.Commands.Add("dbstatus", {
    perm = "admin.character",
    description = "État de la base de données",
    run = function()
        local DB = NRP.DB
        local status = DB.Ready and "prête" or "non prête"
        if DB.IsMySQL() and DB.Conn and mysqloo then
            status = status .. " (MySQL, état " .. tostring(DB.Conn:status()) .. ")"
        else
            status = status .. " (SQLite)"
        end
        return true, "Base de données : " .. status
    end,
})

NRP.Commands.Add("saveall", {
    perm = "admin.character",
    description = "Sauvegarde immédiate de tous les personnages",
    run = function()
        local n = 0
        for _, ply in NRP.Util.PlayerIterator() do
            if ply.NRPChar then
                NRP.Char.Save(ply)
                n = n + 1
            end
        end
        return true, n .. " personnage(s) sauvegardé(s)."
    end,
})
