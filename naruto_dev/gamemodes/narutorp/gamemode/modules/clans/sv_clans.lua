--[[
    Module : clans (serveur)

        NRP.Clans.SetClan(ply, "hyuga", admin)     -- "" pour retirer
        NRP.Clans.UnlockNode(ply, "hyuga_juken")   -- coûte des points de statistiques (NRP.Progression.AddStatPoints)

    Hooks : "NRP.ClanChanged"(ply, new, old), "NRP.ClanNodeUnlocked"(ply, nodeId)
]]

local Clans = NRP.Clans
local Char = NRP.Char
local Prog = NRP.Progression
local Passives = NRP.Passives

Clans.Counts = Clans.Counts or {}

-- Applique bonus, passifs et affinité du clan
function Clans.Apply(ply)
    local data = ply.NRPChar
    if not data then return end

    NRP.Stats.SetModifier(ply, "clan", Clans.BuildModifiers(data))
    Passives.Refresh(ply)

    local def = Clans.Registry:Get(data.clan)
    if def and def.affinity and not Char.HasAffinity(data, def.affinity) then
        Char.AddAffinity(ply, def.affinity, true)
    end

    hook.Run("NRP.ClanApplied", ply, def)
end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------

hook.Add("NRP.InitCharacter", "NRP.Clans.Init", function(ply, data, req)
    data.clan = (req.clan and Clans.Registry:Exists(req.clan)) and req.clan or ""
    data.clanTree = {}

    if data.clan ~= "" and not data.isBot then
        Clans.Counts[data.clan] = (Clans.Counts[data.clan] or 0) + 1
    end

    local def = Clans.Registry:Get(data.clan)
    if def and def.affinity and not Char.HasAffinity(data, def.affinity) then
        table.insert(data.affinities, def.affinity)
    end
end)

hook.Add("NRP.PreCharacterLoaded", "NRP.Clans.Sanitize", function(ply, data)
    local def = Clans.Registry:Get(data.clan)
    if not def then
        data.clan = ""
        data.clanTree = {}
        return
    end
    for nodeId in pairs(data.clanTree) do
        if not def.nodes[nodeId] then
            data.clanTree[nodeId] = nil
        end
    end
end)

hook.Add("NRP.CharacterLoaded", "NRP.Clans.Apply", Clans.Apply)

hook.Add("NRP.CharacterUnloaded", "NRP.Clans.Unload", function(ply)
    ply.NRPPassives = nil
end)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function Clans.SetClan(ply, clanId, actor)
    local data = ply.NRPChar
    if not data then return false, "Aucun personnage." end
    clanId = clanId or ""
    if clanId ~= "" and not Clans.Registry:Exists(clanId) then
        return false, "Clan inconnu."
    end

    local old = data.clan
    if old == clanId then return true end

    -- Retire les techniques exclusives de l'ancien clan
    if old ~= "" then
        for id, jutsu in NRP.Jutsu.Registry:Iterate() do
            local reqClan = jutsu.requirements.clan
            if data.jutsus[id] and (reqClan == old or (istable(reqClan) and table.HasValue(reqClan, old))) then
                NRP.Jutsu.Forget(ply, id)
            end
        end
        Clans.Counts[old] = math.max(0, (Clans.Counts[old] or 1) - 1)
    end
    if clanId ~= "" then
        Clans.Counts[clanId] = (Clans.Counts[clanId] or 0) + 1
    end

    -- Rembourse les points de statistiques dépensés dans l'arbre de l'ancien clan
    local oldDef = Clans.Registry:Get(old)
    if oldDef then
        local refund = 0
        for nodeId in pairs(data.clanTree) do
            local node = oldDef.nodes[nodeId]
            refund = refund + (node and node.cost or 0)
        end
        if refund > 0 then
            Prog.AddStatPoints(ply, refund)
        end
    end

    data.clanTree = {}
    Char.Touch(ply, "clanTree")
    Char.Set(ply, "clan", clanId)

    Clans.Apply(ply)
    hook.Run("NRP.ClanChanged", ply, clanId, old)

    NRP.LogAction("clan", actor, ply, (old ~= "" and old or "aucun") .. " -> " .. (clanId ~= "" and clanId or "aucun"))
    NRP.Announce("Clan", "Vous appartenez désormais au clan " .. Clans.GetName(clanId), (Clans.Get(clanId) or {}).color, 5, ply)
    return true
end

function Clans.UnlockNode(ply, nodeId)
    local data = ply.NRPChar
    local ok, reason = Clans.CanUnlockNode(data, nodeId)
    if not ok then return false, reason end

    local def = Clans.Registry:Get(data.clan)
    local node = def.nodes[nodeId]

    data.clanTree[nodeId] = true
    Char.Touch(ply, "clanTree")
    Char.Set(ply, "statPoints", data.statPoints - node.cost)

    local rewards = node.rewards
    if rewards.jutsu then
        NRP.Jutsu.Learn(ply, rewards.jutsu, { force = true, source = "clan" })
    end
    if rewards.affinity then
        Char.AddAffinity(ply, rewards.affinity)
    end
    for dojutsuId, stage in pairs(rewards.dojutsuStage or {}) do
        NRP.Dojutsu.UnlockStage(ply, dojutsuId, stage)
    end

    Clans.Apply(ply)
    hook.Run("NRP.ClanNodeUnlocked", ply, nodeId)
    NRP.Notify(ply, "Débloqué : " .. node.name, NRP.NOTIFY_SUCCESS)
    return true
end

NRP.Net.Receive("UnlockClanNode", function(ply)
    local nodeId = NRP.Net.ReadId()
    if not nodeId then return end
    local ok, err = Clans.UnlockNode(ply, nodeId)
    if not ok then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR)
    end
end, { rate = 2, burst = 4, maxBytes = 96 })

-- Effectifs par clan (quotas de création)
hook.Add("NRP.DatabaseReady", "NRP.Clans.Counts", function()
    local DB = NRP.DB
    DB.Query("SELECT clan, COUNT(*) AS n FROM " .. DB.Ident(DB.Table(Char.TABLE)) .. " GROUP BY clan", nil, function(rows)
        Clans.Counts = {}
        for _, row in ipairs(rows) do
            if row.clan and row.clan ~= "" then
                Clans.Counts[row.clan] = tonumber(row.n) or 0
            end
        end
    end)
end)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

NRP.Commands.Add("setclan", {
    perm = "admin.clan", usage = "setclan <joueur> <clan|none>", description = "Attribuer un clan",
    args = { "player", "string" },
    run = function(caller, target, clanId)
        if clanId == "none" then clanId = "" end
        local ok, err = Clans.SetClan(target, clanId, caller)
        if not ok then return false, err end
        return true, target:Nick() .. " -> " .. Clans.GetName(clanId)
    end,
})

NRP.Commands.Add("clans", {
    description = "Liste des clans",
    run = function()
        local parts = {}
        for id, def in Clans.Registry:Iterate() do
            parts[#parts + 1] = id .. " (" .. def.name .. ", " .. (Clans.Counts[id] or 0) .. (def.maxMembers and ("/" .. def.maxMembers) or "") .. ")"
        end
        return true, table.concat(parts, ", ")
    end,
})
