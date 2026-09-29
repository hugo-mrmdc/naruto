--[[
    UI : onglet MISSIONS + tableau de missions (PNJ donneur)
]]

local UI = NRP.UI
local S = UI.S
local Missions = NRP.Missions

local function RewardsText(rewards)
    local parts = {}
    if rewards.xp then parts[#parts + 1] = NRP.Util.FormatNumber(rewards.xp) .. " XP" end
    if rewards.ryo then parts[#parts + 1] = NRP.Util.FormatNumber(rewards.ryo) .. " Ryo" end
    if rewards.reputation then parts[#parts + 1] = "+" .. rewards.reputation .. " réputation" end
    if rewards.statPoints then parts[#parts + 1] = rewards.statPoints .. " pt(s) de stats" end
    for id, qty in pairs(rewards.items or {}) do
        local def = NRP.Inventory.Items:Get(id)
        parts[#parts + 1] = qty .. " x " .. (def and def.name or id)
    end
    return table.concat(parts, "  •  ")
end

local function MissionCard(parent, def, footer)
    local theme = UI.Theme()
    local rank = Missions.GetRank(def.rank)
    local mtype = Missions.Types[def.type]

    local card = vgui.Create("DPanel", parent)
    card:Dock(TOP)
    card:SetTall(S(108))
    card:DockMargin(0, 0, 0, S(8))
    card.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, theme.Panel, S(8))
        draw.RoundedBoxEx(S(8), 0, 0, S(6), h, rank.color, true, false, true, false)

        local badge = S(44)
        UI.Box(S(18), S(14), badge, badge, UI.Alpha(rank.color, 60), S(8))
        UI.Text(def.rank, "NRP.Title", S(18) + badge / 2, S(14) + badge / 2, rank.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local x = S(78)
        UI.Text(def.name, "NRP.BodyBold", x, S(12), theme.Text)
        UI.Text((mtype and mtype.name or def.type) .. "  •  " .. def.party[1] .. "-" .. def.party[2] .. " ninja(s)  •  "
            .. NRP.Util.FormatTime(def.timeLimit), "NRP.Tiny", x, S(34), theme.TextDim)
        UI.Text(UI.Ellipsis(def.description, "NRP.Small", w - x - S(200)), "NRP.Small", x, S(52), theme.Text)
        UI.Text(UI.Ellipsis(RewardsText(def.rewards), "NRP.Tiny", w - x - S(200)), "NRP.Tiny", x, S(78), theme.XP)
        if footer then
            UI.Text(footer, "NRP.Tiny", w - S(14), h - S(10), theme.Error, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        end
    end
    return card
end

---------------------------------------------------------------------------
-- Tableau de missions
---------------------------------------------------------------------------
local board

hook.Add("NRP.MissionBoard", "NRP.UI.Board", function(npc, list)
    if IsValid(board) then board:Remove() end
    local theme = UI.Theme()
    local village = IsValid(npc) and NRP.Villages:Get(npc:GetVillage())

    board = vgui.Create("NRP.Frame")
    board:SetSize(math.min(S(900), ScrW() - S(40)), math.min(S(700), ScrH() - S(40)))
    board:Center()
    board:SetHeader("Tableau des missions", village and village.fullName or "Toutes origines")
    board:MakePopup()

    local scroll = vgui.Create("NRP.Scroll", board)
    scroll:Dock(FILL)

    if Missions.Current then
        UI.Label(scroll, "Vous êtes déjà en mission : terminez-la ou abandonnez-la (menu MISSIONS).", "NRP.BodyBold", theme.Warning)
    end

    table.sort(list, function(a, b)
        local da, db = Missions.Registry:Get(a.id), Missions.Registry:Get(b.id)
        if not da or not db then return false end
        if a.ok ~= b.ok then return a.ok end
        return Missions.GetRank(da.rank).order < Missions.GetRank(db.rank).order
    end)

    for _, entry in ipairs(list) do
        local def = Missions.Registry:Get(entry.id)
        if def then
            local card = MissionCard(scroll, def, not entry.ok and entry.reason or nil)
            local btn = UI.Button(card, "Accepter", function()
                Missions.RequestAccept(npc, entry.id)
                board:Remove()
            end)
            btn:SetSize(S(160), S(36))
            card.PerformLayout = function(_, w)
                btn:SetPos(w - S(174), S(14))
            end
            if not entry.ok then
                btn:SetDisabledReason(entry.reason)
            elseif Missions.Current then
                btn:SetDisabledReason("Déjà en mission")
            end
        end
    end

    if #list == 0 then
        UI.Label(scroll, "Aucune mission disponible pour le moment.", "NRP.Body", theme.TextDim)
    end
end)

---------------------------------------------------------------------------
-- Onglet MISSIONS
---------------------------------------------------------------------------
local function InviteMenu()
    local me = LocalPlayer()
    local menu = DermaMenu()
    local count = 0
    for _, ply in NRP.Util.PlayerIterator() do
        if ply ~= me and ply:GetNW2Bool("NRP_Loaded", false)
            and NRP.Char.GetVillage(ply) == NRP.Char.GetVillage(me)
            and ply:GetPos():DistToSqr(me:GetPos()) < 1500 * 1500 then
            count = count + 1
            menu:AddOption(ply:Nick(), function() Missions.RequestInvite(ply) end)
        end
    end
    if count == 0 then
        menu:AddOption("Aucun ninja de votre village à proximité"):SetEnabled(false)
    end
    menu:Open()
end

UI.RegisterTab("missions", {
    name = "MISSIONS",
    order = 4,
    refreshOn = { missionData = true, rank = true, level = true },
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local left, right = UI.Columns(parent, 0.6)

        UI.Section(left, "Mission en cours")
        local current = Missions.Current
        if not current then
            UI.Label(left, "Aucune mission en cours. Parlez à un donneur de mission de votre village (touche Utiliser).",
                "NRP.Body", theme.TextDim)
        else
            local def = current.def
            if def then MissionCard(left, def) end
            UI.KeyValue(left, "Objectif", current.objective or "")
            if (current.max or 0) > 0 then
                UI.KeyValue(left, "Progression", (current.cur or 0) .. " / " .. current.max, theme.Accent)
            end
            UI.KeyValue(left, "Temps restant", NRP.Util.FormatTime((current.endTime or 0) - CurTime()))
            UI.KeyValue(left, "Chef d'équipe", current.leader or "")
            UI.KeyValue(left, "Équipe", table.concat(current.members or {}, ", "))

            local actions = vgui.Create("DPanel", left)
            actions:Dock(TOP)
            actions:SetTall(S(40))
            actions:DockMargin(0, S(10), 0, 0)
            actions:SetPaintBackground(false)

            if current.isLeader then
                if current.state == "forming" then
                    local start = UI.Button(actions, "Lancer la mission", function()
                        Missions.RequestBegin()
                        UI.CloseMenu()
                    end)
                    start:Dock(LEFT)
                    start:SetWide(S(200))
                    start:DockMargin(0, 0, S(8), 0)
                end
                if def and #(current.members or {}) < def.party[2] then
                    local invite = UI.Button(actions, "Inviter…", InviteMenu, "ghost")
                    invite:Dock(LEFT)
                    invite:SetWide(S(140))
                    invite:DockMargin(0, 0, S(8), 0)
                end
            end

            local abandon = UI.Button(actions, "Abandonner", function()
                UI.Confirm("Abandonner la mission", "Vous ne pourrez pas la reprendre avant un moment.", function()
                    Missions.RequestAbandon()
                end, nil, nil, "Abandonner", "Annuler")
            end, "danger")
            abandon:Dock(RIGHT)
            abandon:SetWide(S(160))
        end

        -- Statistiques
        UI.Section(right, "Missions accomplies")
        local completed = data.missionData and data.missionData.completed or {}
        local ranks = {}
        for id, r in pairs(NRP.Config.MissionSettings.Ranks) do ranks[#ranks + 1] = { id = id, def = r } end
        table.sort(ranks, function(a, b) return a.def.order < b.def.order end)
        for _, r in ipairs(ranks) do
            UI.KeyValue(right, r.def.name, tonumber(completed[r.id]) or 0, r.def.color)
        end

        local rank = NRP.Ranks.Get(data.rank)
        UI.Section(right, "Accès")
        UI.KeyValue(right, "Rang maximum", rank and Missions.GetRank(rank.maxMissionRank or "D").name or "?")

        UI.Section(right, "Recharges")
        local now = os.time()
        local any = false
        for id, t in SortedPairs(data.missionData and data.missionData.cooldowns or {}) do
            local left2 = (tonumber(t) or 0) - now
            local def = Missions.Registry:Get(id)
            if left2 > 0 and def then
                any = true
                UI.KeyValue(right, def.name, NRP.Util.FormatTime(left2), theme.TextDim)
            end
        end
        if not any then
            UI.Label(right, "Aucune mission en recharge.", "NRP.Small", theme.TextDim)
        end
    end,
})

hook.Add("NRP.MissionUpdated", "NRP.UI.MissionTab", function()
    if UI.IsMenuOpen() and UI.LastTab == "missions" then
        timer.Create("NRP.UI.MissionRefresh", 0.2, 1, UI.RefreshMenu)
    end
end)
