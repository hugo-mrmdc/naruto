--[[
    UI : onglet VILLAGE (relations, guerres, réputation, Bingo Book, primes)
]]

local UI = NRP.UI
local S = UI.S
local Villages = NRP.Villages

local function BountyForm(parent)
    local theme = UI.Theme()
    local cfg = NRP.Config.VillageSettings.Bounty
    if not cfg.PlayerCanPlace then return end

    UI.Section(parent, "Placer une prime")
    UI.Label(parent, string.format("Montant entre %s et %s Ryo, taxe de %d%%.",
        NRP.Util.FormatNumber(cfg.MinAmount), NRP.Util.FormatNumber(cfg.MaxAmount), cfg.TaxPercent), "NRP.Tiny", theme.TextDim)

    local target
    local choices = {}
    for _, ply in NRP.Util.PlayerIterator() do
        if ply ~= LocalPlayer() and ply:GetNW2Bool("NRP_Loaded", false) then
            choices[#choices + 1] = { ply:Nick(), ply }
        end
    end
    local combo = UI.Combo(parent, choices, function(ply) target = ply end)
    combo:Dock(TOP)
    combo:SetValue("Cible…")
    combo:DockMargin(0, 0, 0, S(6))

    local amount = UI.TextEntry(parent, "Montant (Ryo)")
    amount:Dock(TOP)
    amount:SetNumeric(true)
    amount:DockMargin(0, 0, 0, S(6))

    local reason = UI.TextEntry(parent, "Raison (120 caractères max)")
    reason:Dock(TOP)
    reason:DockMargin(0, 0, 0, S(6))

    local submit = UI.Button(parent, "Placer la prime", function()
        if not IsValid(target) then
            return NRP.NotifyLocal("Choisissez une cible.", NRP.NOTIFY_ERROR, 2)
        end
        local value = tonumber(amount:GetValue()) or 0
        local total = value + math.ceil(value * cfg.TaxPercent / 100)
        UI.Confirm("Confirmer la prime", string.format("%s Ryo seront prélevés (taxe comprise) pour une prime sur %s.",
            NRP.Util.FormatNumber(total), target:Nick()), function()
            Villages.RequestPlaceBounty(target, value, reason:GetValue())
            timer.Simple(0.6, Villages.RequestBingoBook)
        end, nil, nil, "Confirmer", "Annuler")
    end, "danger")
    submit:Dock(TOP)
end

local function BingoBookList(parent)
    local theme = UI.Theme()
    local list = Villages.BingoBook
    if not list then
        UI.Label(parent, "Chargement…", "NRP.Small", theme.TextDim)
        return
    end
    if #list == 0 then
        UI.Label(parent, "Aucune prime active.", "NRP.Small", theme.TextDim)
        return
    end

    for _, entry in ipairs(list) do
        local village = entry.village and Villages:Get(entry.village)
        local rank = entry.rank and NRP.Ranks.Get(entry.rank)
        local card = vgui.Create("DPanel", parent)
        card:Dock(TOP)
        card:SetTall(S(70))
        card:DockMargin(0, 0, 0, S(6))
        card.Paint = function(_, w, h)
            UI.Box(0, 0, w, h, theme.Panel, S(8))
            draw.RoundedBoxEx(S(8), 0, 0, S(5), h, entry.deserter and theme.Error or theme.Warning, true, false, true, false)
            UI.Text(entry.name or "?", "NRP.BodyBold", S(16), S(8), theme.Text)
            local info = entry.online and ((rank and rank.name or "") .. "  •  Niv. " .. (entry.level or "?") .. "  •  "
                .. (village and village.name or "?")) or "Hors ligne"
            UI.Text(info, "NRP.Tiny", S(16), S(30), entry.online and theme.TextDim or UI.Alpha(theme.TextDim, 120))
            UI.Text(UI.Ellipsis(table.concat(entry.reasons or {}, " / "), "NRP.Tiny", w - S(200)), "NRP.Tiny", S(16), S(48), theme.TextDim)
            UI.Text(NRP.Util.FormatNumber(entry.total) .. " Ryo", "NRP.Header", w - S(14), h / 2, theme.Ryo, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

UI.RegisterTab("village", {
    name = "VILLAGE",
    order = 7,
    refreshOn = { reputation = true, village = true, deserter = true },
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local mine = Villages:Get(data.village)
        local left, right = UI.Columns(parent, 0.45)

        if mine then
            UI.Label(left, mine.fullName, "NRP.Title", mine.color)
            UI.Label(left, mine.country .. "  •  dirigé par le " .. mine.kage, "NRP.Small", theme.TextDim)
            local rep = Villages.GetReputation(data, data.village)
            UI.KeyValue(left, "Votre réputation", rep .. "  (" .. Villages.GetReputationTitle(rep) .. ")", rep < 0 and theme.Error or theme.Success)
        end

        UI.Section(left, "Relations diplomatiques")
        for _, v in ipairs(Villages.SortedList()) do
            if v.id ~= data.village and not v.deserter then
                local relType, relId = Villages.GetRelationType(data.village, v.id)
                local text = relType and relType.name or relId
                local score = Villages.WarScores and Villages.WarScores[Villages.RelationKey(data.village, v.id)]
                if relId == "war" and score then
                    text = text .. string.format("  (%d - %d)", score[data.village] or 0, score[v.id] or 0)
                end
                UI.KeyValue(left, v.name, text, relType and relType.color)
            end
        end

        if not data.deserter and NRP.Config.VillageSettings.Deserters.AllowSelfDesert then
            UI.Section(left, "Désertion")
            UI.Label(left, "Quitter définitivement votre village fait de vous un Nukenin : une prime sera placée sur votre tête.",
                "NRP.Tiny", theme.TextDim)
            local desert = UI.Button(left, "Déserter…", function()
                UI.Confirm("Déserter " .. (mine and mine.name or ""), "Cette décision est définitive. Continuer ?", function()
                    RunConsoleCommand("nrp", "deserter")
                    timer.Simple(0.5, function() RunConsoleCommand("nrp", "deserter") end)
                end, nil, nil, "Déserter", "Annuler")
            end, "danger")
            desert:Dock(TOP)
        end

        UI.Section(right, "Bingo Book")
        local refresh = UI.Button(right, "Actualiser", Villages.RequestBingoBook, "ghost")
        refresh:Dock(TOP)
        refresh:DockMargin(0, 0, 0, S(8))

        local listPanel = vgui.Create("DPanel", right)
        listPanel:Dock(TOP)
        listPanel:SetPaintBackground(false)
        listPanel:SetTall(S(20))
        listPanel.PerformLayout = function(self)
            self:SizeToChildren(false, true)
        end
        local function FillList()
            if not IsValid(listPanel) then return end
            listPanel:Clear()
            BingoBookList(listPanel)
            listPanel:InvalidateLayout()
        end
        FillList()
        hook.Add("NRP.BingoBook", listPanel, FillList)

        BountyForm(right)
        Villages.RequestBingoBook()
    end,
})

hook.Add("NRP.RelationsUpdated", "NRP.UI.VillageTab", function()
    if UI.IsMenuOpen() and UI.LastTab == "village" then
        timer.Create("NRP.UI.VillageRefresh", 0.2, 1, UI.RefreshMenu)
    end
end)
