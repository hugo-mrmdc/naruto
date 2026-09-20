--[[
    Module : framework des Jutsu (partagé)

    Un jutsu = une définition de config (config/jutsu.lua) + un archetype qui fournit le
    comportement. Ajouter un jutsu :
        - le plus souvent : une entrée dans config/jutsu.lua avec un archetype existant ;
        - ailleurs (addon, fichier custom) : NRP.Jutsu.Registry:Register("id", { ... }) ;
        - comportement unique : OnCast = function(ply, jutsu, ctx) ... return true end.

    Ajouter un archetype : NRP.Jutsu.RegisterArchetype("nom", {
        CanCast = function(ply, jutsu) return true end,          -- optionnel (serveur)
        Execute = function(ply, jutsu, ctx) return true end,     -- serveur, false = annulé (remboursé)
    })
    ctx = { power, aim, eye, cost }
]]

NRP.Jutsu = NRP.Jutsu or {}
local Jutsu = NRP.Jutsu
local Char = NRP.Char

Jutsu.Archetypes = Jutsu.Archetypes or {}

function Jutsu.RegisterArchetype(id, def)
    local existing = Jutsu.Archetypes[id] or { id = id }
    for k, v in pairs(def) do
        existing[k] = v
    end
    Jutsu.Archetypes[id] = existing
end

Jutsu.Categories = NRP.CreateRegistry("jutsu_categories")
Jutsu.Categories:RegisterAll(NRP.Config.JutsuCategories)

Jutsu.Registry = NRP.CreateRegistry("jutsu", {
    defaults = {
        chakra = 0,
        cooldown = 1,
        castTime = 0,
        category = "special",
        unlock = "auto",
        requirements = {},
        rootWhileCasting = true,
        interruptible = true,
        description = "",
        color = Color(255, 255, 255),
    },
    validate = function(def)
        if not isstring(def.name) then return false, "nom manquant" end
        if not def.archetype and not def.OnCast then return false, "archetype ou OnCast requis" end
        if not NRP.Jutsu.Categories:Exists(def.category) then return false, "catégorie inconnue " .. tostring(def.category) end
        return true
    end,
})

Jutsu.Registry:RegisterAll(NRP.Config.Jutsu)

function Jutsu.Get(id)
    return Jutsu.Registry:Get(id)
end

function Jutsu.SlotCount()
    return NRP.Config.JutsuSettings.LoadoutSlots
end

Char.RegisterField("jutsus", { type = "json", default = {} })
Char.RegisterField("loadout", { type = "json", default = {} })

NRP.Keys.Register("cast", { name = "Lancer le jutsu sélectionné", default = MOUSE_MIDDLE, order = 1, clientOnly = true })

---------------------------------------------------------------------------
-- Conditions
---------------------------------------------------------------------------

local function MatchesAny(value, wanted)
    if istable(wanted) then
        for _, w in ipairs(wanted) do
            if w == value then return true end
        end
        return false
    end
    return value == wanted
end

local function ListNames(registry, wanted)
    local ids = istable(wanted) and wanted or { wanted }
    local names = {}
    for _, id in ipairs(ids) do
        local def = registry and registry:Get(id)
        names[#names + 1] = def and def.name or tostring(id)
    end
    return table.concat(names, " / ")
end

function Jutsu.Knows(data, id)
    return data ~= nil and data.jutsus ~= nil and data.jutsus[id] == true
end

--[[
    Vérifie les conditions d'un jutsu pour des données de personnage.
    ply est optionnel (nécessaire pour les conditions "dojutsu actif").
    Retourne true ou false, raison.
]]
function Jutsu.CheckRequirements(data, jutsu, ply, ignoreActive)
    if not data then return false, "Aucun personnage" end
    local req = jutsu.requirements or {}

    if req.level and (data.level or 1) < req.level then
        return false, "Niveau " .. req.level .. " requis"
    end

    if req.rank and NRP.Ranks.GetOrder(data.rank) < NRP.Ranks.GetOrder(req.rank) then
        return false, "Grade " .. NRP.Ranks.GetName(req.rank) .. " requis"
    end

    if req.affinity then
        local ok = false
        for _, element in ipairs(data.affinities or {}) do
            if MatchesAny(element, req.affinity) then ok = true break end
        end
        if not ok then
            return false, "Affinité " .. ListNames(NRP.Elements, req.affinity) .. " requise"
        end
    end

    if req.clan and not MatchesAny(data.clan, req.clan) then
        return false, "Réservé au clan " .. ListNames(NRP.Clans and NRP.Clans.Registry, req.clan)
    end

    for statId, min in pairs(req.stats or {}) do
        if (tonumber(data.stats and data.stats[statId]) or 0) < min then
            local def = NRP.Stats.Defs:Get(statId)
            return false, (def and def.name or statId) .. " " .. min .. " requis"
        end
    end

    if req.dojutsu then
        local d = req.dojutsu
        local unlocked = tonumber(data.dojutsu and data.dojutsu[d.id]) or 0
        local dojutsuDef = NRP.Dojutsu and NRP.Dojutsu.Registry:Get(d.id)
        local name = dojutsuDef and dojutsuDef.name or d.id
        if unlocked < (d.stage or 1) then
            return false, name .. " (stade " .. (d.stage or 1) .. ") requis"
        end
        if d.active and not ignoreActive and ply and not NRP.Dojutsu.IsActive(ply, d.id, d.stage) then
            return false, name .. " doit être activé"
        end
    end

    if jutsu.CanLearn then
        local ok, reason = jutsu.CanLearn(data, ply)
        if ok == false then return false, reason end
    end

    return true
end

---------------------------------------------------------------------------
-- Valeurs effectives
---------------------------------------------------------------------------

function Jutsu.GetCost(ply, jutsu)
    local cost = (jutsu.chakra or 0) * NRP.Stats.Get(ply, "jutsuCost")
    return hook.Run("NRP.JutsuCost", ply, jutsu, cost) or cost
end

function Jutsu.GetCastTime(ply, jutsu)
    return (jutsu.castTime or 0) / math.max(0.2, NRP.Stats.Get(ply, "castSpeed"))
end

function Jutsu.GetCooldown(ply, jutsu)
    return hook.Run("NRP.JutsuCooldown", ply, jutsu, jutsu.cooldown) or jutsu.cooldown
end

function Jutsu.GetPower(ply, jutsu)
    local scaling = jutsu.scaling or "ninjutsu"
    local power

    if scaling == "melee" then
        power = NRP.Stats.Get(ply, "meleePower")
    elseif scaling == "genjutsu" then
        power = NRP.Stats.Get(ply, "genjutsuPower")
    elseif scaling == "control" then
        power = 1 + NRP.Stats.GetStat(ply, "control") * 0.015
    else
        power = NRP.Stats.Get(ply, "jutsuPower")
    end

    if jutsu.element then
        local data = Char.GetData(ply)
        if Char.PrimaryAffinity(data) == jutsu.element then
            power = power * NRP.Config.ElementSettings.PrimaryAffinityBonus
        end
    end

    return hook.Run("NRP.JutsuPower", ply, jutsu, power) or power
end

function Jutsu.IsCasting(ply)
    return ply:GetNW2Float("NRP_CastEnd", 0) > CurTime()
end

function Jutsu.GetCasting(ply)
    if not Jutsu.IsCasting(ply) then return nil end
    return Jutsu.Registry:Get(ply:GetNW2String("NRP_CastJutsu", ""))
end

-- Jutsu triés pour l'affichage
function Jutsu.SortedList()
    local list = {}
    for _, def in Jutsu.Registry:Iterate() do
        list[#list + 1] = def
    end
    table.sort(list, function(a, b)
        local ca = Jutsu.Categories:Get(a.category)
        local cb = Jutsu.Categories:Get(b.category)
        local oa, ob = ca and ca.order or 99, cb and cb.order or 99
        if oa ~= ob then return oa < ob end
        local la = a.requirements.level or 0
        local lb = b.requirements.level or 0
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
    return list
end
