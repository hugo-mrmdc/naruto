--[[
    UI : onglet STATISTIQUES (répartition des points + valeurs dérivées)
]]

local UI = NRP.UI
local S = UI.S

local function FormatDerived(def, value)
    if def.percent then
        if def.absolute then
            return string.format("%.0f%%", value * 100)
        end
        return UI.FormatPercent(value)
    end
    if value < 20 and math.floor(value) ~= value then
        return string.format("%.1f", value)
    end
    return tostring(math.floor(value))
end

UI.RegisterTab("stats", {
    name = "STATISTIQUES",
    order = 6,
    refreshOn = { stats = true, statPoints = true },
    refreshOnStats = true,
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local points = data.statPoints or 0
        local effective = NRP.Stats.LocalStats or {}
        local derived = NRP.Stats.LocalDerived or {}

        local left, right = UI.Columns(parent, 0.58)

        local header = vgui.Create("NRP.Card", left)
        header:Dock(TOP)
        header:SetTall(S(56))
        header:SetAccent(points > 0 and theme.Accent or theme.TextDim)
        header.Paint = function(self, w, h)
            UI.Box(0, 0, w, h, theme.Panel, S(8))
            draw.RoundedBoxEx(S(8), 0, 0, S(4), h, points > 0 and theme.Accent or theme.TextDim, true, false, true, false)
            UI.Text("Points disponibles", "NRP.Body", S(16), h / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            UI.Text(tostring(points), "NRP.Title", w - S(16), h / 2, points > 0 and theme.Accent or theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        for _, def in ipairs(NRP.Stats.Defs:Sorted("order")) do
            local allocated = tonumber(data.stats and data.stats[def.id]) or 0
            local total = effective[def.id] or allocated

            local row = vgui.Create("NRP.Card", left)
            row:Dock(TOP)
            row:DockMargin(0, S(8), 0, 0)
            row:SetTall(S(74))
            row.Paint = function(_, w, h)
                UI.Box(0, 0, w, h, theme.Panel, S(8))
                UI.Text(def.name, "NRP.BodyBold", S(14), S(10), theme.Text)
                local bonus = total - allocated
                local valueText = tostring(allocated) .. (math.abs(bonus) >= 0.5 and string.format("  (%+.0f)", bonus) or "")
                UI.Text(valueText, "NRP.BodyBold", w - S(150), S(10), theme.Accent, TEXT_ALIGN_RIGHT)
                UI.Text(def.description, "NRP.Tiny", S(14), S(32), theme.TextDim)
                UI.Bar(S(14), h - S(18), w - S(180), S(8), allocated / math.max(1, def.max or 100), theme.Accent)
                UI.Text(allocated .. " / " .. (def.max or "∞"), "NRP.Tiny", w - S(160), h - S(14), theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end

            local capped = allocated >= (def.max or math.huge)
            for i, amount in ipairs({ 5, 1 }) do
                local btn = UI.Button(row, "+" .. amount, function()
                    NRP.Progression.RequestAllocate(def.id, amount)
                end)
                btn:SetSize(S(56), S(32))
                btn:SetPos(0, S(21))
                row.PerformLayout = function(self, w)
                    for j, child in ipairs(self:GetChildren()) do
                        child:SetPos(w - j * S(64), S(21))
                    end
                end
                if points < amount or capped then
                    btn:SetDisabledReason(capped and "Maximum atteint" or "Pas assez de points")
                end
            end
        end

        UI.Section(right, "Valeurs effectives")
        local keys = {}
        for key in pairs(NRP.Stats.Derived) do keys[#keys + 1] = key end
        table.sort(keys, function(a, b) return NRP.Stats.Derived[a].name < NRP.Stats.Derived[b].name end)
        for _, key in ipairs(keys) do
            local def = NRP.Stats.Derived[key]
            local value = derived[key] or NRP.Stats.Baseline()[key] or 0
            UI.KeyValue(right, def.name, FormatDerived(def, value))
        end

        UI.Label(right, "Les bonus de clan, d'équipement, de dojutsu et de techniques actives sont inclus.",
            "NRP.Tiny", theme.TextDim):DockMargin(0, S(10), 0, 0)
    end,
})
