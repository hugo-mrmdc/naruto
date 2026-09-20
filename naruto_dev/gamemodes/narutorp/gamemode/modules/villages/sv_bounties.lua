--[[
    Module : primes et Bingo Book (serveur)

        NRP.Villages.PlaceBounty(issuer|nil, targetPly, montant, raison, villageEmetteur)
        NRP.Villages.ClaimBounties(killer, victim)
        NRP.Villages.RemoveBounty(id)

    Les primes actives sont gardées en cache ; la base n'est lue qu'au démarrage.
]]

local Villages = NRP.Villages
local Char = NRP.Char
local DB = NRP.DB

Villages.Bounties = Villages.Bounties or {}   -- [id] = bounty

NRP.Net.Pool("BingoBook")

local function Cfg()
    return NRP.Config.VillageSettings.Bounty
end

DB.RegisterTable("bounties", {
    columns = {
        { "id", "id" },
        { "target", "steamid", "" },
        { "target_name", "string", "" },
        { "amount", "bigint", 0 },
        { "reason", "string", "" },
        { "issuer", "steamid", "" },
        { "issuer_name", "string", "" },
        { "village", "string", "" },
        { "created", "int", 0 },
        { "active", "bool", 1 },
    },
    primary = { "id" },
    indexes = { { "target" }, { "active" } },
})

hook.Add("NRP.DatabaseReady", "NRP.Bounties.Load", function()
    local expire = os.time() - (Cfg().ExpireDays or 14) * 86400
    DB.Query("UPDATE " .. DB.Ident(DB.Table("bounties")) .. " SET active = 0 WHERE active = 1 AND created < ?", { expire })
    DB.Select("bounties", { active = 1 }, function(rows)
        Villages.Bounties = {}
        for _, row in ipairs(rows) do
            local id = tonumber(row.id)
            Villages.Bounties[id] = {
                id = id,
                target = tostring(row.target),
                targetName = row.target_name,
                amount = tonumber(row.amount) or 0,
                reason = row.reason,
                issuer = tostring(row.issuer or ""),
                issuerName = row.issuer_name,
                village = row.village,
                created = tonumber(row.created) or 0,
            }
        end
    end)
end)

function Villages.PlaceBounty(issuer, target, amount, reason, village)
    local cfg = Cfg()
    amount = math.floor(tonumber(amount) or 0)
    if not IsValid(target) or not target.NRPChar or target.NRPChar.isBot then
        return false, "Cible invalide."
    end

    local issuerId, issuerName = "", "Village"
    if IsValid(issuer) then
        if not cfg.PlayerCanPlace then return false, "Les joueurs ne peuvent pas placer de prime." end
        if issuer == target then return false, "Vous ne pouvez pas vous viser vous-même." end
        if amount < cfg.MinAmount or amount > cfg.MaxAmount then
            return false, string.format("Montant entre %s et %s Ryo.", NRP.Util.FormatNumber(cfg.MinAmount), NRP.Util.FormatNumber(cfg.MaxAmount))
        end

        issuerId = issuer.NRPChar.steamid
        local active = 0
        for _, b in pairs(Villages.Bounties) do
            if b.issuer == issuerId then active = active + 1 end
        end
        if active >= cfg.MaxActivePerIssuer then
            return false, "Vous avez trop de primes actives."
        end

        local total = amount + math.ceil(amount * (cfg.TaxPercent or 0) / 100)
        if not Char.AddRyo(issuer, -total, "bounty") then
            return false, "Il vous faut " .. NRP.Util.FormatNumber(total) .. " Ryo (taxe comprise)."
        end
        issuerName = issuer:Nick()
        village = ""
    end

    reason = string.sub(string.Trim(tostring(reason or "")), 1, 120)
    if reason == "" then reason = "Aucune raison donnée" end

    local bounty = {
        target = target.NRPChar.steamid,
        targetName = target:Nick(),
        amount = amount,
        reason = reason,
        issuer = issuerId,
        issuerName = issuerName,
        village = village or "",
        created = os.time(),
    }

    DB.Insert("bounties", {
        target = bounty.target, target_name = bounty.targetName, amount = amount, reason = reason,
        issuer = issuerId, issuer_name = issuerName, village = bounty.village, created = bounty.created, active = 1,
    }, function(_, id)
        bounty.id = tonumber(id)
        if bounty.id then
            Villages.Bounties[bounty.id] = bounty
        end
    end)

    NRP.ChatPrint(nil, Color(220, 60, 60), "[Bingo Book] ", color_white,
        string.format("Prime de %s Ryo sur %s : %s", NRP.Util.FormatNumber(amount), target:Nick(), reason))
    NRP.LogAction("bounty", issuer, target, amount .. " Ryo - " .. reason)
    return true
end

function Villages.RemoveBounty(id)
    if not Villages.Bounties[id] then return false end
    Villages.Bounties[id] = nil
    DB.Update("bounties", { active = 0 }, { id = id })
    return true
end

function Villages.ClaimBounties(killer, victim)
    local victimId = victim.NRPChar.steamid
    local killerId = killer.NRPChar.steamid
    local cfg = Cfg()
    local total, claimed = 0, {}

    for id, b in pairs(Villages.Bounties) do
        if b.target == victimId and b.issuer ~= killerId then
            local allowed = cfg.ClaimSameVillage or Char.GetVillage(killer) ~= Char.GetVillage(victim)
            if allowed then
                total = total + b.amount
                claimed[#claimed + 1] = id
            end
        end
    end

    if total <= 0 then return end

    for _, id in ipairs(claimed) do
        Villages.RemoveBounty(id)
    end
    Char.AddRyo(killer, total, "bounty_claim")
    NRP.ChatPrint(nil, Color(220, 60, 60), "[Bingo Book] ", color_white,
        string.format("%s a encaissé %s Ryo en éliminant %s.", killer:Nick(), NRP.Util.FormatNumber(total), victim:Nick()))
    NRP.LogAction("bounty", killer, victim, "prime encaissée " .. total)
end

-- Bingo Book : primes regroupées par cible
function Villages.BuildBingoBook()
    local byTarget = {}
    for _, b in pairs(Villages.Bounties) do
        local entry = byTarget[b.target]
        if not entry then
            entry = { steamid = b.target, name = b.targetName, total = 0, reasons = {}, count = 0 }
            byTarget[b.target] = entry
        end
        entry.total = entry.total + b.amount
        entry.count = entry.count + 1
        if #entry.reasons < 3 then
            entry.reasons[#entry.reasons + 1] = b.reason
        end
    end

    local list = {}
    for _, entry in pairs(byTarget) do
        local ply = player.GetBySteamID64(entry.steamid)
        if IsValid(ply) then
            entry.online = true
            entry.name = ply:Nick()
            entry.village = Char.GetVillage(ply)
            entry.rank = Char.GetRank(ply)
            entry.level = Char.GetLevel(ply)
            entry.deserter = Char.IsDeserter(ply)
        end
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b) return a.total > b.total end)
    return list
end

NRP.Net.Receive("BingoBookRequest", function(ply)
    NRP.Net.Start("BingoBook")
        NRP.Net.WriteTable(Villages.BuildBingoBook())
    net.Send(ply)
end, { rate = 0.5, burst = 2, maxBytes = 8 })

NRP.Net.Receive("PlaceBounty", function(ply)
    local target = net.ReadEntity()
    local amount = net.ReadUInt(32)
    local reason = NRP.Net.ReadString(120)

    local ok, err = Villages.PlaceBounty(ply, target, amount, reason)
    NRP.Notify(ply, ok and "Prime placée." or err, ok and NRP.NOTIFY_SUCCESS or NRP.NOTIFY_ERROR)
end, { rate = 0.2, burst = 2, maxBytes = 256, alive = true })

NRP.Commands.Add("bounty", {
    perm = "admin.bounty", usage = "bounty <add|remove|list> ...", description = "Gérer les primes",
    args = { "string", "string?", "number?", "text?" },
    run = function(caller, action, arg, amount, reason)
        action = string.lower(action)
        if action == "add" then
            local target, err = NRP.Util.FindPlayer(arg)
            if not target then return false, err end
            return Villages.PlaceBounty(nil, target, amount or 1000, reason or "Décision des autorités", "")
        elseif action == "remove" then
            if not Villages.RemoveBounty(tonumber(arg) or -1) then return false, "Prime introuvable." end
            return true, "Prime supprimée."
        elseif action == "list" then
            local parts = {}
            for id, b in SortedPairs(Villages.Bounties) do
                parts[#parts + 1] = "#" .. id .. " " .. b.targetName .. " " .. b.amount
            end
            return true, #parts > 0 and table.concat(parts, ", ") or "Aucune prime active."
        end
        return false, "Action inconnue."
    end,
})
