--[[
    UI : onglet CLAN (bonus, passifs, arbre de progression, techniques exclusives, dojutsu)
]]

local UI = NRP.UI
local S = UI.S
local Clans = NRP.Clans

local function ModifierText(mods)
    local parts = {}
    for key, value in SortedPairs(mods or {}) do
        local statDef = NRP.Stats.Defs:Get(key)
        local derivedDef = NRP.Stats.Derived[key]
        local name = statDef and statDef.name or (derivedDef and derivedDef.name) or key
        if istable(value) then
            if value.add and value.add ~= 0 then parts[#parts + 1] = string.format("%+g %s", value.add, name) end
            if value.mul and value.mul ~= 0 then parts[#parts + 1] = string.format("%+.0f%% %s", value.mul * 100, name) end
        else
            parts[#parts + 1] = string.format("%+g %s", value, name)
        end
    end
    return table.concat(parts, ", ")
end

local function NodeRewardsText(node)
    local r = node.rewards
    local parts = {}
    if r.stats then parts[#parts + 1] = ModifierText(r.stats) end
    if r.derived then parts[#parts + 1] = ModifierText(r.derived) end
    if r.jutsu then
        local j = NRP.Jutsu.Get(r.jutsu)
        parts[#parts + 1] = "Technique : " .. (j and j.name or r.jutsu)
    end
    for id, stage in pairs(r.dojutsuStage or {}) do
        local d = NRP.Dojutsu.Registry:Get(id)
        parts[#parts + 1] = (d and d.name or id) .. " stade " .. stage
    end
    if r.affinity then parts[#parts + 1] = "Affinité " .. r.affinity end
    return table.concat(parts, " • ")
end

-- Arbre : nœuds placés par pos = { colonne, ligne }, liens vers les prérequis
local function BuildTree(parent, clan, data)
    local theme = UI.Theme()
    local nodeW, nodeH = S(220), S(70)
    local gapX, gapY = S(30), S(30)

    local maxCol, maxRow = 1, 1
    for _, node in ipairs(clan.tree) do
        local pos = node.pos or { 1, 1 }
        maxCol = math.max(maxCol, pos[1])
        maxRow = math.max(maxRow, pos[2])
    end

    local canvas = vgui.Create("DPanel", parent)
    canvas:Dock(TOP)
    canvas:SetTall(maxRow * (nodeH + gapY) + gapY)

    local function NodeRect(node)
        local pos = node.pos or { 1, 1 }
        return gapX + (pos[1] - 1) * (nodeW + gapX), gapY + (pos[2] - 1) * (nodeH + gapY)
    end

    canvas.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, UI.Alpha(theme.Background, 120), S(8))
        for _, node in ipairs(clan.tree) do
            local x1, y1 = NodeRect(node)
            for _, req in ipairs(node.requires) do
                local parentNode = clan.nodes[req]
                if parentNode then
                    local x2, y2 = NodeRect(parentNode)
                    local unlocked = data.clanTree[req] and data.clanTree[node.id]
                    surface.SetDrawColor(unlocked and clan.color or UI.Alpha(theme.TextDim, 120))
                    surface.DrawLine(x2 + nodeW / 2, y2 + nodeH, x1 + nodeW / 2, y1)
                end
            end
        end
    end

    for _, node in ipairs(clan.tree) do
        local x, y = NodeRect(node)
        local unlocked = data.clanTree[node.id] == true
        local ok, reason = Clans.CanUnlockNode(data, node.id)

        local btn = vgui.Create("DButton", canvas)
        btn:SetText("")
        btn:SetPos(x, y)
        btn:SetSize(nodeW, nodeH)
        btn:SetTooltip(node.description .. "\n" .. NodeRewardsText(node) .. (unlocked and "" or ("\n" .. (ok and "Coût : " .. node.cost .. " point(s)" or reason))))
        btn.Paint = function(self, w, h)
            local col = unlocked and clan.color or (ok and theme.Accent or theme.TextDim)
            UI.Box(0, 0, w, h, unlocked and UI.Alpha(clan.color, 70) or (self:IsHovered() and theme.PanelLight or theme.Panel), S(8))
            UI.Outline(0, 0, w, h, col, unlocked and S(2) or 1)
            UI.Text(UI.Ellipsis(node.name, "NRP.SmallBold", w - S(16)), "NRP.SmallBold", S(8), S(8), theme.Text)
            UI.Text(unlocked and "Débloqué" or ("Niv. " .. node.level .. "  •  " .. node.cost .. " pt"), "NRP.Tiny", S(8), S(30), col)
            UI.Text(UI.Ellipsis(node.description, "NRP.Tiny", w - S(16)), "NRP.Tiny", S(8), S(48), theme.TextDim)
        end
        btn.DoClick = function()
            if unlocked then return end
            if not ok then
                NRP.NotifyLocal(reason, NRP.NOTIFY_ERROR, 2)
                return
            end
            UI.Confirm("Débloquer " .. node.name, node.description .. "\nCoût : " .. node.cost .. " point(s) de clan.", function()
                Clans.RequestUnlock(node.id)
            end, nil, nil, "Débloquer", "Annuler")
        end
    end
end

local function BuildDojutsu(parent, data)
    local theme = UI.Theme()
    local any = false
    local activeId, activeStage = NRP.Dojutsu.GetActive(LocalPlayer())
    local pref = data.flags and data.flags.dojutsuPref

    for id, def in NRP.Dojutsu.Registry:Iterate() do
        local unlocked = NRP.Dojutsu.GetUnlocked(data, id)
        if unlocked > 0 then
            if not any then UI.Section(parent, "Dojutsu") end
            any = true

            UI.Label(parent, def.name .. (activeId == id and ("  —  actif (stade " .. activeStage .. ")") or ""), "NRP.Header", def.eye.color)
            local key = input.GetKeyName(NRP.Keys.Get(LocalPlayer(), "dojutsu")) or "?"
            UI.Label(parent, "Activation : touche [" .. string.upper(key) .. "]  •  coût " .. def.activationCost .. " chakra", "NRP.Small", theme.TextDim)

            for i, stage in ipairs(def.stages) do
                local isUnlocked = i <= unlocked
                local isPref = istable(pref) and pref.id == id and tonumber(pref.stage) == i
                local text = stage.name .. "  —  " .. string.format("%.1f chakra/s", stage.drain)
                    .. (stage.modifiers and next(stage.modifiers) and ("  •  " .. ModifierText(stage.modifiers)) or "")
                local btn = UI.Button(parent, text, function()
                    NRP.Dojutsu.RequestPreferredStage(id, i)
                end, isPref and "selected" or "ghost")
                btn:SetFont("NRP.Small")
                btn:Dock(TOP)
                btn:DockMargin(0, 0, 0, S(4))
                if not isUnlocked then
                    btn:SetDisabledReason(stage.unlock == "admin" and "Éveil accordé en RP" or ("Niveau " .. stage.level .. " / arbre de clan"))
                else
                    btn:SetTooltip("Définir comme stade utilisé à l'activation")
                end
            end
        end
    end
end

UI.RegisterTab("clan", {
    name = "CLAN",
    order = 5,
    refreshOn = { clan = true, clanTree = true, clanPoints = true, level = true, dojutsu = true, flags = true, jutsus = true },
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local clan = Clans.Get(data.clan)
        local scroll = vgui.Create("NRP.Scroll", parent)
        scroll:Dock(FILL)

        if not clan then
            UI.Label(scroll, NRP.Config.ClanSettings.NoClanName, "NRP.Title", theme.TextDim)
            UI.Label(scroll, "Vous n'appartenez à aucun clan. Un clan peut vous être attribué au cours du RP.", "NRP.Body", theme.TextDim)
            BuildDojutsu(scroll, data)
            return
        end

        UI.Label(scroll, clan.name, "NRP.Title", clan.color)
        UI.Label(scroll, clan.description or "", "NRP.Body")

        local stats = ModifierText(clan.stats)
        local derived = ModifierText(clan.derived)
        if stats ~= "" or derived ~= "" then
            UI.Section(scroll, "Bonus du clan")
            if stats ~= "" then UI.Label(scroll, stats, "NRP.Small", theme.Success) end
            if derived ~= "" then UI.Label(scroll, derived, "NRP.Small", theme.Success) end
        end

        local passives = NRP.Passives.Collect(data)
        if #passives > 0 then
            UI.Section(scroll, "Capacités passives")
            for _, entry in ipairs(passives) do
                local desc = entry.def.describe and entry.def.describe(entry.params) or ""
                UI.KeyValue(scroll, entry.def.name, desc, clan.color)
            end
        end

        if #clan.tree > 0 then
            UI.Section(scroll, "Arbre du clan  —  " .. (data.clanPoints or 0) .. " point(s) disponible(s)")
            BuildTree(scroll, clan, data)
        end

        local exclusive = {}
        for _, jutsu in ipairs(NRP.Jutsu.SortedList()) do
            local req = jutsu.requirements.clan
            if req == data.clan or (istable(req) and table.HasValue(req, data.clan)) then
                exclusive[#exclusive + 1] = jutsu
            end
        end
        if #exclusive > 0 then
            UI.Section(scroll, "Techniques du clan")
            for _, jutsu in ipairs(exclusive) do
                local known = NRP.Jutsu.Knows(data, jutsu.id)
                local _, reason = NRP.Jutsu.CheckRequirements(data, jutsu, LocalPlayer(), true)
                UI.KeyValue(scroll, jutsu.name, known and "Connue" or (reason or "Disponible"), known and theme.Success or theme.TextDim)
            end
        end

        BuildDojutsu(scroll, data)
    end,
})
