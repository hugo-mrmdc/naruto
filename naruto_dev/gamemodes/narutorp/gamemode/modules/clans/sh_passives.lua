--[[
    Module : capacités passives (partagé, effets côté serveur)

    Un passif est une définition + des paramètres fournis par le clan ou l'arbre :
        passives = { { id = "element_mastery", element = "katon", mul = 0.15 } }

    Ajouter un passif :
        NRP.Passives.Registry:Register("mon_passif", {
            name = "Nom",
            describe = function(p) return "texte" end,
            ScaleDamage = function(owner, p, victim, info, role) end,  -- role : "attacker" | "victim"
            OnHit = function(owner, p, victim, info, amount, role) end,
        })
]]

NRP.Passives = NRP.Passives or {}
local Passives = NRP.Passives

Passives.Registry = NRP.CreateRegistry("passives")

Passives.Registry:Register("element_mastery", {
    name = "Maîtrise élémentaire",
    describe = function(p)
        local e = NRP.Elements:Get(p.element)
        return string.format("+%d%% dégâts %s", (p.mul or 0) * 100, e and e.name or tostring(p.element))
    end,
    ScaleDamage = function(owner, p, victim, info, role)
        if role == "attacker" and info.element == p.element then
            info.amount = info.amount * (1 + (p.mul or 0))
        end
    end,
})

Passives.Registry:Register("damage_reduction", {
    name = "Corps résistant",
    describe = function(p)
        return string.format("-%d%% dégâts subis (%s)", (p.mul or 0) * 100, p.kind or "tous")
    end,
    ScaleDamage = function(owner, p, victim, info, role)
        if role == "victim" and (not p.kind or info.kind == p.kind) then
            info.amount = info.amount * (1 - (p.mul or 0))
        end
    end,
})

Passives.Registry:Register("gentle_fist", {
    name = "Jūken",
    describe = function(p)
        return "Vos coups au corps à corps drainent " .. (p.drain or 0) .. " chakra"
    end,
    OnHit = function(owner, p, victim, info, amount, role)
        if role == "attacker" and info.kind == "melee" and victim:IsPlayer() and amount > 0 then
            NRP.Chakra.Drain(victim, p.drain or 4)
        end
    end,
})

Passives.Registry:Register("chakra_leech", {
    name = "Insectes parasites",
    describe = function(p)
        return "Vos coups volent " .. (p.amount or 0) .. " chakra à la cible"
    end,
    OnHit = function(owner, p, victim, info, amount, role)
        if role == "attacker" and info.kind == "melee" and victim:IsPlayer() and amount > 0 then
            local stolen = NRP.Chakra.Drain(victim, p.amount or 3)
            NRP.Chakra.Add(owner, stolen)
        end
    end,
})

Passives.Registry:Register("keen_senses", {
    name = "Flair",
    describe = function(p)
        return "Repère les ninjas proches (" .. math.floor((p.radius or 0) / 52) .. " m)"
    end,
    -- Effet purement client (voir cl_clans.lua)
})

-- Liste { def, params } des passifs d'un personnage
function Passives.Collect(data)
    local out = {}
    local clan = NRP.Clans.Registry:Get(data and data.clan)
    if not clan then return out end

    local function Add(list)
        for _, params in ipairs(list or {}) do
            local def = Passives.Registry:Get(params.id)
            if def then
                out[#out + 1] = { def = def, params = params }
            end
        end
    end

    Add(clan.passives)
    for nodeId in pairs(data.clanTree or {}) do
        local node = clan.nodes[nodeId]
        if node then Add(node.rewards.passives) end
    end
    return out
end

function Passives.Has(ply, passiveId)
    local list
    if SERVER then
        list = ply.NRPPassives
    else
        list = Passives.Collect(NRP.Char.GetData(ply))
    end
    for _, entry in ipairs(list or {}) do
        if entry.def.id == passiveId then
            return entry.params
        end
    end
end

if SERVER then
    function Passives.Refresh(ply)
        ply.NRPPassives = Passives.Collect(ply.NRPChar)
    end

    local function Dispatch(ply, method, role, ...)
        for _, entry in ipairs(ply.NRPPassives or {}) do
            local fn = entry.def[method]
            if fn then
                fn(ply, entry.params, ...)
            end
        end
    end

    hook.Add("NRP.ScaleDamage", "NRP.Passives", function(victim, info)
        local attacker = info.attacker
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
            for _, entry in ipairs(attacker.NRPPassives or {}) do
                if entry.def.ScaleDamage then
                    entry.def.ScaleDamage(attacker, entry.params, victim, info, "attacker")
                end
            end
        end
        if victim:IsPlayer() then
            for _, entry in ipairs(victim.NRPPassives or {}) do
                if entry.def.ScaleDamage then
                    entry.def.ScaleDamage(victim, entry.params, victim, info, "victim")
                end
            end
        end
    end)

    hook.Add("NRP.PostDamage", "NRP.Passives", function(victim, info, amount)
        local attacker = info.attacker
        if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
            for _, entry in ipairs(attacker.NRPPassives or {}) do
                if entry.def.OnHit then
                    entry.def.OnHit(attacker, entry.params, victim, info, amount, "attacker")
                end
            end
        end
        if victim:IsPlayer() then
            Dispatch(victim, "OnHit", "victim", victim, info, amount, "victim")
        end
    end)
end
