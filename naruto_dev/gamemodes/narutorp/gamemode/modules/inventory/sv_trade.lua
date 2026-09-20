--[[
    Module : échanges entre joueurs (serveur)

    Déroulement :
        1. A -> "TradeRequest"(B)            B reçoit "TradePrompt"
        2. B -> "TradeRespond"(true)         session ouverte, "TradeState" aux deux
        3. chacun -> "TradeOffer"(objet, qté) / "TradeRyo"(montant)   (toute modif annule les validations)
        4. chacun -> "TradeReady"(true)      quand les deux sont prêts : revalidation complète
                                             (distance, possession, objets échangeables, place) puis échange atomique
    "TradeCancel" ferme la session.
]]

local Inv = NRP.Inventory
local Char = NRP.Char

Inv.Trades = Inv.Trades or {}      -- [ply] = session
local requests = {}                -- [target] = { from, expires }

NRP.Net.Pool("TradePrompt")
NRP.Net.Pool("TradeState")

local function Settings()
    return Inv.Settings()
end

local function Other(session, ply)
    return session.a == ply and session.b or session.a
end

local function Offer(session, ply)
    return session.offers[ply]
end

local function SendState(session, closedReason)
    for _, ply in ipairs({ session.a, session.b }) do
        if IsValid(ply) then
            local other = Other(session, ply)
            NRP.Net.Start("TradeState")
                net.WriteBool(closedReason == nil)
                net.WriteString(closedReason or "")
                if not closedReason then
                    net.WriteEntity(other)
                    NRP.Net.WriteTable({
                        mine = session.offers[ply],
                        theirs = session.offers[other],
                        myReady = session.ready[ply] == true,
                        theirReady = session.ready[other] == true,
                    })
                end
            net.Send(ply)
        end
    end
end

function Inv.CloseTrade(session, reason)
    if Inv.Trades[session.a] == session then Inv.Trades[session.a] = nil end
    if Inv.Trades[session.b] == session then Inv.Trades[session.b] = nil end
    SendState(session, reason or "Échange annulé")
end

local function InRange(a, b)
    return IsValid(a) and IsValid(b) and a:Alive() and b:Alive()
        and a:GetPos():DistToSqr(b:GetPos()) <= Settings().TradeDistance ^ 2
end

local function ResetReady(session)
    session.ready = {}
end

-- Vérifie qu'un joueur possède et peut céder son offre
local function ValidateOffer(ply, offer)
    if not Char.CanAfford(ply, offer.ryo) then return false, ply:Nick() .. " n'a plus assez de Ryo." end
    for id, qty in pairs(offer.items) do
        local def = Inv.Items:Get(id)
        if not def or not def.tradeable then return false, "Objet non échangeable." end
        if Inv.Count(ply, id) < qty then return false, ply:Nick() .. " ne possède plus " .. def.name .. "." end
    end
    return true
end

-- Le destinataire peut-il recevoir l'offre ?
local function CanReceive(ply, offer, givenAway)
    local inv = ply.NRPChar.inventory
    local stacks = Inv.StackCount(inv)
    for id, qty in pairs(offer.items) do
        local def = Inv.Items:Get(id)
        local current = Inv.Count(ply, id) - (givenAway.items[id] or 0)
        if current + qty > def.stack then
            return false, ply:Nick() .. " ne peut pas porter autant de " .. def.name .. "."
        end
        if current <= 0 then stacks = stacks + 1 end
    end
    if stacks > Settings().MaxStacks then
        return false, "Inventaire de " .. ply:Nick() .. " plein."
    end
    return true
end

local function Execute(session)
    local a, b = session.a, session.b
    local offerA, offerB = Offer(session, a), Offer(session, b)

    if not InRange(a, b) then return Inv.CloseTrade(session, "Joueurs trop éloignés") end

    for _, check in ipairs({
        { ValidateOffer(a, offerA) }, { ValidateOffer(b, offerB) },
        { CanReceive(a, offerB, offerA) }, { CanReceive(b, offerA, offerB) },
    }) do
        if not check[1] then
            ResetReady(session)
            NRP.Notify({ a, b }, check[2], NRP.NOTIFY_ERROR)
            SendState(session)
            return
        end
    end

    -- Retraits d'abord (tout a été vérifié), puis ajouts
    for id, qty in pairs(offerA.items) do Inv.Take(a, id, qty) end
    for id, qty in pairs(offerB.items) do Inv.Take(b, id, qty) end
    if offerA.ryo > 0 then Char.AddRyo(a, -offerA.ryo, "trade") end
    if offerB.ryo > 0 then Char.AddRyo(b, -offerB.ryo, "trade") end

    for id, qty in pairs(offerA.items) do Inv.Give(b, id, qty, true) end
    for id, qty in pairs(offerB.items) do Inv.Give(a, id, qty, true) end
    if offerA.ryo > 0 then Char.AddRyo(b, offerA.ryo, "trade") end
    if offerB.ryo > 0 then Char.AddRyo(a, offerB.ryo, "trade") end

    NRP.LogAction("trade", a, b, util.TableToJSON({ a = offerA, b = offerB }))
    Inv.CloseTrade(session, "Échange effectué !")
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------

NRP.Net.Receive("TradeRequest", function(ply)
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() or target == ply or not target.NRPChar then return end
    if Inv.Trades[ply] or Inv.Trades[target] then
        return NRP.Notify(ply, "Un des joueurs est déjà en échange.", NRP.NOTIFY_ERROR)
    end
    if not InRange(ply, target) then
        return NRP.Notify(ply, "Ce joueur est trop loin.", NRP.NOTIFY_ERROR)
    end

    requests[target] = { from = ply, expires = CurTime() + Settings().TradeRequestTimeout }
    NRP.Net.Start("TradePrompt")
        net.WriteEntity(ply)
    net.Send(target)
    NRP.Notify(ply, "Demande d'échange envoyée à " .. target:Nick(), NRP.NOTIFY_INFO)
end, { rate = 0.5, burst = 2, maxBytes = 32, alive = true })

NRP.Net.Receive("TradeRespond", function(ply)
    local accept = net.ReadBool()
    local req = requests[ply]
    requests[ply] = nil
    if not req or req.expires < CurTime() or not IsValid(req.from) then return end

    if not accept then
        return NRP.Notify(req.from, ply:Nick() .. " a refusé l'échange.", NRP.NOTIFY_WARNING)
    end
    if Inv.Trades[ply] or Inv.Trades[req.from] or not InRange(ply, req.from) then return end

    local session = {
        a = req.from, b = ply,
        offers = {
            [req.from] = { items = {}, ryo = 0 },
            [ply] = { items = {}, ryo = 0 },
        },
        ready = {},
    }
    Inv.Trades[req.from] = session
    Inv.Trades[ply] = session
    SendState(session)
end, { rate = 1, burst = 2, maxBytes = 16 })

NRP.Net.Receive("TradeOffer", function(ply)
    local session = Inv.Trades[ply]
    local id = NRP.Net.ReadId()
    local qty = net.ReadUInt(16)
    if not session or not id then return end

    local def = Inv.Items:Get(id)
    if not def or not def.tradeable then
        return NRP.Notify(ply, "Cet objet ne peut pas être échangé.", NRP.NOTIFY_ERROR)
    end

    local offer = Offer(session, ply)
    qty = math.min(qty, Inv.Count(ply, id))
    if qty <= 0 then
        offer.items[id] = nil
    else
        if not offer.items[id] and table.Count(offer.items) >= Settings().TradeMaxItems then
            return NRP.Notify(ply, "Trop d'objets dans l'offre.", NRP.NOTIFY_ERROR)
        end
        offer.items[id] = qty
    end

    ResetReady(session)
    SendState(session)
end, { rate = 6, burst = 10, maxBytes = 96 })

NRP.Net.Receive("TradeRyo", function(ply)
    local session = Inv.Trades[ply]
    local amount = net.ReadUInt(32)
    if not session then return end

    Offer(session, ply).ryo = math.Clamp(amount, 0, Char.GetRyo(ply))
    ResetReady(session)
    SendState(session)
end, { rate = 4, burst = 6, maxBytes = 16 })

NRP.Net.Receive("TradeReady", function(ply)
    local session = Inv.Trades[ply]
    local ready = net.ReadBool()
    if not session then return end

    session.ready[ply] = ready
    if session.ready[session.a] and session.ready[session.b] then
        Execute(session)
    else
        SendState(session)
    end
end, { rate = 3, burst = 4, maxBytes = 16 })

NRP.Net.Receive("TradeCancel", function(ply)
    local session = Inv.Trades[ply]
    if session then
        Inv.CloseTrade(session, ply:Nick() .. " a annulé l'échange")
    end
end, { rate = 2, burst = 3, maxBytes = 16, needChar = false })

local function CancelFor(ply)
    local session = Inv.Trades[ply]
    if session then
        Inv.CloseTrade(session, "Échange interrompu")
    end
    requests[ply] = nil
end

hook.Add("PlayerDeath", "NRP.Trade.Cancel", CancelFor)
hook.Add("PlayerDisconnected", "NRP.Trade.Cancel", CancelFor)
hook.Add("NRP.CharacterUnloaded", "NRP.Trade.Cancel", CancelFor)
