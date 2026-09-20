--[[
    Module : villages (serveur) - relations, guerres, réputation, déserteurs, points d'apparition

        NRP.Villages.SetRelation("konoha", "kumo", "war", admin)
        NRP.Villages.AddReputation(ply, "konoha", 10)
        NRP.Villages.SetDeserter(ply, true, admin)
        NRP.Villages.SetVillage(ply, "suna", admin)
]]

local Villages = NRP.Villages
local Char = NRP.Char
local DB = NRP.DB

Villages.Spawns = Villages.Spawns or {}
Villages.WarScores = Villages.WarScores or {}

NRP.Net.Pool("Relations")

local function Settings()
    return NRP.Config.VillageSettings
end

DB.RegisterTable("village_relations", {
    columns = { { "a", "string", "" }, { "b", "string", "" }, { "status", "string", "neutral" } },
    primary = { "a", "b" },
})

DB.RegisterTable("spawns", {
    columns = {
        { "id", "id" }, { "map", "string", "" }, { "village", "string", "" },
        { "x", "float", 0 }, { "y", "float", 0 }, { "z", "float", 0 }, { "yaw", "float", 0 },
    },
    primary = { "id" },
    indexes = { { "map" } },
})

---------------------------------------------------------------------------
-- Relations
---------------------------------------------------------------------------

function Villages.BroadcastRelations(target)
    NRP.Net.Start("Relations")
        NRP.Net.WriteTable({ relations = Villages.Relations, wars = Villages.WarScores })
    if target then net.Send(target) else net.Broadcast() end
end

local function SaveRelation(a, b, status)
    if a > b then a, b = b, a end
    DB.Replace("village_relations", { a = a, b = b, status = status })
end

hook.Add("NRP.DatabaseReady", "NRP.Villages.Load", function()
    DB.Select("village_relations", nil, function(rows)
        Villages.Relations = {}
        for _, row in ipairs(rows) do
            if Villages.RelationTypes[row.status] then
                Villages.Relations[Villages.RelationKey(row.a, row.b)] = row.status
            end
        end

        if #rows == 0 then
            for _, rel in ipairs(Settings().InitialRelations or {}) do
                Villages.Relations[Villages.RelationKey(rel[1], rel[2])] = rel[3]
                SaveRelation(rel[1], rel[2], rel[3])
            end
        end
        Villages.BroadcastRelations()
    end)

    Villages.LoadSpawns()
end)

function Villages.SetRelation(a, b, status, actor)
    if not Villages:Exists(a) or not Villages:Exists(b) or a == b then
        return false, "Villages invalides."
    end
    local relType = Villages.RelationTypes[status]
    if not relType then return false, "Statut inconnu." end

    local key = Villages.RelationKey(a, b)
    local old = Villages.Relations[key] or Settings().DefaultRelation
    if old == status then return true end

    Villages.Relations[key] = status
    if status == "war" then
        Villages.WarScores[key] = { [a] = 0, [b] = 0 }
    else
        Villages.WarScores[key] = nil
    end

    SaveRelation(a, b, status)
    Villages.BroadcastRelations()

    NRP.Announce(Villages:Get(a).name .. " & " .. Villages:Get(b).name, relType.name, relType.color, 8)
    NRP.LogAction("villages", actor, nil, a .. "/" .. b .. " : " .. old .. " -> " .. status)
    hook.Run("NRP.RelationChanged", a, b, status, old)
    return true
end

hook.Add("NRP.CharacterLoaded", "NRP.Villages.SendRelations", function(ply)
    Villages.BroadcastRelations(ply)
end)

-- Qui peut blesser qui ? (appelé par NRP.Combat.CanHarm)
hook.Add("NRP.CanHarm", "NRP.Villages.CanHarm", function(attacker, victim)
    if Char.IsDeserter(attacker) or Char.IsDeserter(victim) then
        return true
    end

    local va, vv = Char.GetVillage(attacker), Char.GetVillage(victim)
    if va == vv then
        return NRP.Config.Combat.SameVillageDamage == true
    end

    local relType = Villages.GetRelationType(va, vv)
    if relType and relType.canHarm == false then
        return false
    end
end)

---------------------------------------------------------------------------
-- Réputation
---------------------------------------------------------------------------

function Villages.AddReputation(ply, villageId, amount, silent)
    local data = ply.NRPChar
    if not data or not Villages:Exists(villageId) or amount == 0 then return end

    local cfg = Settings().Reputation
    local value = math.Clamp(Villages.GetReputation(data, villageId) + amount, cfg.Min, cfg.Max)
    data.reputation[villageId] = value
    Char.Touch(ply, "reputation")

    if not silent then
        NRP.Notify(ply, string.format("Réputation %s : %+d", Villages:Get(villageId).name, amount),
            amount > 0 and NRP.NOTIFY_SUCCESS or NRP.NOTIFY_WARNING, 2)
    end
end

hook.Add("PlayerDeath", "NRP.Villages.Kill", function(victim, inflictor, killer)
    if not IsValid(killer) or not killer:IsPlayer() or killer == victim then return end
    if not killer.NRPChar or not victim.NRPChar then return end

    local cfg = Settings().Reputation
    local vk, vv = Char.GetVillage(killer), Char.GetVillage(victim)
    local killerDeserter = Char.IsDeserter(killer)

    if not killerDeserter and not NRP.Combat.InDuel(killer, victim) then
        if Char.IsDeserter(victim) then
            Villages.AddReputation(killer, vk, cfg.KillDeserter)
        elseif vk == vv then
            Villages.AddReputation(killer, vk, cfg.KillSameVillage)
        else
            local relation = Villages.GetRelation(vk, vv)
            if relation == "ally" then
                Villages.AddReputation(killer, vk, cfg.KillAlly)
            elseif relation == "war" then
                Villages.AddReputation(killer, vk, cfg.KillAtWar)
                local score = Villages.WarScores[Villages.RelationKey(vk, vv)]
                if score then
                    score[vk] = (score[vk] or 0) + 1
                    if not timer.Exists("NRP.Villages.WarSync") then
                        timer.Create("NRP.Villages.WarSync", 5, 1, Villages.BroadcastRelations)
                    end
                end
            end
        end
    end

    Villages.ClaimBounties(killer, victim)
end)

---------------------------------------------------------------------------
-- Déserteurs et changement de village
---------------------------------------------------------------------------

function Villages.SetDeserter(ply, desert, actor, newVillage)
    local data = ply.NRPChar
    if not data then return false, "Aucun personnage." end

    if desert then
        if data.deserter then return false, "Déjà déserteur." end
        local origin = data.village
        Char.Set(ply, "originVillage", origin)
        Char.Set(ply, "village", "nukenin")
        Char.Set(ply, "deserter", true)
        NRP.Dojutsu.Deactivate(ply)

        local originDef = Villages:Get(origin)
        NRP.Announce("Déserteur !", ply:Nick() .. " a trahi " .. (originDef and originDef.name or origin),
            Color(200, 50, 50), 8)

        local bounty = Settings().Deserters.AutoBounty or 0
        if bounty > 0 then
            Villages.PlaceBounty(nil, ply, bounty, "Désertion", origin)
        end
    else
        if not data.deserter and not newVillage then return false, "Ce joueur n'est pas déserteur." end
        local village = newVillage or data.originVillage
        if not Villages:Exists(village) or village == "nukenin" then
            return false, "Village de retour invalide."
        end
        Char.Set(ply, "village", village)
        Char.Set(ply, "deserter", false)
        Char.Set(ply, "originVillage", "")
        NRP.Announce("Retour au village", "Vous appartenez de nouveau à " .. Villages:Get(village).name, Villages:Get(village).color, 6, ply)
    end

    NRP.LogAction("village", actor, ply, desert and "désertion" or ("retour -> " .. tostring(newVillage or data.village)))
    hook.Run("NRP.VillageChanged", ply, data.village)
    return true
end

function Villages.SetVillage(ply, villageId, actor)
    local data = ply.NRPChar
    if not data then return false, "Aucun personnage." end
    if villageId == "nukenin" then
        return Villages.SetDeserter(ply, true, actor)
    end
    if not Villages:Exists(villageId) then return false, "Village inconnu." end

    if data.deserter then
        return Villages.SetDeserter(ply, false, actor, villageId)
    end

    Char.Set(ply, "village", villageId)
    NRP.LogAction("village", actor, ply, "village -> " .. villageId)
    hook.Run("NRP.VillageChanged", ply, villageId)
    return true
end

---------------------------------------------------------------------------
-- Points d'apparition
---------------------------------------------------------------------------

function Villages.LoadSpawns()
    DB.Select("spawns", { map = game.GetMap() }, function(rows)
        Villages.Spawns = {}
        for _, row in ipairs(rows) do
            local list = Villages.Spawns[row.village] or {}
            list[#list + 1] = {
                id = tonumber(row.id),
                pos = Vector(tonumber(row.x), tonumber(row.y), tonumber(row.z)),
                yaw = tonumber(row.yaw) or 0,
            }
            Villages.Spawns[row.village] = list
        end
    end)
end

hook.Add("NRP.PostSpawnStats", "NRP.Villages.Spawn", function(ply)
    local list = Villages.Spawns[Char.GetVillage(ply)]
    if not list or #list == 0 then return end

    local spawn = list[math.random(#list)]
    local pos = spawn.pos + Vector(math.Rand(-40, 40), math.Rand(-40, 40), 4)
    if not NRP.Util.IsHullFree(pos, ply) then pos = spawn.pos + Vector(0, 0, 4) end

    ply:SetPos(pos)
    ply:SetEyeAngles(Angle(0, spawn.yaw, 0))
end)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

NRP.Commands.Add("relation", {
    perm = "admin.villages", usage = "relation <village> <village> <ally|neutral|tension|war>", description = "Modifier une relation entre villages",
    args = { "string", "string", "string" },
    run = function(caller, a, b, status)
        local ok, err = Villages.SetRelation(a, b, status, caller)
        if not ok then return false, err end
        return true, "Relation mise à jour."
    end,
})

NRP.Commands.Add("setvillage", {
    perm = "admin.village", usage = "setvillage <joueur> <village>", description = "Changer le village d'un joueur",
    args = { "player", "string" },
    run = function(caller, target, village)
        local ok, err = Villages.SetVillage(target, village, caller)
        if not ok then return false, err end
        return true, target:Nick() .. " -> " .. village
    end,
})

NRP.Commands.Add("setdeserter", {
    perm = "admin.village", usage = "setdeserter <joueur> <1|0>", description = "Marquer / gracier un déserteur",
    args = { "player", "number" },
    run = function(caller, target, value)
        local ok, err = Villages.SetDeserter(target, value == 1, caller)
        if not ok then return false, err end
        return true
    end,
})

NRP.Commands.Add("deserter", {
    needChar = true, description = "Déserter votre village (définitif, confirmation requise)",
    run = function(caller)
        local cfg = Settings().Deserters
        if not cfg.AllowSelfDesert then return false, "La désertion volontaire est désactivée." end
        if caller.NRPChar.deserter then return false, "Vous êtes déjà déserteur." end
        if caller.NRPChar.level < (cfg.MinLevel or 1) then return false, "Niveau " .. cfg.MinLevel .. " requis." end

        if (caller.NRPDesertConfirm or 0) < CurTime() then
            caller.NRPDesertConfirm = CurTime() + 15
            return true, "Retapez !deserter dans les 15 secondes pour confirmer. Une prime sera placée sur votre tête."
        end
        caller.NRPDesertConfirm = nil
        return Villages.SetDeserter(caller, true, caller)
    end,
})

NRP.Commands.Add("rep", {
    perm = "admin.reputation", usage = "rep <joueur> <village> <montant>", description = "Modifier la réputation",
    args = { "player", "string", "number" },
    run = function(caller, target, village, amount)
        if not Villages:Exists(village) then return false, "Village inconnu." end
        Villages.AddReputation(target, village, math.floor(amount))
        NRP.LogAction("admin", caller, target, "réputation " .. village .. " " .. amount)
        return true, "Réputation modifiée."
    end,
})

NRP.Commands.Add("spawn", {
    perm = "admin.world", usage = "spawn <add|remove|list> [village|id]", description = "Points d'apparition des villages",
    args = { "string", "string?" },
    run = function(caller, action, arg)
        action = string.lower(action)
        if action == "add" then
            if caller == NULL then return false, "Commande en jeu uniquement." end
            if not Villages:Exists(arg) then return false, "Village inconnu." end
            local pos = caller:GetPos()
            DB.Insert("spawns", { map = game.GetMap(), village = arg, x = pos.x, y = pos.y, z = pos.z, yaw = caller:EyeAngles().y },
                function() Villages.LoadSpawns() end)
            NRP.LogAction("world", caller, nil, "spawn " .. arg)
            return true, "Point d'apparition ajouté pour " .. arg
        elseif action == "remove" then
            local id = tonumber(arg)
            if not id then return false, "Identifiant attendu." end
            DB.Delete("spawns", { id = id, map = game.GetMap() }, function() Villages.LoadSpawns() end)
            return true, "Point #" .. id .. " supprimé."
        elseif action == "list" then
            local parts = {}
            for village, list in SortedPairs(Villages.Spawns) do
                for _, s in ipairs(list) do
                    parts[#parts + 1] = "#" .. s.id .. " " .. village
                end
            end
            return true, #parts > 0 and table.concat(parts, ", ") or "Aucun point d'apparition."
        end
        return false, "Action inconnue."
    end,
})
