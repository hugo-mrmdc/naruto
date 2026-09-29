--[[
    UI : onglet INVENTAIRE
    Grille d'objets (rareté, quantité), fiche détaillée, équipement, poids, échange.
]]

local UI = NRP.UI
local S = UI.S
local Inv = NRP.Inventory

local selectedItem

local function ItemTile(parent, entry, onClick)
    local theme = UI.Theme()
    local def = entry.def
    local rarity = Inv.GetRarity(def)
    local size = S(86)

    local tile = parent:Add("DButton")
    tile:SetText("")
    tile:SetSize(size, size)
    tile:SetTooltip(def.name .. "\n" .. rarity.name .. " — " .. def.weight .. " kg\n" .. def.description)

    tile.Paint = function(self, w, h)
        local selected = selectedItem == entry.id
        UI.Box(0, 0, w, h, selected and UI.Alpha(rarity.color, 50) or (self:IsHovered() and theme.PanelLight or theme.Panel), S(8))
        UI.Icon(S(12), S(8), w - S(24), def.icon, def.name, rarity.color)
        UI.Outline(0, 0, w, h, UI.Alpha(rarity.color, selected and 255 or 90), selected and S(2) or 1)
        UI.Text("x" .. entry.qty, "NRP.SmallBold", w - S(6), h - S(4), theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, true)
        if entry.equipped then
            UI.Text("É", "NRP.SmallBold", S(6), S(4), theme.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, true)
        end
    end
    tile.DoClick = onClick
    tile.DoRightClick = function()
        local menu = DermaMenu()
        if Inv.IsUsable(def) then
            menu:AddOption("Utiliser", function() Inv.RequestAction(Inv.ACTION_USE, entry.id) end)
        end
        if def.equip then
            if entry.equipped then
                menu:AddOption("Déséquiper", function() Inv.RequestAction(Inv.ACTION_UNEQUIP, def.equip.slot) end)
            else
                menu:AddOption("Équiper", function() Inv.RequestAction(Inv.ACTION_EQUIP, entry.id) end)
            end
        end
        if def.droppable then
            menu:AddOption("Jeter 1", function() Inv.RequestAction(Inv.ACTION_DROP, entry.id, 1) end)
            if entry.qty > 1 then
                menu:AddOption("Jeter tout", function() Inv.RequestAction(Inv.ACTION_DROP, entry.id, entry.qty) end)
            end
        end
        menu:Open()
    end
    return tile
end

-- Joueurs proches pour un échange
local function NearbyPlayers(range)
    local out = {}
    local me = LocalPlayer()
    for _, ply in NRP.Util.PlayerIterator() do
        if ply ~= me and ply:Alive() and ply:GetNW2Bool("NRP_Loaded", false)
            and ply:GetPos():DistToSqr(me:GetPos()) <= range * range then
            out[#out + 1] = ply
        end
    end
    return out
end

function UI.OpenTradeTargetMenu()
    local players = NearbyPlayers(NRP.Config.InventorySettings.TradeDistance)
    local menu = DermaMenu()
    if #players == 0 then
        menu:AddOption("Aucun joueur à proximité"):SetEnabled(false)
    end
    for _, ply in ipairs(players) do
        menu:AddOption(ply:Nick(), function() Inv.RequestTrade(ply) end)
    end
    menu:Open()
end

UI.RegisterTab("inventory", {
    name = "INVENTAIRE",
    order = 3,
    refreshOn = { inventory = true },
    refreshOnStats = true,
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local inv = data.inventory or { items = {}, equipped = {} }
        local settings = NRP.Config.InventorySettings

        -- Barre supérieure : poids, piles, équipement, échange
        local top = vgui.Create("DPanel", parent)
        top:Dock(TOP)
        top:SetTall(S(70))
        top:DockMargin(0, 0, 0, S(10))
        local weight = Inv.GetWeight(inv)
        local maxWeight = NRP.Stats.Get(LocalPlayer(), "carryWeight")
        top.Paint = function(_, w, h)
            UI.Box(0, 0, w, h, theme.Panel, S(8))
            UI.Text("Poids", "NRP.Small", S(14), S(10), theme.TextDim)
            UI.Bar(S(14), S(32), S(260), S(14), weight / math.max(1, maxWeight),
                weight > maxWeight and theme.Error or theme.Accent,
                string.format("%.1f / %.0f kg", weight, maxWeight))
            UI.Text(Inv.StackCount(inv) .. " / " .. settings.MaxStacks .. " emplacements", "NRP.Small", S(290), S(32), theme.TextDim)
        end

        local tradeBtn = UI.Button(top, "Proposer un échange", UI.OpenTradeTargetMenu, "ghost")
        tradeBtn:Dock(RIGHT)
        tradeBtn:DockMargin(0, S(16), S(14), S(16))
        tradeBtn:SetWide(S(200))

        -- Équipement
        local equipBar = vgui.Create("DPanel", parent)
        equipBar:Dock(TOP)
        equipBar:SetTall(S(44))
        equipBar:DockMargin(0, 0, 0, S(10))
        equipBar:SetPaintBackground(false)

        local slots = {}
        for id, slot in pairs(settings.EquipSlots) do
            slots[#slots + 1] = { id = id, def = slot }
        end
        table.sort(slots, function(a, b) return (a.def.order or 0) < (b.def.order or 0) end)

        for _, slot in ipairs(slots) do
            local itemId = inv.equipped[slot.id]
            local item = itemId and Inv.Items:Get(itemId)
            local btn = UI.Button(equipBar, slot.def.name .. " : " .. (item and item.name or "—"), function()
                if item then Inv.RequestAction(Inv.ACTION_UNEQUIP, slot.id) end
            end, item and "primary" or "ghost")
            btn:SetFont("NRP.Small")
            btn:SetTooltip(item and "Cliquer pour déséquiper" or nil)
            btn:Dock(LEFT)
            btn:SetWide(S(300))
            btn:DockMargin(0, 0, S(8), 0)
        end

        -- Grille + fiche
        local detail = vgui.Create("NRP.Card", parent)
        detail:Dock(RIGHT)
        detail:SetWide(S(360))
        detail:DockMargin(S(12), 0, 0, 0)

        local scroll = vgui.Create("NRP.Scroll", parent)
        scroll:Dock(FILL)
        local grid = vgui.Create("DIconLayout", scroll)
        grid:Dock(TOP)
        grid:SetSpaceX(S(8))
        grid:SetSpaceY(S(8))

        local equippedIds = {}
        for _, id in pairs(inv.equipped) do equippedIds[id] = true end

        local entries = Inv.SortedEntries(inv)
        local function ShowDetail()
            detail:Clear()
            local entry
            for _, e in ipairs(entries) do
                if e.id == selectedItem then entry = e end
            end
            if not entry then
                UI.Label(detail, "Sélectionnez un objet.", "NRP.Body", theme.TextDim)
                UI.Label(detail, "Clic droit sur un objet : actions rapides.", "NRP.Small", theme.TextDim)
                return
            end

            local def = entry.def
            local rarity = Inv.GetRarity(def)
            UI.Label(detail, def.name, "NRP.Header", rarity.color)
            UI.Label(detail, rarity.name .. "  •  " .. ((settings.Categories[def.category] or {}).name or def.category), "NRP.Small", theme.TextDim)
            UI.Label(detail, def.description, "NRP.Body", theme.Text):DockMargin(0, S(8), 0, S(8))
            UI.KeyValue(detail, "Quantité", entry.qty .. " / " .. def.stack)
            UI.KeyValue(detail, "Poids", string.format("%.2f kg", def.weight * entry.qty))
            if def.price > 0 then UI.KeyValue(detail, "Valeur", NRP.Util.FormatNumber(def.price) .. " Ryo", theme.Ryo) end
            if def.use and def.use.cooldown then UI.KeyValue(detail, "Recharge", def.use.cooldown .. " s") end
            if def.learnJutsu then
                local j = NRP.Jutsu.Get(def.learnJutsu)
                UI.KeyValue(detail, "Enseigne", j and j.name or def.learnJutsu, theme.Accent)
            end
            if def.equip then
                for key, m in pairs(def.equip.modifiers or {}) do
                    local d = NRP.Stats.Derived[key]
                    local text = (m.add and string.format("%+g", m.add) or "") .. (m.mul and string.format(" %+.0f%%", m.mul * 100) or "")
                    UI.KeyValue(detail, d and d.name or key, text, theme.Success)
                end
            end

            local actions = vgui.Create("DPanel", detail)
            actions:Dock(BOTTOM)
            actions:SetTall(S(84))
            actions:SetPaintBackground(false)

            if Inv.IsUsable(def) then
                local use = UI.Button(actions, "Utiliser", function() Inv.RequestAction(Inv.ACTION_USE, entry.id) end)
                use:Dock(TOP)
                use:DockMargin(0, 0, 0, S(6))
            elseif def.equip then
                local label = entry.equipped and "Déséquiper" or "Équiper"
                local eq = UI.Button(actions, label, function()
                    if entry.equipped then
                        Inv.RequestAction(Inv.ACTION_UNEQUIP, def.equip.slot)
                    else
                        Inv.RequestAction(Inv.ACTION_EQUIP, entry.id)
                    end
                end)
                eq:Dock(TOP)
                eq:DockMargin(0, 0, 0, S(6))
            end

            if def.droppable then
                local drop = UI.Button(actions, "Jeter…", function()
                    UI.RequestText("Jeter " .. def.name, "Quantité (1 - " .. entry.qty .. ")", 1, function(value)
                        local qty = math.Clamp(tonumber(value) or 0, 0, entry.qty)
                        if qty > 0 then Inv.RequestAction(Inv.ACTION_DROP, entry.id, qty) end
                    end, true)
                end, "danger")
                drop:Dock(TOP)
            end
        end

        for _, entry in ipairs(entries) do
            entry.equipped = equippedIds[entry.id] == true
            ItemTile(grid, entry, function()
                selectedItem = entry.id
                ShowDetail()
            end)
        end

        if #entries == 0 then
            UI.Label(scroll, "Votre inventaire est vide.", "NRP.Body", theme.TextDim)
        end

        ShowDetail()
    end,
})
