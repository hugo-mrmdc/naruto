--[[
    Module : Dojutsu (partagé)

    Données : char.dojutsu = { sharingan = 3 }  (stade maximum débloqué)
    Actif    : NW2String "NRP_Dojutsu" = "sharingan:2" (visible de tous pour le rendu des yeux)
    Ajouter un dojutsu : config/dojutsu.lua ou NRP.Dojutsu.Registry:Register(id, def)
]]

NRP.Dojutsu = NRP.Dojutsu or {}
local Dojutsu = NRP.Dojutsu

Dojutsu.Registry = NRP.CreateRegistry("dojutsu", {
    defaults = { activationCost = 10, cooldown = 3, stages = {}, eye = {} },
    validate = function(def)
        if not isstring(def.name) then return false, "nom manquant" end
        if #def.stages == 0 then return false, "aucun stade" end
        for _, stage in ipairs(def.stages) do
            stage.unlock = stage.unlock or "level"
            stage.level = stage.level or 1
            stage.drain = stage.drain or 1
            stage.modifiers = stage.modifiers or {}
            stage.jutsus = stage.jutsus or {}
            stage.hud = stage.hud or {}
        end
        return true
    end,
})

Dojutsu.Registry:RegisterAll(NRP.Config.Dojutsu)

NRP.Char.RegisterField("dojutsu", { type = "json", default = {} })
NRP.Keys.Register("dojutsu", { name = "Activer / désactiver le dojutsu", default = KEY_P, order = 30 })

function Dojutsu.GetActive(ply)
    local value = ply:GetNW2String("NRP_Dojutsu", "")
    if value == "" then return nil end
    local id, stage = string.match(value, "^([%w_]+):(%d+)$")
    if not id then return nil end
    return id, tonumber(stage), Dojutsu.Registry:Get(id)
end

function Dojutsu.IsActive(ply, id, minStage)
    local activeId, stage = Dojutsu.GetActive(ply)
    if not activeId then return false end
    if id and activeId ~= id then return false end
    return stage >= (minStage or 1)
end

function Dojutsu.GetStage(id, stage)
    local def = Dojutsu.Registry:Get(id)
    return def and def.stages[stage]
end

function Dojutsu.GetUnlocked(data, id)
    return tonumber(data and data.dojutsu and data.dojutsu[id]) or 0
end

-- Dojutsu et stade utilisés à l'activation (préférence du joueur, sinon le plus haut)
function Dojutsu.GetPreferred(data)
    if not data then return nil end
    local pref = data.flags and data.flags.dojutsuPref
    if istable(pref) and Dojutsu.GetUnlocked(data, pref.id) > 0 then
        return pref.id, math.Clamp(tonumber(pref.stage) or 99, 1, Dojutsu.GetUnlocked(data, pref.id))
    end

    for id in Dojutsu.Registry:Iterate() do
        local unlocked = Dojutsu.GetUnlocked(data, id)
        if unlocked > 0 then
            return id, unlocked
        end
    end
end
