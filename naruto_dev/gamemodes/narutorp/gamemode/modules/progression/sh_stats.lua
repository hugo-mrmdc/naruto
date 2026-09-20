--[[
    Module : statistiques (partagé)

    Statistiques effectives = (points investis + add) * (1 + mul)
    Valeurs dérivées        = (formule(stats) + add) * (1 + mul)

    Les modificateurs sont indexés par source ("clan", "equip", "dojutsu", "buff:xxx"...) :
        NRP.Stats.SetModifier(ply, "equip", { maxHealth = { add = 30 }, runSpeed = { mul = -0.05 } })
        NRP.Stats.RemoveModifier(ply, "equip")
        NRP.Stats.Get(ply, "jutsuPower")
]]

NRP.Stats = NRP.Stats or {}
local Stats = NRP.Stats

Stats.Defs = NRP.CreateRegistry("stats", {
    validate = function(def) return isstring(def.name), "nom manquant" end,
})

for i, def in ipairs(NRP.Config.Stats) do
    def.order = i
    Stats.Defs:Register(def.id, def)
end

Stats.Derived = NRP.Config.Derived

-- Additionne des modificateurs { source = { clé = { add, mul } } }
function Stats.SumModifiers(modifiers)
    local add, mul = {}, {}
    for _, mods in pairs(modifiers or {}) do
        for key, m in pairs(mods) do
            if istable(m) then
                add[key] = (add[key] or 0) + (tonumber(m.add) or 0)
                mul[key] = (mul[key] or 0) + (tonumber(m.mul) or 0)
            end
        end
    end
    return add, mul
end

function Stats.Compute(allocated, modifiers)
    local add, mul = Stats.SumModifiers(modifiers)
    local s = {}

    for id in Stats.Defs:Iterate() do
        s[id] = ((tonumber(allocated and allocated[id]) or 0) + (add[id] or 0)) * (1 + (mul[id] or 0))
    end

    local d = {}
    for key, def in pairs(Stats.Derived) do
        local ok, base = pcall(def.fn, s)
        if not ok then
            NRP.Error("Formule dérivée '" .. key .. "' :", base)
            base = 0
        end
        d[key] = ((tonumber(base) or 0) + (add[key] or 0)) * (1 + (mul[key] or 0))
    end

    return s, d
end

local baseline
function Stats.Baseline()
    if not baseline then
        local _, d = Stats.Compute({}, {})
        baseline = d
    end
    return baseline
end

function Stats.Get(ply, key)
    local derived
    if SERVER then
        derived = ply.NRPDerived
    elseif ply == LocalPlayer() then
        derived = Stats.LocalDerived
    end
    local value = derived and derived[key]
    if value == nil then
        value = Stats.Baseline()[key] or 0
    end
    return value
end

function Stats.GetStat(ply, id)
    local stats
    if SERVER then
        stats = ply.NRPStats
    elseif ply == LocalPlayer() then
        stats = Stats.LocalStats
    end
    return stats and stats[id] or 0
end
