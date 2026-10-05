--[[
    UI : onglet JUTSU
    - Barre d'emplacements : clic gauche = placer le jutsu sélectionné, clic droit = vider
    - Liste par catégorie : techniques connues puis verrouillées (avec la condition manquante)
]]

local UI = NRP.UI
local S = UI.S
local Jutsu = NRP.Jutsu

local pickedJutsu

local function Detail(jutsu)
    local parts = {}
    parts[#parts + 1] = "Chakra " .. jutsu.chakra
    parts[#parts + 1] = "Recharge " .. jutsu.cooldown .. " s"
    if (jutsu.castTime or 0) > 0 then parts[#parts + 1] = "Incantation " .. jutsu.castTime .. " s" end
    if jutsu.damage then parts[#parts + 1] = "Dégâts " .. jutsu.damage end
    if jutsu.heal then parts[#parts + 1] = "Soin " .. jutsu.heal end
    if jutsu.range then parts[#parts + 1] = "Portée " .. math.floor(jutsu.range * 0.01905) .. " m" end
    if jutsu.duration then parts[#parts + 1] = "Durée " .. jutsu.duration .. " s" end
    return table.concat(parts, "  •  ")
end

local function UnlockText(jutsu)
    local map = {
        auto = "Appris automatiquement",
        scroll = "S'apprend avec un parchemin",
        tree = "Arbre de clan",
        admin = "Enseigné en RP",
    }
    return map[jutsu.unlock] or ""
end

local function BuildLoadout(parent, data)
    local theme = UI.Theme()
    local count = Jutsu.SlotCount()
    local bar = vgui.Create("DPanel", parent)
    bar:Dock(TOP)
    bar:SetTall(S(110))
    bar:DockMargin(0, 0, 0, S(10))
    bar.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, theme.Panel, S(8))
        local hint = pickedJutsu and ("Cliquez sur un emplacement pour y placer : " .. pickedJutsu.name)
            or "Sélectionnez une technique ci-dessous, puis un emplacement. Clic droit : vider."
        UI.Text(hint, "NRP.Small", S(14), S(10), pickedJutsu and theme.Accent or theme.TextDim)
    end

    local size = S(64)
    for i = 1, count do
        local slot = vgui.Create("DButton", bar)
        slot:SetText("")
        slot:SetSize(size, size)
        slot:SetPos(S(14) + (i - 1) * (size + S(10)), S(36))

        local id = data.loadout and data.loadout[i]
        local jutsu = id and id ~= "" and Jutsu.Registry:Get(id)
        slot:SetTooltip(jutsu and jutsu.name or ("Emplacement " .. i))

        slot.Paint = function(self, w, h)
            UI.Box(0, 0, w, h, self:IsHovered() and theme.PanelLight or theme.Background, S(6))
            if jutsu then
                UI.Icon(S(4), S(4), w - S(8), jutsu.icon, jutsu.name, UI.CategoryColor(jutsu))
            end
            UI.Text(tostring(i), "NRP.Tiny", S(4), S(2), theme.TextDim)
            if pickedJutsu and self:IsHovered() then
                UI.Outline(0, 0, w, h, theme.Accent, S(2))
            end
        end
        slot.DoClick = function()
            if pickedJutsu then
                Jutsu.RequestSetSlot(i, pickedJutsu.id)
                pickedJutsu = nil
            end
        end
        slot.DoRightClick = function()
            Jutsu.RequestSetSlot(i, "")
        end
    end
end

local function JutsuRow(parent, jutsu, data, known)
    local theme = UI.Theme()
    local ok, reason = Jutsu.CheckRequirements(data, jutsu, LocalPlayer(), true)
    local catColor = UI.CategoryColor(jutsu)

    local row = vgui.Create("DButton", parent)
    row:SetText("")
    row:Dock(TOP)
    row:DockMargin(0, 0, 0, S(6))
    row:SetTall(S(84))

    row.Paint = function(self, w, h)
        local selected = pickedJutsu == jutsu
        local bg = selected and UI.Alpha(catColor, 50) or (self:IsHovered() and known and theme.PanelLight or theme.Panel)
        UI.Box(0, 0, w, h, bg, S(8))

        local iconSize = h - S(20)
        UI.Icon(S(10), S(10), iconSize, jutsu.icon, jutsu.name, known and catColor or theme.TextDim)
        local x = S(20) + iconSize

        UI.Text(jutsu.name, "NRP.BodyBold", x, S(8), known and theme.Text or theme.TextDim)
        UI.Text(UI.Ellipsis(jutsu.description, "NRP.Small", w - x - S(14)), "NRP.Small", x, S(30), theme.TextDim)
        UI.Text(Detail(jutsu), "NRP.Tiny", x, S(54), known and catColor or theme.TextDim)

        if not known then
            local lockText = ok and UnlockText(jutsu) or reason
            UI.Text(lockText, "NRP.SmallBold", w - S(14), S(10), ok and theme.Warning or theme.Error, TEXT_ALIGN_RIGHT)
        end
        if selected then
            UI.Outline(0, 0, w, h, catColor, S(2))
        end
    end

    row.DoClick = function()
        if not known then return end
        pickedJutsu = pickedJutsu ~= jutsu and jutsu or nil
        surface.PlaySound("solve_naruto_base/ui/begin_reroll_sound.wav")
    end

    row.DoRightClick = function()
        if not known then return end
        local menu = DermaMenu()
        for i = 1, Jutsu.SlotCount() do
            menu:AddOption("Placer dans l'emplacement " .. i, function()
                Jutsu.RequestSetSlot(i, jutsu.id)
            end)
        end
        menu:Open()
    end
end

UI.RegisterTab("jutsu", {
    name = "JUTSU",
    order = 2,
    refreshOn = { jutsus = true, loadout = true, level = true, rank = true, affinities = true, clan = true, dojutsu = true, stats = true },
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        pickedJutsu = nil

        BuildLoadout(parent, data)

        local filterBar = vgui.Create("DPanel", parent)
        filterBar:Dock(TOP)
        filterBar:SetTall(S(34))
        filterBar:DockMargin(0, 0, 0, S(8))
        filterBar:SetPaintBackground(false)

        local list = vgui.Create("NRP.Scroll", parent)
        list:Dock(FILL)

        local showLocked = UI.ShowLockedJutsu ~= false
        local category = UI.JutsuCategory

        local function Fill()
            list:Clear()
            local lastCategory
            local shown = 0
            for _, jutsu in ipairs(Jutsu.SortedList()) do
                local known = Jutsu.Knows(data, jutsu.id)
                if (known or showLocked) and (not category or category == jutsu.category) then
                    if jutsu.category ~= lastCategory then
                        lastCategory = jutsu.category
                        local cat = Jutsu.Categories:Get(jutsu.category)
                        UI.Section(list, cat and cat.name or jutsu.category)
                    end
                    JutsuRow(list, jutsu, data, known)
                    shown = shown + 1
                end
            end
            if shown == 0 then
                UI.Label(list, "Aucune technique à afficher.", "NRP.Body", theme.TextDim)
            end
        end

        local choices = { { "Toutes les catégories", false, not category } }
        for _, cat in ipairs(Jutsu.Categories:Sorted("order")) do
            choices[#choices + 1] = { cat.name, cat.id, category == cat.id }
        end
        local combo = UI.Combo(filterBar, choices, function(value)
            category = value or nil
            UI.JutsuCategory = category
            Fill()
        end)
        combo:Dock(LEFT)
        combo:SetWide(S(260))

        local toggle = UI.Button(filterBar, showLocked and "Masquer les techniques verrouillées" or "Afficher les techniques verrouillées", function(btn)
            showLocked = not showLocked
            UI.ShowLockedJutsu = showLocked
            btn:SetLabel(showLocked and "Masquer les techniques verrouillées" or "Afficher les techniques verrouillées")
            Fill()
        end, "ghost")
        toggle:Dock(RIGHT)
        toggle:SetWide(S(300))

        local known = table.Count(data.jutsus or {})
        local counter = vgui.Create("DLabel", filterBar)
        counter:Dock(FILL)
        counter:SetContentAlignment(5)
        counter:SetFont("NRP.Small")
        counter:SetTextColor(theme.TextDim)
        counter:SetText(known .. " / " .. Jutsu.Registry:Count() .. " techniques connues")

        Fill()
    end,
})
