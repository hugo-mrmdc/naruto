--[[
    Module : inventaire (client) - requêtes et réception (l'affichage est dans ui/inventory)
    Hooks : "NRP.TradePrompt"(fromPly), "NRP.TradeState"(open, reason, other, state),
            "NRP.OpenShop"(npc, shopId)
]]

local Inv = NRP.Inventory

function Inv.RequestAction(action, id, qty)
    if not NRP.Net.CanSend("ItemAction", 0.15) then return end
    NRP.Net.Start("ItemAction")
        net.WriteUInt(action, 3)
        net.WriteString(id)
        net.WriteUInt(math.Clamp(qty or 1, 0, 65535), 16)
    net.SendToServer()
end

function Inv.RequestShop(npc, buying, id, qty)
    if not NRP.Net.CanSend("ShopTransaction", 0.3) then return end
    NRP.Net.Start("ShopTransaction")
        net.WriteEntity(npc)
        net.WriteBool(buying)
        net.WriteString(id)
        net.WriteUInt(math.Clamp(qty or 1, 1, 255), 8)
    net.SendToServer()
end

function Inv.RequestTrade(target)
    if not NRP.Net.CanSend("TradeRequest", 2) then return end
    NRP.Net.Start("TradeRequest")
        net.WriteEntity(target)
    net.SendToServer()
end

function Inv.RespondTrade(accept)
    NRP.Net.Start("TradeRespond")
        net.WriteBool(accept)
    net.SendToServer()
end

function Inv.TradeOffer(id, qty)
    if not NRP.Net.CanSend("TradeOffer", 0.17) then return end
    NRP.Net.Start("TradeOffer")
        net.WriteString(id)
        net.WriteUInt(math.Clamp(qty, 0, 65535), 16)
    net.SendToServer()
end

function Inv.TradeRyo(amount)
    if not NRP.Net.CanSend("TradeRyo", 0.25) then return end
    NRP.Net.Start("TradeRyo")
        net.WriteUInt(math.Clamp(math.floor(amount), 0, 4294967295), 32)
    net.SendToServer()
end

function Inv.TradeReady(ready)
    if not NRP.Net.CanSend("TradeReady", 0.3) then return end
    NRP.Net.Start("TradeReady")
        net.WriteBool(ready)
    net.SendToServer()
end

function Inv.TradeCancel()
    NRP.Net.Start("TradeCancel")
    net.SendToServer()
end

NRP.Net.Receive("TradePrompt", function()
    local from = net.ReadEntity()
    if IsValid(from) then
        hook.Run("NRP.TradePrompt", from)
    end
end)

NRP.Net.Receive("TradeState", function()
    local open = net.ReadBool()
    local reason = net.ReadString()
    local other, state
    if open then
        other = net.ReadEntity()
        state = NRP.Net.ReadTable()
    end
    hook.Run("NRP.TradeState", open, reason, other, state)
end)

NRP.Net.Receive("OpenShop", function()
    local npc = net.ReadEntity()
    local shopId = net.ReadString()
    if IsValid(npc) then
        hook.Run("NRP.OpenShop", npc, shopId)
    end
end)
