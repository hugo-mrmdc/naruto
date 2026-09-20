--[[
    Module : base de données

    API asynchrone identique pour SQLite et MySQLOO :
        NRP.DB.Query("SELECT * FROM " .. NRP.DB.Table("characters") .. " WHERE steamid = ?", { sid },
            function(rows, lastInsertId) end, function(err) end)
        NRP.DB.Insert(tbl, { col = val }, cb, errCb)
        NRP.DB.Update(tbl, { col = val }, { where_col = val }, cb, errCb)
        NRP.DB.Select(tbl, { where_col = val }, cb, errCb, "ORDER BY id DESC")
        NRP.DB.Delete(tbl, { where_col = val }, cb, errCb)
        NRP.DB.Replace(tbl, { col = val }, cb, errCb)

    Schéma déclaratif : chaque module déclare ses tables, le module crée les tables
    et ajoute les colonnes manquantes au démarrage (migrations sans perte).
        NRP.DB.RegisterTable("bounties", {
            columns = { { "id", "id" }, { "target", "steamid" }, { "amount", "bigint", 0 } },
            primary = { "id" },
            indexes = { { "target" } },
        })
    Types : id, int, bigint, float, bool, string, steamid, text, json

    ATTENTION : SQLite renvoie toutes les valeurs sous forme de chaînes -> toujours tonumber().
    Hook émis : "NRP.DatabaseReady" une fois les tables prêtes.
]]

NRP.DB = NRP.DB or {}
local DB = NRP.DB

DB.NULL = DB.NULL or setmetatable({}, { __tostring = function() return "NULL" end })
DB.Tables = DB.Tables or {}
DB.Ready = false
DB.Driver = "sqlite"

local pending = {}

local function Cfg()
    return NRP.Config.Database or {}
end

function DB.IsMySQL()
    return DB.Driver == "mysqloo"
end

function DB.Table(name)
    return (Cfg().TablePrefix or "nrp_") .. name
end

function DB.Ident(name)
    if not isstring(name) or not string.match(name, "^[%w_]+$") then
        error("Identifiant SQL invalide : " .. tostring(name), 2)
    end
    return "`" .. name .. "`"
end

function DB.Escape(str)
    str = tostring(str)
    if DB.IsMySQL() and DB.Conn then
        return "'" .. DB.Conn:escape(str) .. "'"
    end
    return sql.SQLStr(str)
end

function DB.Value(v)
    if v == nil or v == DB.NULL then
        return "NULL"
    end

    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "0"
        end
        if v == math.floor(v) and math.abs(v) < 2 ^ 53 then
            return string.format("%d", v)
        end
        return string.format("%.6f", v)
    elseif t == "boolean" then
        return v and "1" or "0"
    elseif t == "table" then
        return DB.Escape(util.TableToJSON(v))
    end

    return DB.Escape(v)
end

-- Remplace chaque "?" par la valeur échappée correspondante.
function DB.Format(query, params)
    local i = 0
    return (string.gsub(query, "%?", function()
        i = i + 1
        return DB.Value(params[i])
    end))
end

local function LogError(query, err)
    NRP.Error("SQL :", tostring(err))
    NRP.Error("   requête :", string.sub(query, 1, 400))
end

-- Exécution brute (sans file d'attente), utilisée par la migration.
local function RawQuery(query, onSuccess, onError)
    if DB.IsMySQL() then
        local q = DB.Conn:query(query)
        function q:onSuccess(data)
            if onSuccess then onSuccess(data or {}, self:lastInsert()) end
        end
        function q:onError(err)
            LogError(query, err)
            if onError then onError(err) end
        end
        q:start()
        return
    end

    local data = sql.Query(query)
    if data == false then
        local err = sql.LastError()
        LogError(query, err)
        if onError then onError(err) end
        return
    end

    if onSuccess then
        local lastId = 0
        if string.match(query, "^%s*[Ii][Nn][Ss][Ee][Rr][Tt]") then
            lastId = tonumber(sql.QueryValue("SELECT last_insert_rowid()")) or 0
        end
        onSuccess(data or {}, lastId)
    end
end

function DB.Query(query, params, onSuccess, onError)
    if params then
        query = DB.Format(query, params)
    end

    if not DB.Ready then
        pending[#pending + 1] = { query, onSuccess, onError }
        return
    end

    RawQuery(query, onSuccess, onError)
end

local function WhereClause(where)
    if not where or next(where) == nil then return "" end
    local parts = {}
    for col, val in SortedPairs(where) do
        if val == DB.NULL then
            parts[#parts + 1] = DB.Ident(col) .. " IS NULL"
        else
            parts[#parts + 1] = DB.Ident(col) .. " = " .. DB.Value(val)
        end
    end
    return " WHERE " .. table.concat(parts, " AND ")
end

function DB.Insert(tbl, data, onSuccess, onError)
    local cols, vals = {}, {}
    for col, val in SortedPairs(data) do
        cols[#cols + 1] = DB.Ident(col)
        vals[#vals + 1] = DB.Value(val)
    end
    DB.Query(string.format("INSERT INTO %s (%s) VALUES (%s)",
        DB.Ident(DB.Table(tbl)), table.concat(cols, ", "), table.concat(vals, ", ")), nil, onSuccess, onError)
end

function DB.Replace(tbl, data, onSuccess, onError)
    local cols, vals = {}, {}
    for col, val in SortedPairs(data) do
        cols[#cols + 1] = DB.Ident(col)
        vals[#vals + 1] = DB.Value(val)
    end
    DB.Query(string.format("REPLACE INTO %s (%s) VALUES (%s)",
        DB.Ident(DB.Table(tbl)), table.concat(cols, ", "), table.concat(vals, ", ")), nil, onSuccess, onError)
end

function DB.Update(tbl, data, where, onSuccess, onError)
    local sets = {}
    for col, val in SortedPairs(data) do
        sets[#sets + 1] = DB.Ident(col) .. " = " .. DB.Value(val)
    end
    if #sets == 0 then
        if onSuccess then onSuccess({}) end
        return
    end
    DB.Query(string.format("UPDATE %s SET %s%s",
        DB.Ident(DB.Table(tbl)), table.concat(sets, ", "), WhereClause(where)), nil, onSuccess, onError)
end

function DB.Select(tbl, where, onSuccess, onError, suffix)
    DB.Query(string.format("SELECT * FROM %s%s %s",
        DB.Ident(DB.Table(tbl)), WhereClause(where), suffix or ""), nil, onSuccess, onError)
end

function DB.Delete(tbl, where, onSuccess, onError)
    DB.Query(string.format("DELETE FROM %s%s",
        DB.Ident(DB.Table(tbl)), WhereClause(where)), nil, onSuccess, onError)
end

---------------------------------------------------------------------------
-- Schéma
---------------------------------------------------------------------------

-- def peut être une table ou une fonction renvoyant la table (évaluée à la migration)
function DB.RegisterTable(name, def)
    DB.Tables[name] = def
end

local SQLITE_TYPES = {
    id = "INTEGER PRIMARY KEY AUTOINCREMENT",
    int = "INTEGER", bigint = "INTEGER", bool = "INTEGER", float = "REAL",
    string = "TEXT", steamid = "TEXT", text = "TEXT", json = "TEXT",
}

local MYSQL_TYPES = {
    id = "INT NOT NULL AUTO_INCREMENT",
    int = "INT", bigint = "BIGINT", bool = "TINYINT", float = "DOUBLE",
    string = "VARCHAR(255)", steamid = "VARCHAR(32)", text = "TEXT", json = "MEDIUMTEXT",
}

local NO_DEFAULT = { text = true, json = true, id = true }

local function ColumnSQL(col)
    local name, kind, default = col[1], col[2], col[3]
    local types = DB.IsMySQL() and MYSQL_TYPES or SQLITE_TYPES
    local out = DB.Ident(name) .. " " .. (types[kind] or types.text)

    if default ~= nil and not (DB.IsMySQL() and NO_DEFAULT[kind]) and kind ~= "id" then
        out = out .. " DEFAULT " .. DB.Value(default)
    end
    if kind == "steamid" and col.notNull then
        out = out .. " NOT NULL"
    end
    return out
end

local function RunSteps(steps, done)
    local i = 0
    local function step()
        i = i + 1
        local fn = steps[i]
        if not fn then
            if done then done() end
            return
        end
        fn(step)
    end
    step()
end

local function MigrateTable(name, def, nextStep)
    if isfunction(def) then def = def() end
    local tbl = DB.Table(name)
    local lines = {}
    local hasAutoId = false

    for _, col in ipairs(def.columns) do
        lines[#lines + 1] = ColumnSQL(col)
        if col[2] == "id" then hasAutoId = true end
    end

    if def.primary and not (hasAutoId and not DB.IsMySQL()) then
        local keys = {}
        for _, k in ipairs(def.primary) do keys[#keys + 1] = DB.Ident(k) end
        lines[#lines + 1] = "PRIMARY KEY (" .. table.concat(keys, ", ") .. ")"
    end

    if DB.IsMySQL() then
        for i, idx in ipairs(def.indexes or {}) do
            local keys = {}
            for _, k in ipairs(idx) do keys[#keys + 1] = DB.Ident(k) end
            lines[#lines + 1] = "INDEX " .. DB.Ident("idx_" .. i) .. " (" .. table.concat(keys, ", ") .. ")"
        end
    end

    local create = string.format("CREATE TABLE IF NOT EXISTS %s (\n  %s\n)%s",
        DB.Ident(tbl), table.concat(lines, ",\n  "),
        DB.IsMySQL() and " ENGINE=InnoDB DEFAULT CHARSET=utf8mb4" or "")

    RunSteps({
        function(done)
            RawQuery(create, done, done)
        end,
        -- colonnes manquantes
        function(done)
            local listQuery = DB.IsMySQL()
                and ("SHOW COLUMNS FROM " .. DB.Ident(tbl))
                or ("PRAGMA table_info(" .. tbl .. ")")

            RawQuery(listQuery, function(rows)
                local existing = {}
                for _, row in ipairs(rows) do
                    existing[string.lower(row.Field or row.name or "")] = true
                end

                local alters = {}
                for _, col in ipairs(def.columns) do
                    if not existing[string.lower(col[1])] then
                        alters[#alters + 1] = function(d)
                            NRP.Print("Migration : ajout de la colonne " .. tbl .. "." .. col[1])
                            RawQuery("ALTER TABLE " .. DB.Ident(tbl) .. " ADD COLUMN " .. ColumnSQL(col), d, d)
                        end
                    end
                end
                RunSteps(alters, done)
            end, done)
        end,
        -- index (SQLite)
        function(done)
            if DB.IsMySQL() or not def.indexes then return done() end
            local steps = {}
            for i, idx in ipairs(def.indexes) do
                local keys = {}
                for _, k in ipairs(idx) do keys[#keys + 1] = DB.Ident(k) end
                steps[#steps + 1] = function(d)
                    RawQuery(string.format("CREATE INDEX IF NOT EXISTS %s ON %s (%s)",
                        DB.Ident(tbl .. "_idx_" .. i), DB.Ident(tbl), table.concat(keys, ", ")), d, d)
                end
            end
            RunSteps(steps, done)
        end,
    }, nextStep)
end

local function OnConnected()
    local steps = {}
    for name, def in SortedPairs(DB.Tables) do
        steps[#steps + 1] = function(done)
            MigrateTable(name, def, done)
        end
    end

    RunSteps(steps, function()
        DB.Ready = true
        NRP.Print("Base de données prête (" .. DB.Driver .. ", " .. table.Count(DB.Tables) .. " tables)")

        local queued = pending
        pending = {}
        for _, q in ipairs(queued) do
            RawQuery(q[1], q[2], q[3])
        end

        hook.Run("NRP.DatabaseReady")
    end)
end

local function ConnectMySQL()
    local cfg = Cfg().MySQL or {}

    if not util.IsBinaryModuleInstalled("mysqloo") then
        NRP.Error("MySQLOO introuvable (lua/bin). Repli sur SQLite.")
        DB.Driver = "sqlite"
        return OnConnected()
    end

    require("mysqloo")
    local conn = mysqloo.connect(cfg.Host, cfg.User, cfg.Password, cfg.Database, cfg.Port or 3306)
    DB.Conn = conn

    function conn:onConnected()
        NRP.Print("Connecté à MySQL " .. tostring(cfg.Host))
        if self.setCharacterSet then self:setCharacterSet("utf8mb4") end
        if not DB.Ready then OnConnected() end
    end

    function conn:onConnectionFailed(err)
        NRP.Error("Connexion MySQL impossible :", err, "- nouvel essai dans 30 s")
        timer.Simple(30, function() conn:connect() end)
    end

    if conn.setAutoReconnect then conn:setAutoReconnect(true) end
    conn:connect()
end

function DB.Connect()
    DB.Driver = Cfg().Driver == "mysqloo" and "mysqloo" or "sqlite"
    if DB.IsMySQL() then
        ConnectMySQL()
    else
        OnConnected()
    end
end

-- Connexion une fois tous les modules chargés (ils ont déclaré leurs tables).
hook.Add("Initialize", "NRP.DB.Connect", function()
    DB.Connect()
end)

-- Journal des actions sensibles (utilisé par l'administration)
DB.RegisterTable("logs", {
    columns = {
        { "id", "id" },
        { "time", "int", 0 },
        { "category", "string", "" },
        { "actor", "steamid", "" },
        { "actor_name", "string", "" },
        { "target", "steamid", "" },
        { "message", "text" },
    },
    primary = { "id" },
    indexes = { { "target" }, { "time" } },
})

function NRP.LogAction(category, actor, target, message)
    local actorId, actorName = "", "Console"
    if IsValid(actor) then
        actorId, actorName = actor:SteamID64() or "", actor.SteamName and actor:SteamName() or actor:Nick()
    end

    local targetId = ""
    if IsValid(target) then
        targetId = target:SteamID64() or ""
    elseif isstring(target) then
        targetId = target
    end

    NRP.Print(string.format("[%s] %s : %s", category, actorName, message))
    DB.Insert("logs", {
        time = os.time(),
        category = category,
        actor = actorId,
        actor_name = actorName,
        target = targetId,
        message = message,
    })
end
