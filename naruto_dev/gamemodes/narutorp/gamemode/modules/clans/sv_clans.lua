--[[
    Module : clans (serveur)

        NRP.Clans.SetClan(ply, "hyuga", admin)     -- "" pour retirer
        NRP.Clans.UnlockNode(ply, "hyuga_juken")
        NRP.Clans.AddPoints(ply, 2)

    Hooks : "NRP.ClanChanged"(ply, new, old), "NRP.ClanNodeUnlocked"(ply, nodeId)
]]

local Clans = NRP.Clans
local Char = NRP.Char
local Prog = NRP.Progression
local Passives = NRP.Passives

Clans.Counts = Clans.Counts or {}

local function SpentPoints(data)
    local def = Clans.Registry:Get(data.clan)
    local spent = 0
    if def then
        for nodeId in pairs(data.clanTree) do
            local node = def.nodes[nodeId]
            spent = spent + (node and node.cost or 0)
        end
    end
    return spent
end

local function TotalPoints(ply, data)
    return Prog.ClanPointsForLevel(data.level) + Char.GetFlag(ply, "bonusClanPoints", 0)
end

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
    data.clanPoints = Prog.ClanPointsForLevel(data.level or 1)

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

hook.Add("NRP.LevelUp", "NRP.Clans.Points", function(ply, newLevel, oldLevel)
    local gained = Prog.ClanPointsForLevel(newLevel) - Prog.ClanPointsForLevel(oldLevel)
    if gained > 0 then
        Char.Set(ply, "clanPoints", ply.NRPChar.clanPoints + gained)
        NRP.Notify(ply, "+" .. gained .. " point(s) de clan", NRP.NOTIFY_SUCCESS)
    end
end)

hook.Add("NRP.LevelSet", "NRP.Clans.Points", function(ply)
    local data = ply.NRPChar
    Char.Set(ply, "clanPoints", math.max(0, TotalPoints(ply, data) - SpentPoints(data)))
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

    data.clanTree = {}
    Char.Touch(ply, "clanTree")
    Char.Set(ply, "clanPoints", TotalPoints(ply, data))
    Char.Set(ply, "clan", clanId)

    Clans.Apply(ply)
    hook.Run("NRP.ClanChanged", ply, clanId, old)

    NRP.LogAction("clan", actor, ply, (old ~= "" and old or "aucun") .. " -> " .. (clanId ~= "" and clanId or "aucun"))
    NRP.Announce("Clan", "Vous appartenez désormais au clan " .. Clans.GetName(clanId), (Clans.Get(clanId) or {}).color, 5, ply)
    return true
end

function Clans.AddPoints(ply, amount)
    if not ply.NRPChar then return end
    Char.SetFlag(ply, "bonusClanPoints", Char.GetFlag(ply, "bonusClanPoints", 0) + amount)
    Char.Set(ply, "clanPoints", math.max(0, ply.NRPChar.clanPoints + amount))
end

function Clans.UnlockNode(ply, nodeId)
    local data = ply.NRPChar
    local ok, reason = Clans.CanUnlockNode(data, nodeId)
    if not ok then return false, reason end

    local def = Clans.Registry:Get(data.clan)
    local node = def.nodes[nodeId]

    data.clanTree[nodeId] = true
    Char.Touch(ply, "clanTree")
    Char.Set(ply, "clanPoints", data.clanPoints - node.cost)

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

NRP.Commands.Add("clanpoints", {
    perm = "admin.clan", usage = "clanpoints <joueur> <points>", description = "Donner des points de clan",
    args = { "player", "number" },
    run = function(caller, target, amount)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        Clans.AddPoints(target, math.floor(amount))
        NRP.LogAction("admin", caller, target, "points de clan " .. amount)
        return true, amount .. " point(s) de clan donnés à " .. target:Nick()
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
