--[[
    Module : villages (client)
    Hooks : "NRP.RelationsUpdated"(), "NRP.BingoBook"(list)
]]

local Villages = NRP.Villages

NRP.Net.Receive("Relations", function()
    local payload = NRP.Net.ReadTable()
    if not payload then return end
    Villages.Relations = payload.relations or {}
    Villages.WarScores = payload.wars or {}
    hook.Run("NRP.RelationsUpdated")
end)

NRP.Net.Receive("BingoBook", function()
    Villages.BingoBook = NRP.Net.ReadTable() or {}
    hook.Run("NRP.BingoBook", Villages.BingoBook)
end)

function Villages.RequestBingoBook()
    if not NRP.Net.CanSend("BingoBookRequest", 2.5) then return end
    NRP.Net.Start("BingoBookRequest")
    net.SendToServer()
end

function Villages.RequestPlaceBounty(target, amount, reason)
    if not NRP.Net.CanSend("PlaceBounty", 5) then return end
    NRP.Net.Start("PlaceBounty")
        net.WriteEntity(target)
        net.WriteUInt(math.Clamp(math.floor(amount), 0, 4294967295), 32)
        net.WriteString(string.sub(reason or "", 1, 120))
    net.SendToServer()
end
