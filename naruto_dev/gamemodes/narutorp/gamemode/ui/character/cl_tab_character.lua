--[[
    UI : onglet PERSONNAGE (fiche + réglage des touches)
]]

local UI = NRP.UI
local S = UI.S

local function BuildKeybinds(panel)
    local theme = UI.Theme()
    UI.Section(panel, "Touches")

    for _, def in ipairs(NRP.Keys.Sorted()) do
        local row = vgui.Create("DPanel", panel)
        row:Dock(TOP)
        row:SetTall(S(34))
        row:DockMargin(0, 0, 0, S(4))
        row:SetPaintBackground(false)

        local label = vgui.Create("DLabel", row)
        label:Dock(FILL)
        label:SetFont("NRP.Small")
        label:SetTextColor(theme.Text)
        label:SetText(def.name)

        local binder = vgui.Create("DBinder", row)
        binder:Dock(RIGHT)
        binder:SetWide(S(140))
        binder:SetConVar(def.convar)
        binder:SetFont("NRP.SmallBold")
        binder.Paint = function(self, w, h)
            UI.Box(0, 0, w, h, self:IsHovered() and theme.PanelLight or theme.Panel, S(6))
        end
        binder:SetTextColor(theme.Accent)
    end

    local quick = vgui.Create("DCheckBoxLabel", panel)
    quick:Dock(TOP)
    quick:DockMargin(0, S(8), 0, S(4))
    quick:SetText("Lancer le jutsu dès la sélection de l'emplacement")
    quick:SetConVar("nrp_quickcast")
    quick:SetTextColor(theme.Text)

    local wheel = vgui.Create("DCheckBoxLabel", panel)
    wheel:Dock(TOP)
    wheel:DockMargin(0, 0, 0, S(4))
    wheel:SetText("La molette change d'emplacement de jutsu")
    wheel:SetConVar("nrp_wheel_select")
    wheel:SetTextColor(theme.Text)

    local hud = vgui.Create("DCheckBoxLabel", panel)
    hud:Dock(TOP)
    hud:SetText("Afficher le HUD")
    hud:SetConVar("nrp_hud")
    hud:SetTextColor(theme.Text)
end

UI.RegisterTab("character", {
    name = "PERSONNAGE",
    order = 1,
    refreshOn = { ryo = true, level = true, xp = true, rank = true, affinities = true, reputation = true, village = true, clan = true },
    build = function(parent)
        local theme = UI.Theme()
        local data = UI.Local()
        local ply = LocalPlayer()

        local modelPanel = vgui.Create("DModelPanel", parent)
        modelPanel:Dock(LEFT)
        modelPanel:SetWide(S(300))
        modelPanel:SetModel(ply:GetModel())
        modelPanel:SetFOV(36)
        modelPanel:SetCamPos(Vector(90, 0, 50))
        modelPanel:SetLookAt(Vector(0, 0, 38))
        local ent = modelPanel:GetEntity()
        if IsValid(ent) then
            ent:SetSkin(ply:GetSkin())
            for i = 0, ply:GetNumBodyGroups() - 1 do
                ent:SetBodygroup(i, ply:GetBodygroup(i))
            end
            local color = ply:GetPlayerColor()
            ent.GetPlayerColor = function() return color end
        end
        modelPanel.LayoutEntity = function(_, e)
            e:SetAngles(Angle(0, 20 + math.sin(RealTime() * 0.6) * 25, 0))
        end

        local left, right = UI.Columns(vgui.Create("DPanel", parent), 0.5)
        left:GetParent():Dock(FILL)
        left:GetParent():SetPaintBackground(false)

        -- Identité
        UI.Section(left, "Identité")
        UI.KeyValue(left, "Nom", NRP.Char.GetName(ply))
        UI.KeyValue(left, "Sexe", (NRP.Config.Character.Genders[data.gender] or {}).name or "?")

        local village = NRP.Villages:Get(data.village)
        UI.KeyValue(left, "Village", village and village.fullName or "?", village and village.color)
        if data.deserter then
            local origin = NRP.Villages:Get(data.originVillage)
            UI.KeyValue(left, "Village d'origine", origin and origin.name or "?", theme.Error)
        end

        local clan = NRP.Clans.Get(data.clan)
        UI.KeyValue(left, "Clan", clan and clan.name or NRP.Config.ClanSettings.NoClanName, clan and clan.color)

        local rank = NRP.Ranks.Get(data.rank)
        UI.KeyValue(left, "Grade", rank and rank.name or "?", rank and rank.color)

        UI.Section(left, "Progression")
        UI.KeyValue(left, "Niveau", data.level or 1, theme.XP)
        local xp, need = NRP.Progression.GetLevelProgress(data)
        local bar = vgui.Create("DPanel", left)
        bar:Dock(TOP)
        bar:SetTall(S(22))
        bar.Paint = function(_, w, h)
            UI.Bar(0, S(4), w, h - S(8), xp / math.max(1, need), theme.XP,
                NRP.Util.FormatNumber(xp) .. " / " .. NRP.Util.FormatNumber(need) .. " XP")
        end
        UI.KeyValue(left, "Ryo", NRP.Util.FormatNumber(data.ryo or 0), theme.Ryo)
        UI.KeyValue(left, "Points de statistiques", data.statPoints or 0)

        local completed = 0
        for _, n in pairs(data.missionData and data.missionData.completed or {}) do
            completed = completed + (tonumber(n) or 0)
        end
        UI.KeyValue(left, "Missions accomplies", completed)
        UI.KeyValue(left, "Créé le", os.date("%d/%m/%Y", data.created or 0))

        UI.Section(left, "Affinités")
        for i, element in ipairs(data.affinities or {}) do
            local def = NRP.Elements:Get(element)
            if def then
                UI.KeyValue(left, def.name .. (i == 1 and "  (principale)" or ""), def.description, def.color)
            end
        end

        UI.Section(left, "Réputation")
        for _, v in ipairs(NRP.Villages.SortedList()) do
            local value = NRP.Villages.GetReputation(data, v.id)
            if value ~= 0 or v.id == data.village then
                UI.KeyValue(left, v.name, value .. "  (" .. NRP.Villages.GetReputationTitle(value) .. ")",
                    value < 0 and theme.Error or v.color)
            end
        end

        BuildKeybinds(right)
    end,
})
