--[[
    Module : villages, relations, réputation (partagé)

    NRP.Villages est lui-même le registre des villages :
        NRP.Villages:Get("konoha"), NRP.Villages:Iterate()
    Les relations sont diffusées à tous (petite table, changée rarement) :
        NRP.Villages.GetRelation("konoha", "suna") -> "ally"
]]

-- État conservé si le fichier est rechargé à chaud
local previous = NRP.Villages or {}

NRP.Villages = NRP.CreateRegistry("villages", {
    defaults = { selectable = true, order = 50, color = Color(200, 200, 200), kage = "Kage" },
    validate = function(def) return isstring(def.name), "nom manquant" end,
})

local Villages = NRP.Villages
Villages:RegisterAll(NRP.Config.Villages)

Villages.RelationTypes = NRP.Config.VillageSettings.RelationTypes
Villages.Relations = previous.Relations or {}
Villages.WarScores = previous.WarScores
Villages.Spawns = previous.Spawns
Villages.Bounties = previous.Bounties
Villages.BingoBook = previous.BingoBook

NRP.Char.RegisterField("reputation", { type = "json", default = {} })
NRP.Char.RegisterField("deserter", { type = "bool", default = false, nw = "Bool", nwKey = "NRP_Deserter" })
NRP.Char.RegisterField("originVillage", { type = "string", default = "" })

local function Settings()
    return NRP.Config.VillageSettings
end

function Villages.RelationKey(a, b)
    if a > b then a, b = b, a end
    return a .. "|" .. b
end

function Villages.GetRelation(a, b)
    if not a or not b or a == "" or b == "" then return Settings().DefaultRelation end
    if a == b then return "ally" end
    return Villages.Relations[Villages.RelationKey(a, b)] or Settings().DefaultRelation
end

function Villages.GetRelationType(a, b)
    local id = Villages.GetRelation(a, b)
    return Villages.RelationTypes[id], id
end

-- (ne pas nommer "Sorted" : ce nom masquerait la méthode du registre)
function Villages.SortedList()
    return Villages:Sorted("order")
end

function Villages.GetReputation(data, villageId)
    return tonumber(data and data.reputation and data.reputation[villageId]) or 0
end

function Villages.GetReputationTitle(value)
    local title = ""
    for _, t in ipairs(Settings().Reputation.Titles) do
        if value >= t.min then title = t.name end
    end
    return title
end

-- Village affiché d'un joueur (les déserteurs affichent "Nukenin")
function Villages.GetDisplay(ply)
    return Villages:Get(NRP.Char.GetVillage(ply))
end
