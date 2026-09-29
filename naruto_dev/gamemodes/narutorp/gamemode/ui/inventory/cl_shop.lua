--[[
    UI : boutique (PNJ marchand)
]]

local UI = NRP.UI
local S = UI.S
local Inv = NRP.Inventory

local frame

local function Open(npc, shopId)
    local shop = Inv.Shops:Get(shopId)
    if not shop then return end
    if IsValid(frame) then frame:Remove() end
    local theme = UI.Theme()

    frame = vgui.Create("NRP.Frame")
    frame:SetSize(math.min(S(760), ScrW() - S(40)), math.min(S(620), ScrH() - S(40)))
    frame:Center()
    frame:SetHeader(shop.name)
    frame:MakePopup()

    local function Fill(selling)
        frame.Body:Clear()
        local data = NRP.Char.Local or {}
        frame:SetHeader(shop.name, NRP.Util.FormatNumber(data.ryo or 0) .. " Ryo")

        local list = {}
        if selling then
            for _, entry in ipairs(Inv.SortedEntries(data.inventory)) do
                if entry.def.price > 0 then
                    list[#list + 1] = { def = entry.def, qty = entry.qty }
                end
            end
        else
            for _, id in ipairs(shop.items) do
                local def = Inv.Items:Get(id)
                if def then list[#list + 1] = { def = def } end
            end
        end

        for _, entry in ipairs(list) do
            local def = entry.def
            local rarity = Inv.GetRarity(def)
            local price = selling and math.floor(def.price * shop.sellRatio) or def.price

            local row = vgui.Create("DPanel", frame.Body)
            row:Dock(TOP)
            row:SetTall(S(64))
            row:DockMargin(0, 0, 0, S(6))
            row.Paint = function(_, w, h)
                UI.Box(0, 0, w, h, theme.Panel, S(8))
                UI.Icon(S(8), S(8), h - S(16), def.icon, def.name, rarity.color)
                UI.Text(def.name .. (entry.qty and ("  (x" .. entry.qty .. ")") or ""), "NRP.BodyBold", h + S(4), S(10), rarity.color)
                UI.Text(UI.Ellipsis(def.description, "NRP.Tiny", w - h - S(260)), "NRP.Tiny", h + S(4), S(36), theme.TextDim)
                UI.Text(NRP.Util.FormatNumber(price) .. " Ryo", "NRP.BodyBold", w - S(200), h / 2, theme.Ryo, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            local btn = UI.Button(row, selling and "Vendre" or "Acheter", function()
                UI.RequestText(def.name, "Quantité", 1, function(value)
                    local qty = math.Clamp(tonumber(value) or 0, 0, 100)
                    if qty > 0 then Inv.RequestShop(npc, not selling, def.id, qty) end
                    timer.Simple(0.4, function()
                        if IsValid(frame) then Fill(selling) end
                    end)
                end, true)
            end)
            btn:Dock(RIGHT)
            btn:DockMargin(S(8), S(14), S(10), S(14))
            btn:SetWide(S(160))
            if not selling and (data.ryo or 0) < price then
                btn:SetDisabledReason("Pas assez de Ryo")
            end
        end

        if #list == 0 then
            UI.Label(frame.Body, selling and "Rien à vendre à ce marchand." or "Ce marchand n'a rien en stock.", "NRP.Body", theme.TextDim)
        end
    end

    local tabs = vgui.Create("DPanel", frame)
    tabs:Dock(TOP)
    tabs:SetTall(S(36))
    tabs:DockMargin(0, 0, 0, S(8))
    tabs:SetPaintBackground(false)

    frame.Body = vgui.Create("NRP.Scroll", frame)
    frame.Body:Dock(FILL)

    local buy = UI.Button(tabs, "Acheter", function() Fill(false) end, "ghost")
    buy:Dock(LEFT)
    buy:SetWide(S(160))
    if shop.sellRatio > 0 then
        local sell = UI.Button(tabs, "Vendre", function() Fill(true) end, "ghost")
        sell:Dock(LEFT)
        sell:DockMargin(S(8), 0, 0, 0)
        sell:SetWide(S(160))
    end

    Fill(false)
end

hook.Add("NRP.OpenShop", "NRP.UI.Shop", Open)
