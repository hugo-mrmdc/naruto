--[[
    Module : clans (partagé)

    Ajouter un clan : une entrée dans config/clans.lua, ou
        NRP.Clans.Registry:Register("senju", { name = "Senju", ... })
    Les techniques exclusives se déclarent côté jutsu avec requirements = { clan = "senju" }.
]]

NRP.Clans = NRP.Clans or {}
local Clans = NRP.Clans
local Char = NRP.Char

Clans.Registry = NRP.CreateRegistry("clans", {
    defaults = { selectable = false, stats = {}, derived = {}, passives = {}, tree = {}, color = Color(200, 200, 200) },
    validate = function(def)
        if not isstring(def.name) then return false, "nom manquant" end
        def.nodes = {}
        for _, node in ipairs(def.tree) do
            if not NRP.Util.IsValidId(node.id) then return false, "nœud invalide" end
            node.cost = node.cost or 1
            node.level = node.level or 1
            node.requires = node.requires or {}
            node.rewards = node.rewards or {}
            def.nodes[node.id] = node
        end
        return true
    end,
})

Clans.Registry:RegisterAll(NRP.Config.Clans)

Char.RegisterField("clan", { type = "string", default = "", nw = "String", nwKey = "NRP_Clan" })
Char.RegisterField("clanTree", { type = "json", default = {} })

function Clans.Get(id)
    return Clans.Registry:Get(id)
end

function Clans.GetName(id)
    local def = Clans.Registry:Get(id)
    return def and def.name or NRP.Config.ClanSettings.NoClanName
end

-- Choix à la création : vrai ou faux, raison. Les quotas ne sont connus que du serveur.
function Clans.CanChoose(clanId, villageId)
    local def = Clans.Registry:Get(clanId)
    if not def then return false, "Clan inconnu." end
    if not def.selectable then return false, "Ce clan ne peut pas être choisi à la création." end

    if def.villages and not table.HasValue(def.villages, villageId) then
        return false, "Ce clan n'existe pas dans ce village."
    end

    if SERVER and def.maxMembers and (Clans.Counts[clanId] or 0) >= def.maxMembers then
        return false, "Ce clan est complet."
    end

    return true
end

-- Somme des bonus du clan et des nœuds débloqués, sous forme de modificateurs
function Clans.BuildModifiers(data)
    local mods = {}
    local def = Clans.Registry:Get(data and data.clan)
    if not def then return mods end

    local function AddStats(stats)
        for key, value in pairs(stats or {}) do
            mods[key] = mods[key] or { add = 0, mul = 0 }
            mods[key].add = mods[key].add + value
        end
    end

    local function AddDerived(derived)
        for key, m in pairs(derived or {}) do
            mods[key] = mods[key] or { add = 0, mul = 0 }
            mods[key].add = mods[key].add + (m.add or 0)
            mods[key].mul = mods[key].mul + (m.mul or 0)
        end
    end

    AddStats(def.stats)
    AddDerived(def.derived)

    for nodeId in pairs(data.clanTree or {}) do
        local node = def.nodes[nodeId]
        if node then
            AddStats(node.rewards.stats)
            AddDerived(node.rewards.derived)
        end
    end

    return mods
end

-- Nœud débloquable ? (vrai ou faux, raison)
function Clans.CanUnlockNode(data, nodeId)
    local def = Clans.Registry:Get(data and data.clan)
    if not def then return false, "Vous n'avez pas de clan." end

    local node = def.nodes[nodeId]
    if not node then return false, "Nœud inconnu." end
    if data.clanTree[nodeId] then return false, "Déjà débloqué." end
    if (data.level or 1) < node.level then return false, "Niveau " .. node.level .. " requis." end

    for _, req in ipairs(node.requires) do
        if not data.clanTree[req] then
            local parent = def.nodes[req]
            return false, "Requiert : " .. (parent and parent.name or req)
        end
    end

    if (data.statPoints or 0) < node.cost then
        return false, "Points de statistiques insuffisants (" .. node.cost .. ")."
    end
    return true
end
