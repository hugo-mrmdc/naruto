--[[
    Module : synchronisation avec l'API web externe (naruto_api/, PHP + MySQL)

    Ce fichier ne fait QUE pousser des données vers l'API (naruto_dev/../naruto_api/) :
    il ne change jamais le comportement du jeu si l'API est coupée ou injoignable
    (NRP.Config.Api.Enabled = false par défaut, voir config/sv_api.lua).

        - Fiche personnage complète  -> POST /characters/sync   (à chaque sauvegarde)
        - Connexion / déconnexion    -> POST /sessions/start|end
        - Actions journalisées       -> POST /logs               (miroir de NRP.LogAction)
        - Relations entre villages   -> POST /villages/relations/sync (resync périodique)
        - Catalogue des jutsu        -> POST /jutsu/sync         (une fois, au démarrage)
]]

NRP.Api = NRP.Api or {}

local function Cfg()
    return NRP.Config.Api or {}
end

local function Log(msg)
    if Cfg().Debug then
        NRP.Print("[API] " .. msg)
    end
end

--[[
    Requête HTTP générique vers l'API. Ne fait rien si NRP.Config.Api.Enabled
    est faux (permet d'installer ce module sans avoir configuré l'API tout de
    suite). Échoue toujours en silence côté jeu : un souci réseau côté site
    web ne doit jamais impacter les joueurs.
]]
function NRP.Api.Request(method, path, payload, onSuccess, onFailure)
    local cfg = Cfg()
    if not cfg.Enabled then return end
    if not cfg.BaseUrl or cfg.BaseUrl == "" then return end

    local ok, body = pcall(util.TableToJSON, payload or {})
    if not ok then
        Log("Échec d'encodage JSON pour " .. path)
        return
    end

    HTTP({
        url = cfg.BaseUrl .. path,
        method = method,
        headers = {
            ["Content-Type"] = "application/json",
            ["X-Api-Key"] = cfg.ApiKey or "",
        },
        body = body,
        type = "application/json",
        timeout = cfg.Timeout or 5,
        success = function(code, respBody)
            if code < 200 or code >= 300 then
                Log(method .. " " .. path .. " -> HTTP " .. code .. " : " .. tostring(respBody))
                if onFailure then onFailure(code, respBody) end
                return
            end
            if onSuccess then onSuccess(respBody) end
        end,
        failed = function(err)
            Log(method .. " " .. path .. " a échoué : " .. tostring(err))
            if onFailure then onFailure(nil, err) end
        end,
    })
end

---------------------------------------------------------------------------
-- Fiches personnage : une requête à chaque sauvegarde du jeu (autosave,
-- déconnexion, arrêt du serveur -> voir modules/character/sv_character.lua)
---------------------------------------------------------------------------

hook.Add("NRP.PreSaveCharacter", "NRP.Api.SyncCharacter", function(ply, data)
    if not Cfg().Enabled or not data or data.isBot then return end

    local Char = NRP.Char
    local payload = { steamid = data.steamid }
    for _, key in ipairs(Char.FieldList) do
        local f = Char.Fields[key]
        if f.save then
            payload[f.column] = Char.Encode(f, data[key])
        end
    end

    NRP.Api.Request("POST", "/characters/sync", payload)
end)

---------------------------------------------------------------------------
-- Sessions de connexion
---------------------------------------------------------------------------

local function SteamName(ply)
    if IsValid(ply) and ply.SteamName then return ply:SteamName() end
    return IsValid(ply) and ply:Nick() or ""
end

hook.Add("NRP.CharacterLoaded", "NRP.Api.SessionStart", function(ply, data)
    if not Cfg().Enabled or not IsValid(ply) or not data then return end
    ply.NRP_ApiSession = true
    NRP.Api.Request("POST", "/sessions/start", {
        steamid = data.steamid,
        steam_name = SteamName(ply),
    })
end)

hook.Add("PlayerDisconnected", "NRP.Api.SessionEnd", function(ply)
    if not Cfg().Enabled or not ply.NRP_ApiSession then return end
    local data = ply.NRPChar
    if not data then return end
    NRP.Api.Request("POST", "/sessions/end", { steamid = data.steamid })
end)

---------------------------------------------------------------------------
-- Journal d'actions : on garde NRP.LogAction intact et on relaie juste
-- l'appel vers l'API, sans changer son comportement local.
---------------------------------------------------------------------------

local BaseLogAction = NRP.LogAction
function NRP.LogAction(category, actor, target, message)
    BaseLogAction(category, actor, target, message)

    if not Cfg().Enabled then return end

    local actorId, actorName = "", "Console"
    if IsValid(actor) then
        actorId, actorName = actor:SteamID64() or "", SteamName(actor)
    end

    local targetId = ""
    if IsValid(target) then
        targetId = target:SteamID64() or ""
    elseif isstring(target) then
        targetId = target
    end

    NRP.Api.Request("POST", "/logs", {
        category = category,
        actor_steamid = actorId,
        actor_name = actorName,
        target_steamid = targetId,
        message = message,
    })
end

---------------------------------------------------------------------------
-- Relations entre villages : resync périodique complet (plus simple et
-- plus robuste qu'un suivi coup par coup, cette liste est petite).
---------------------------------------------------------------------------

local function SyncVillageRelations()
    local Villages = NRP.Villages
    if not Villages or not Villages.Relations then return end

    local list = {}
    for key, status in pairs(Villages.Relations) do
        local a, b = string.match(key, "^(.-)|(.+)$")
        if a and b then
            list[#list + 1] = { village_a = a, village_b = b, status = status }
        end
    end

    NRP.Api.Request("POST", "/villages/relations/sync", { relations = list })
end

timer.Create("NRP.Api.PeriodicSync", math.max(Cfg().SyncInterval or 60, 15), 0, function()
    if not Cfg().Enabled then return end
    SyncVillageRelations()
end)

---------------------------------------------------------------------------
-- Catalogue des jutsu : référence STATIQUE (config/jutsu.lua), pas propre à
-- un joueur -> poussée une seule fois, au chargement du gamemode, pas de
-- resync périodique (le catalogue ne change pas en cours de partie).
---------------------------------------------------------------------------

hook.Add("NRP.Loaded", "NRP.Api.SyncJutsuCatalog", function()
    if not Cfg().Enabled or not SERVER then return end

    local Jutsu = NRP.Jutsu
    if not Jutsu or not Jutsu.Registry then return end

    local list = {}
    for id, def in Jutsu.Registry:Iterate() do
        list[#list + 1] = {
            id = id,
            name = def.name,
            description = def.description,
            category = def.category,
            element = def.element,
            archetype = def.archetype,
            chakra = def.chakra,
            cooldown = def.cooldown,
            cast_time = def.castTime,
            damage = def.damage,
            range = def.range,
            unlock = def.unlock,
            requirements = def.requirements,
        }
    end

    NRP.Api.Request("POST", "/jutsu/sync", { jutsu = list })
end)
