--[[
    Module : personnage (serveur) - chargement, sauvegarde, synchronisation, apparence

    Cycle de vie :
        client InitPostEntity -> "NRP.ClientReady" -> Char.Load
            -> ligne trouvée : Char.Setup -> hooks "NRP.PreCharacterLoaded" / "NRP.CharacterLoaded"
            -> sinon : "NRP.OpenCreation" (voir sv_creation.lua)
        Sauvegarde : champs modifiés uniquement, toutes les SaveInterval s, à la déconnexion et à l'arrêt.

    Modifier une donnée : NRP.Char.Set(ply, "ryo", 100)
    Après modification EN PLACE d'une table : NRP.Char.Touch(ply, "jutsus")
]]

local Char = NRP.Char
local DB = NRP.DB

Char.TABLE = "characters"

NRP.Net.Pool("CharSync")
NRP.Net.Pool("OpenCreation")
NRP.Net.Pool("CreationResult")

DB.RegisterTable(Char.TABLE, function()
    local columns = { { "steamid", "steamid", notNull = true } }
    for _, key in ipairs(Char.FieldList) do
        local f = Char.Fields[key]
        if f.save then
            local default = f.default
            if istable(default) or isfunction(default) then default = nil end
            if isbool(default) then default = default and 1 or 0 end
            columns[#columns + 1] = { f.column, f.type, default }
        end
    end
    return {
        columns = columns,
        primary = { "steamid" },
        indexes = { { "village" }, { "clan" } },
    }
end)

---------------------------------------------------------------------------
-- Encodage / décodage
---------------------------------------------------------------------------

function Char.Decode(field, raw)
    if raw == nil or raw == DB.NULL then
        return Char.DefaultValue(field.key)
    end

    local t = field.type
    if t == "int" or t == "bigint" or t == "float" then
        return tonumber(raw) or Char.DefaultValue(field.key)
    elseif t == "bool" then
        return raw == true or tonumber(raw) == 1
    elseif t == "json" then
        local value = isstring(raw) and util.JSONToTable(raw) or nil
        if not istable(value) then
            return Char.DefaultValue(field.key)
        end
        -- Complète les clés manquantes à partir du défaut (tables "objet")
        local default = Char.DefaultValue(field.key)
        if istable(default) and not default[1] then
            for k, v in pairs(default) do
                if value[k] == nil then value[k] = v end
            end
        end
        return value
    end
    return tostring(raw)
end

function Char.Encode(field, value)
    if field.type == "bool" then
        return value and 1 or 0
    elseif field.type == "json" then
        return istable(value) and value or {}
    end
    return value
end

---------------------------------------------------------------------------
-- Données publiques
---------------------------------------------------------------------------

function Char.UpdatePublic(ply)
    local data = ply.NRPChar
    if not data then return end

    ply:SetNW2String("NRP_Name", string.Trim((data.firstname or "") .. " " .. (data.lastname or "")))
    for _, key in ipairs(Char.FieldList) do
        local f = Char.Fields[key]
        if f.nw then
            ply["SetNW2" .. f.nw](ply, f.nwKey, data[key])
        end
    end
end

local function ClearPublic(ply)
    ply:SetNW2Bool("NRP_Loaded", false)
    ply:SetNW2String("NRP_Name", "")
    for _, key in ipairs(Char.FieldList) do
        local f = Char.Fields[key]
        if f.nw then
            local empty = (f.nw == "String" and "") or (f.nw == "Bool" and false) or 0
            ply["SetNW2" .. f.nw](ply, f.nwKey, empty)
        end
    end
end

---------------------------------------------------------------------------
-- Synchronisation privée
---------------------------------------------------------------------------

function Char.SyncFull(ply)
    local data = ply.NRPChar
    if not data then return end

    local payload = { steamid = data.steamid }
    for _, key in ipairs(Char.FieldList) do
        if Char.Fields[key].sync then
            payload[key] = data[key]
        end
    end

    NRP.Net.Start("CharSync")
        net.WriteBool(true)
        NRP.Net.WriteTable(payload)
    net.Send(ply)
end

function Char.FlushSync(ply)
    ply.NRPSyncPending = false
    local queue = ply.NRPSyncQueue
    ply.NRPSyncQueue = {}

    local data = ply.NRPChar
    if not data or not queue or next(queue) == nil then return end

    local payload = {}
    for key in pairs(queue) do
        payload[key] = data[key]
    end

    NRP.Net.Start("CharSync")
        net.WriteBool(false)
        NRP.Net.WriteTable(payload)
    net.Send(ply)
end

-- Regroupe les envois d'un même tick en un seul message.
function Char.Sync(ply, key)
    ply.NRPSyncQueue = ply.NRPSyncQueue or {}
    ply.NRPSyncQueue[key] = true
    if ply.NRPSyncPending then return end

    ply.NRPSyncPending = true
    timer.Simple(0, function()
        if IsValid(ply) then Char.FlushSync(ply) end
    end)
end

---------------------------------------------------------------------------
-- Modification
---------------------------------------------------------------------------

function Char.MarkDirty(ply, key)
    ply.NRPDirty = ply.NRPDirty or {}
    ply.NRPDirty[key] = true
end

function Char.Set(ply, key, value, noSync)
    local data = ply.NRPChar
    if not data then return false end

    local old = data[key]
    data[key] = value
    Char.MarkDirty(ply, key)

    local field = Char.Fields[key]
    if field then
        if field.nw then
            ply["SetNW2" .. field.nw](ply, field.nwKey, value)
        end
        if key == "firstname" or key == "lastname" then
            Char.UpdatePublic(ply)
        end
        if field.sync and not noSync then
            Char.Sync(ply, key)
        end
    end

    hook.Run("NRP.CharacterChanged", ply, key, value, old)
    return true
end

-- À appeler après avoir modifié une table en place.
function Char.Touch(ply, key)
    if not ply.NRPChar then return end
    Char.MarkDirty(ply, key)
    local field = Char.Fields[key]
    if field and field.sync then
        Char.Sync(ply, key)
    end
    hook.Run("NRP.CharacterChanged", ply, key, ply.NRPChar[key])
end

function Char.GetFlag(ply, key, fallback)
    local data = ply.NRPChar
    if not data or data.flags[key] == nil then return fallback end
    return data.flags[key]
end

function Char.SetFlag(ply, key, value)
    local data = ply.NRPChar
    if not data then return end
    data.flags[key] = value
    Char.Touch(ply, "flags")
end

---------------------------------------------------------------------------
-- Ryo
---------------------------------------------------------------------------

function Char.GetRyo(ply)
    return ply.NRPChar and ply.NRPChar.ryo or 0
end

function Char.CanAfford(ply, amount)
    return Char.GetRyo(ply) >= amount
end

-- amount négatif = retrait ; échoue si le solde deviendrait négatif
function Char.AddRyo(ply, amount, reason)
    local data = ply.NRPChar
    amount = math.floor(tonumber(amount) or 0)
    if not data or amount == 0 then return false end

    local newValue = data.ryo + amount
    if newValue < 0 then return false end

    Char.Set(ply, "ryo", newValue)
    hook.Run("NRP.RyoChanged", ply, amount, reason)
    return true
end

---------------------------------------------------------------------------
-- Chargement
---------------------------------------------------------------------------

function Char.Setup(ply, data, isNew)
    ply.NRPChar = data
    ply.NRPDirty = {}
    ply.NRPPlaytimeMark = CurTime()

    hook.Run("NRP.PreCharacterLoaded", ply, data, isNew)

    Char.UpdatePublic(ply)
    ply:SetNW2Bool("NRP_Loaded", true)
    Char.SyncFull(ply)

    hook.Run("NRP.CharacterLoaded", ply, data, isNew)
    ply:Spawn()
end

function Char.FromRow(row)
    local data = { steamid = tostring(row.steamid) }
    for _, key in ipairs(Char.FieldList) do
        local f = Char.Fields[key]
        data[key] = Char.Decode(f, row[f.column])
    end
    return data
end

function Char.OpenCreation(ply)
    ply.NRPChar = nil
    ClearPublic(ply)

    local info = hook.Run("NRP.CreationInfo", ply) or {}
    NRP.Net.Start("OpenCreation")
        NRP.Net.WriteTable(info)
    net.Send(ply)
end

function Char.Load(ply)
    if ply:IsBot() then
        Char.CreateBot(ply)
        return
    end

    if not DB.Ready then
        ply.NRPPendingLoad = true
        return
    end

    ply.NRPPendingLoad = nil
    local sid = ply:SteamID64()

    DB.Select(Char.TABLE, { steamid = sid }, function(rows)
        if not IsValid(ply) then return end
        if rows[1] then
            Char.Setup(ply, Char.FromRow(rows[1]), false)
        else
            Char.OpenCreation(ply)
        end
    end, function()
        if IsValid(ply) then
            ply:Kick("Erreur de chargement du personnage, réessayez dans un instant.")
        end
    end)
end

-- Lecture d'un personnage hors ligne (administration)
function Char.LoadOffline(steamid, callback)
    DB.Select(Char.TABLE, { steamid = steamid }, function(rows)
        callback(rows[1] and Char.FromRow(rows[1]) or nil)
    end, function()
        callback(nil)
    end)
end

-- Les bots reçoivent un personnage temporaire (tests de combat), jamais sauvegardé.
function Char.CreateBot(ply)
    local data = { steamid = "BOT" .. ply:EntIndex(), isBot = true }
    for _, key in ipairs(Char.FieldList) do
        data[key] = Char.DefaultValue(key)
    end

    local villages = {}
    for id, v in NRP.Villages:Iterate() do
        if v.selectable then villages[#villages + 1] = id end
    end
    local elements = NRP.Config.Character.SelectableAffinities

    data.firstname = "Bot"
    data.lastname = tostring(ply:EntIndex())
    data.village = villages[math.random(#villages)] or ""
    data.affinities = { elements[math.random(#elements)] }
    data.model = NRP.Config.General.DefaultModel
    data.created = os.time()

    hook.Run("NRP.InitCharacter", ply, data, {})
    Char.Setup(ply, data, true)
end

---------------------------------------------------------------------------
-- Sauvegarde
---------------------------------------------------------------------------

function Char.Save(ply)
    local data = ply.NRPChar
    if not data or data.isBot or not DB.Ready then return end

    local now = CurTime()
    data.playtime = (data.playtime or 0) + math.floor(now - (ply.NRPPlaytimeMark or now))
    ply.NRPPlaytimeMark = now
    data.lastSeen = os.time()

    local dirty = ply.NRPDirty or {}
    dirty.playtime = true
    dirty.lastSeen = true
    ply.NRPDirty = {}

    hook.Run("NRP.PreSaveCharacter", ply, data)

    local update = {}
    for key in pairs(dirty) do
        local f = Char.Fields[key]
        if f and f.save then
            update[f.column] = Char.Encode(f, data[key])
        end
    end

    DB.Update(Char.TABLE, update, { steamid = data.steamid })
end

local function HasDirtyData(ply)
    return ply.NRPDirty and next(ply.NRPDirty) ~= nil
end

timer.Create("NRP.Char.AutoSave", (NRP.Config.Database or {}).SaveInterval or 120, 0, function()
    for _, ply in NRP.Util.PlayerIterator() do
        if ply.NRPChar and HasDirtyData(ply) then
            Char.Save(ply)
        end
    end
end)

hook.Add("PlayerDisconnected", "NRP.Char.Save", function(ply)
    if ply.NRPChar then
        Char.Save(ply)
        hook.Run("NRP.CharacterUnloaded", ply)
    end
end)

hook.Add("NRP.ShutDown", "NRP.Char.SaveAll", function()
    for _, ply in NRP.Util.PlayerIterator() do
        if ply.NRPChar then Char.Save(ply) end
    end
end)

---------------------------------------------------------------------------
-- Suppression / renommage (administration)
---------------------------------------------------------------------------

function Char.Delete(ply, callback)
    local data = ply.NRPChar
    if not data then return end

    hook.Run("NRP.CharacterUnloaded", ply)
    DB.Delete(Char.TABLE, { steamid = data.steamid }, function()
        if not IsValid(ply) then return end
        ply.NRPDirty = {}
        Char.OpenCreation(ply)
        ply:KillSilent()
        if callback then callback() end
    end)
end

function Char.Rename(ply, firstname, lastname)
    local ok1, first = Char.ValidateName(firstname)
    if not ok1 then return false, first end
    local ok2, last = Char.ValidateName(lastname)
    if not ok2 then return false, last end

    Char.Set(ply, "firstname", first)
    Char.Set(ply, "lastname", last)
    return true
end

---------------------------------------------------------------------------
-- Apparence et apparition
---------------------------------------------------------------------------

function Char.ApplyAppearance(ply)
    local data = ply.NRPChar
    if not data or not isstring(data.model) or data.model == "" then return false end
    if not util.IsValidModel(data.model) then return false end

    ply:SetModel(data.model)
    ply:SetSkin(math.Clamp(tonumber(data.skin) or 0, 0, math.max(0, ply:SkinCount() - 1)))

    for id, value in pairs(data.bodygroups or {}) do
        id, value = tonumber(id), tonumber(value)
        if id and value and id >= 0 and id < ply:GetNumBodyGroups() then
            ply:SetBodygroup(id, math.Clamp(value, 0, math.max(0, ply:GetBodygroupCount(id) - 1)))
        end
    end

    local c = data.color
    if istable(c) and c[1] then
        ply:SetPlayerColor(Vector((tonumber(c[1]) or 255) / 255, (tonumber(c[2]) or 255) / 255, (tonumber(c[3]) or 255) / 255))
    end

    hook.Run("NRP.AppearanceApplied", ply)
    return true
end

-- Un joueur sans personnage attend, figé et invisible, la fin de la création.
hook.Add("NRP.PlayerSpawned", "NRP.Char.Spawn", function(ply)
    if ply.NRPChar then
        ply:Freeze(false)
        ply:GodDisable()
        ply:SetNoDraw(false)
        ply:SetNotSolid(false)
        return
    end

    ply:StripWeapons()
    ply:Freeze(true)
    ply:GodEnable()
    ply:SetNoDraw(true)
    ply:SetNotSolid(true)
end)

---------------------------------------------------------------------------
-- Connexion
---------------------------------------------------------------------------

NRP.Net.Receive("ClientReady", function(ply)
    if ply.NRPReady then return end
    ply.NRPReady = true
    Char.Load(ply)
end, { needChar = false, rate = 0.2, burst = 2 })

hook.Add("PlayerInitialSpawn", "NRP.Char.Bots", function(ply)
    if ply:IsBot() then
        timer.Simple(1, function()
            if IsValid(ply) and not ply.NRPChar then Char.CreateBot(ply) end
        end)
    end
end)

hook.Add("NRP.DatabaseReady", "NRP.Char.PendingLoads", function()
    for _, ply in NRP.Util.PlayerIterator() do
        if ply.NRPPendingLoad then
            Char.Load(ply)
        end
    end
end)
