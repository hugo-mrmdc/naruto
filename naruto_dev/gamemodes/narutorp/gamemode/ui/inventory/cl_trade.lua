--[[
    UI : fenêtre d'échange entre joueurs
    Chaque modification est envoyée au serveur qui renvoie l'état complet (source de vérité).
]]

local UI = NRP.UI
local S = UI.S
local Inv = NRP.Inventory

local frame

local function OfferList(parent, title, offer, color, editable)
    local theme = UI.Theme()
    local card = vgui.Create("NRP.Card", parent)
    card:SetAccent(color)

    UI.Label(card, title, "NRP.Header", color)
    UI.KeyValue(card, "Ryo", NRP.Util.FormatNumber(offer.ryo or 0), theme.Ryo)

    local scroll = vgui.Create("NRP.Scroll", card)
    scroll:Dock(FILL)
    local count = 0
    for id, qty in SortedPairs(offer.items or {}) do
        local def = Inv.Items:Get(id)
        if def then
            count = count + 1
            local row = UI.KeyValue(scroll, def.name, "x" .. qty, Inv.GetRarity(def).color)
            if editable then
                row:SetCursor("hand")
                row:SetMouseInputEnabled(true)
                row.OnMousePressed = function()
                    Inv.TradeOffer(id, 0)
                end
                row:SetTooltip("Cliquer pour retirer de l'offre")
            end
        end
    end
    if count == 0 then
        UI.Label(scroll, "Aucun objet", "NRP.Small", theme.TextDim)
    end
    return card
end

local function Build(other, state)
    local theme = UI.Theme()
    if not IsValid(frame) then
        frame = vgui.Create("NRP.Frame")
        frame:SetSize(math.min(S(900), ScrW() - S(40)), math.min(S(600), ScrH() - S(40)))
        frame:Center()
        frame:MakePopup()
        frame.OnClose = function() Inv.TradeCancel() end

        frame.Body = vgui.Create("DPanel", frame)
        frame.Body:Dock(FILL)
        frame.Body:SetPaintBackground(false)
    end
    frame.Body:Clear()
    frame:SetHeader("Échange", "avec " .. (IsValid(other) and other:Nick() or "?"))
    local body = frame.Body

    local bottom = vgui.Create("DPanel", body)
    bottom:Dock(BOTTOM)
    bottom:SetTall(S(44))
    bottom:DockMargin(0, S(10), 0, 0)
    bottom:SetPaintBackground(false)

    local ready = UI.Button(bottom, state.myReady and "Annuler la validation" or "Valider l'échange", function()
        Inv.TradeReady(not state.myReady)
    end, state.myReady and "ghost" or "primary")
    ready:Dock(RIGHT)
    ready:SetWide(S(240))

    local status = vgui.Create("DLabel", bottom)
    status:Dock(FILL)
    status:SetFont("NRP.BodyBold")
    status:SetTextColor(state.theirReady and theme.Success or theme.TextDim)
    status:SetText(state.theirReady and "L'autre joueur a validé." or "En attente de validation de l'autre joueur…")

    local columns = vgui.Create("DPanel", body)
    columns:Dock(FILL)
    columns:SetPaintBackground(false)

    -- Inventaire local (ajout à l'offre)
    local invCard = vgui.Create("NRP.Card", columns)
    invCard:Dock(LEFT)
    UI.Label(invCard, "Votre inventaire", "NRP.Header")
    UI.Label(invCard, "Cliquez sur un objet pour choisir la quantité proposée.", "NRP.Tiny", theme.TextDim)

    local ryoEntry = UI.TextEntry(invCard, "Ryo proposés")
    ryoEntry:Dock(TOP)
    ryoEntry:SetNumeric(true)
    ryoEntry:SetText(tostring(state.mine.ryo or 0))
    ryoEntry.OnEnter = function(self) Inv.TradeRyo(tonumber(self:GetValue()) or 0) end
    ryoEntry.OnLoseFocus = function(self)
        Inv.TradeRyo(tonumber(self:GetValue()) or 0)
    end

    local scroll = vgui.Create("NRP.Scroll", invCard)
    scroll:Dock(FILL)
    scroll:DockMargin(0, S(8), 0, 0)
    local data = NRP.Char.Local or {}
    for _, entry in ipairs(Inv.SortedEntries(data.inventory)) do
        if entry.def.tradeable then
            local btn = UI.Button(scroll, entry.def.name .. "  (x" .. entry.qty .. ")", function()
                if entry.qty == 1 then
                    Inv.TradeOffer(entry.id, 1)
                    return
                end
                UI.RequestText(entry.def.name, "Quantité à proposer (0 - " .. entry.qty .. ")", entry.qty, function(value)
                    Inv.TradeOffer(entry.id, math.Clamp(tonumber(value) or 0, 0, entry.qty))
                end, true)
            end, "ghost")
            btn:SetFont("NRP.Small")
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, S(4))
        end
    end

    local mine = OfferList(columns, "Votre offre", state.mine, theme.Accent, true)
    local theirs = OfferList(columns, "Offre de " .. (IsValid(other) and other:Nick() or "?"), state.theirs, theme.Chakra, false)
    mine:Dock(LEFT)
    mine:DockMargin(S(10), 0, S(10), 0)
    theirs:Dock(FILL)

    columns.PerformLayout = function(_, w)
        invCard:SetWide(w * 0.34)
        mine:SetWide(w * 0.3)
    end
end

hook.Add("NRP.TradeState", "NRP.UI.Trade", function(open, reason, other, state)
    if not open then
        if IsValid(frame) then
            frame.OnClose = function() end
            frame:Remove()
        end
        if reason ~= "" then
            NRP.NotifyLocal(reason, string.find(reason, "effectué", 1, true) and NRP.NOTIFY_SUCCESS or NRP.NOTIFY_WARNING, 4)
        end
        return
    end
    if state then
        Build(other, state)
    end
end)
