--[[
    Module : progression (partagé) - niveaux, grades, définitions de statistiques

    Valeurs dérivées et modificateurs : voir sh_stats.lua
]]

NRP.Progression = NRP.Progression or {}
local Prog = NRP.Progression
local Char = NRP.Char

local function Cfg()
    return NRP.Config.Progression
end

Char.RegisterField("level", { type = "int", default = 1, nw = "Int", nwKey = "NRP_Level" })
Char.RegisterField("xp", { type = "int", default = 0 })
Char.RegisterField("rank", { type = "string", default = "academy", nw = "String", nwKey = "NRP_Rank" })
Char.RegisterField("statPoints", { type = "int", default = 0 })
Char.RegisterField("stats", { type = "json", default = {} })

function Prog.XPForLevel(level)
    local cfg = Cfg()
    return math.floor(cfg.XPBase * math.max(1, level) ^ cfg.XPExponent)
end

function Prog.StatPointsForLevel(level)
    return (math.max(1, level) - 1) * Cfg().StatPointsPerLevel
end

function Prog.ClanPointsForLevel(level)
    return (Cfg().ClanPointsStart or 0) + math.floor(math.max(1, level) / math.max(1, Cfg().ClanPointsEvery))
end

---------------------------------------------------------------------------
-- Grades
---------------------------------------------------------------------------

NRP.Ranks = NRP.Ranks or {}
local Ranks = NRP.Ranks

Ranks.Registry = NRP.CreateRegistry("ranks", {
    validate = function(def) return isstring(def.name), "nom manquant" end,
})

for i, def in ipairs(NRP.Config.Ranks) do
    def.order = def.order or i
    Ranks.Registry:Register(def.id, def)
end

function Ranks.Get(id)
    return Ranks.Registry:Get(id)
end

function Ranks.GetOrder(id)
    local def = Ranks.Registry:Get(id)
    return def and def.order or 0
end

function Ranks.GetName(id)
    local def = Ranks.Registry:Get(id)
    return def and def.name or tostring(id)
end

function Ranks.GetPlayerRank(ply)
    return Ranks.Registry:Get(ply:GetNW2String("NRP_Rank", ""))
end

function Ranks.HasPermission(ply, perm)
    local rank = Ranks.GetPlayerRank(ply)
    return rank ~= nil and rank.permissions ~= nil and rank.permissions[perm] == true
end

-- Le grade peut-il accéder à une mission de ce rang ?
function Ranks.CanAccessMissionRank(rankId, missionRank)
    local rank = Ranks.Registry:Get(rankId)
    if not rank then return false end
    local ranks = NRP.Config.MissionSettings.Ranks
    local max = ranks[rank.maxMissionRank or "D"]
    local wanted = ranks[missionRank]
    return max ~= nil and wanted ~= nil and wanted.order <= max.order
end

function Ranks.Sorted()
    return Ranks.Registry:Sorted("order")
end

---------------------------------------------------------------------------
-- Titre de réputation / progression affichable
---------------------------------------------------------------------------

function Prog.GetLevelProgress(data)
    if not data then return 0, 1 end
    local need = Prog.XPForLevel(data.level or 1)
    return data.xp or 0, need
end
