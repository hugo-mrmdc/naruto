--[[
    Core : utilitaires partagés (logs, formatage, recherche de joueurs)
]]

NRP.Util = NRP.Util or {}
local Util = NRP.Util

local COLOR_TAG = Color(255, 140, 30)
local COLOR_TEXT = Color(230, 230, 230)
local COLOR_WARN = Color(255, 200, 60)
local COLOR_ERR = Color(255, 80, 80)

function NRP.Print(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    MsgC(COLOR_TAG, "[NRP] ", COLOR_TEXT, table.concat(parts, " "), "\n")
end

function NRP.Warn(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    MsgC(COLOR_TAG, "[NRP] ", COLOR_WARN, table.concat(parts, " "), "\n")
end

function NRP.Error(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring((select(i, ...)))
    end
    MsgC(COLOR_TAG, "[NRP] ", COLOR_ERR, table.concat(parts, " "), "\n")
end

local debugCvar = GetConVar("nrp_debug") or CreateConVar("nrp_debug", "0", FCVAR_REPLICATED + FCVAR_ARCHIVE, "Logs de debug Naruto RP")

function NRP.Debug(...)
    if debugCvar:GetBool() then
        NRP.Print("[debug]", ...)
    end
end

-- Identifiant de contenu valide (jutsu, objet, clan...) : lettres, chiffres, underscore.
function Util.IsValidId(id)
    return isstring(id) and #id > 0 and #id <= 64 and string.match(id, "^[%w_]+$") ~= nil
end

-- 1234567 -> "1 234 567"
function Util.FormatNumber(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n))
    local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
    out = string.Trim(out)
    return (n < 0 and "-" or "") .. out
end

function Util.FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh%02d", h, m)
    end
    return string.format("%d:%02d", m, s)
end

function Util.PlayerIterator()
    if player.Iterator then
        return player.Iterator()
    end
    return ipairs(player.GetAll())
end

-- Recherche un joueur par SteamID64, SteamID, UserID (#12) ou nom (RP ou Steam, partiel).
-- Retourne ply ou nil, message d'erreur.
function Util.FindPlayer(query)
    if IsEntity(query) then
        return IsValid(query) and query:IsPlayer() and query or nil, "Joueur invalide"
    end

    query = string.Trim(tostring(query or ""))
    if query == "" then return nil, "Aucun joueur indiqué" end

    if string.match(query, "^%d+$") and #query == 17 then
        local ply = player.GetBySteamID64(query)
        if IsValid(ply) then return ply end
    end

    if string.match(query, "^STEAM_%d:%d:%d+$") then
        local ply = player.GetBySteamID(query)
        if IsValid(ply) then return ply end
    end

    local uid = string.match(query, "^#(%d+)$")
    if uid then
        local ply = Player(tonumber(uid))
        if IsValid(ply) then return ply end
    end

    local lower = string.lower(query)
    local found
    for _, ply in Util.PlayerIterator() do
        local names = { ply.SteamName and ply:SteamName() or ply:Nick(), ply:GetNW2String("NRP_Name", "") }
        for _, name in ipairs(names) do
            local ln = string.lower(name)
            if ln == lower then
                return ply
            end
            if name ~= "" and string.find(ln, lower, 1, true) then
                if found and found ~= ply then
                    return nil, "Plusieurs joueurs correspondent à « " .. query .. " »"
                end
                found = ply
            end
        end
    end

    if found then return found end
    return nil, "Aucun joueur trouvé pour « " .. query .. " »"
end

-- Découpe une chaîne d'arguments en respectant les guillemets : a "b c" d -> {a, "b c", d}
function Util.SplitArgs(str)
    local args = {}
    local i, len = 1, #str
    while i <= len do
        local c = str:sub(i, i)
        if c == '"' then
            local j = str:find('"', i + 1, true) or (len + 1)
            args[#args + 1] = str:sub(i + 1, j - 1)
            i = j + 1
        elseif c:match("%s") then
            i = i + 1
        else
            local j = str:find("%s", i) or (len + 1)
            args[#args + 1] = str:sub(i, j - 1)
            i = j
        end
    end
    return args
end

-- Somme pondérée de modificateurs { add = x, mul = y } appliquée à une valeur.
function Util.ApplyModifier(value, add, mul)
    return (value + (add or 0)) * (1 + (mul or 0))
end

function Util.TableCount(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Résout une valeur de config pouvant être une fonction.
function Util.Resolve(value, ...)
    if isfunction(value) then
        return value(...)
    end
    return value
end

-- Compensation de latence, uniquement pendant le traitement d'une commande du joueur
-- (attaque d'arme, SetupMove...). Ailleurs (timer, message réseau) elle est ignorée.
function Util.LagCompensate(ply, enable)
    if SERVER and GetPredictionPlayer() == ply then
        ply:LagCompensation(enable)
    end
end

-- Vérifie qu'une position de hull joueur est libre (téléportations, dash...).
function Util.IsHullFree(pos, ply)
    local mins, maxs = Vector(-16, -16, 0), Vector(16, 16, 72)
    if IsValid(ply) then
        mins, maxs = ply:GetHull()
    end
    local tr = util.TraceHull({
        start = pos,
        endpos = pos,
        mins = mins,
        maxs = maxs,
        mask = MASK_PLAYERSOLID,
        filter = ply,
    })
    return not tr.Hit and not tr.StartSolid
end
