--[[
    UI : création de personnage (6 étapes)
        Identité -> Village -> Clan -> Affinité -> Apparence -> Résumé
    Les contrôles côté client ne servent qu'au confort : le serveur revalide tout.
]]

local UI = NRP.UI
local S = UI.S

local creation

-- Carte sélectionnable (village, clan, affinité)
function UI.SelectCard(parent, title, subtitle, description, color, selected, onClick)
    local card = vgui.Create("DButton", parent)
    card:SetText("")
    card:Dock(TOP)
    card:DockMargin(0, 0, 0, S(8))
    card:SetTall(description and description ~= "" and S(86) or S(56))

    card.Paint = function(self, w, h)
        local theme = UI.Theme()
        local hovered = self:IsHovered()
        UI.Box(0, 0, w, h, selected and UI.Alpha(color, 60) or (hovered and theme.PanelLight or theme.Panel), S(8))
        draw.RoundedBoxEx(S(8), 0, 0, S(6), h, color, true, false, true, false)
        if selected then
            UI.Outline(0, 0, w, h, color, S(2))
        end
        UI.Text(title, "NRP.Header", S(20), S(10), theme.Text)
        if subtitle then
            UI.Text(subtitle, "NRP.Small", w - S(14), S(14), theme.TextDim, TEXT_ALIGN_RIGHT)
        end
        if description and description ~= "" then
            UI.Text(UI.Ellipsis(description, "NRP.Small", w - S(40)), "NRP.Small", S(20), S(42), theme.TextDim)
        end
    end
    card.DoClick = function()
        surface.PlaySound("naruto_sound/menu_select.mp3")
        onClick()
    end
    return card
end

local function StatsText(stats)
    local parts = {}
    for id, value in SortedPairs(stats or {}) do
        local def = NRP.Stats.Defs:Get(id)
        parts[#parts + 1] = "+" .. value .. " " .. (def and def.name or id)
    end
    return table.concat(parts, ", ")
end

local function OpenCreation(info)
    if IsValid(creation) then creation:Remove() end
    UI.CloseMenu()

    local cfg = NRP.Config.Character
    local theme = UI.Theme()
    local req = {
        firstname = "", lastname = "", gender = "male",
        village = nil, clan = nil, affinity = nil,
        modelIndex = 1, skin = 0, bodygroups = {}, color = { 255, 255, 255 },
    }
    local step = 1
    local waiting = false
    local errorText = ""

    creation = vgui.Create("DFrame")
    creation:SetSize(ScrW(), ScrH())
    creation:SetPos(0, 0)
    creation:SetTitle("")
    creation:ShowCloseButton(false)
    creation:SetDraggable(false)
    creation:MakePopup()
    creation:DockPadding(S(60), S(120), S(60), S(40))

    local STEPS = { "Identité", "Village", "Clan", "Affinité", "Apparence", "Résumé" }

    creation.Paint = function(self, w, h)
        UI.Blur(self, 6)
        surface.SetDrawColor(10, 10, 14, 235)
        surface.DrawRect(0, 0, w, h)

        UI.Text("CRÉATION DE VOTRE NINJA", "NRP.Title", S(60), S(36), theme.Accent)
        local x = S(60)
        for i, name in ipairs(STEPS) do
            local col = i == step and theme.Accent or (i < step and theme.Text or theme.TextDim)
            local tw = UI.Text(i .. ". " .. name, "NRP.SmallBold", x, S(80), col)
            x = x + tw + S(28)
        end
    end

    -----------------------------------------------------------------------
    -- Aperçu 3D
    -----------------------------------------------------------------------
    local preview = vgui.Create("DModelPanel", creation)
    preview:Dock(RIGHT)
    preview:SetWide(ScrW() * 0.35)
    preview:SetFOV(36)
    preview:SetCamPos(Vector(90, 0, 50))
    preview:SetLookAt(Vector(0, 0, 38))
    preview.LayoutEntity = function(self, ent)
        ent:SetAngles(Angle(0, (RealTime() * 25) % 360, 0))
    end

    local function CurrentModels()
        return cfg.Genders[req.gender].models
    end

    -- Premier modèle réellement installé
    local function FirstValidIndex()
        for i, def in ipairs(CurrentModels()) do
            if util.IsValidModel(def.model) then return i end
        end
        return 1
    end

    -- Tête / cheveux ajoutés par l'addon naruto_dev, reproduits dans l'aperçu
    local previewParts = {}
    local function ClearParts()
        for _, part in ipairs(previewParts) do
            if IsValid(part) then part:Remove() end
        end
        previewParts = {}
    end
    creation.OnRemove = ClearParts

    local function AddParts(ent, def)
        ClearParts()
        local compat = NRP.Config.Compat and NRP.Config.Compat.NarutoDev
        if not compat or not compat.Enabled or def.hasHead or not GetGlobal2Bool("NRP_CompatNarutoDev", false) then return end
        for _, info in ipairs(compat.PreviewParts or {}) do
            if util.IsValidModel(info.model) then
                local part = ClientsideModel(info.model, RENDERGROUP_OPAQUE)
                if IsValid(part) then
                    part:SetNoDraw(true)
                    part:SetParent(ent)
                    part:AddEffects(EF_BONEMERGE)
                    part:SetColor(info.color or color_white)
                    previewParts[#previewParts + 1] = part
                end
            end
        end
    end

    preview.PostDrawModel = function()
        for _, part in ipairs(previewParts) do
            if IsValid(part) then
                local c = part:GetColor()
                render.SetColorModulation(c.r / 255, c.g / 255, c.b / 255)
                part:DrawModel()
            end
        end
        render.SetColorModulation(1, 1, 1)
    end

    local function UpdatePreview()
        local def = CurrentModels()[req.modelIndex] or CurrentModels()[1]
        preview:SetModel(def.model)
        local ent = preview:GetEntity()
        if not IsValid(ent) then return end
        AddParts(ent, def)
        ent:SetSkin(req.skin)
        for id, value in pairs(req.bodygroups) do
            ent:SetBodygroup(id, value)
        end
        local c = req.color
        local vec = Vector(c[1] / 255, c[2] / 255, c[3] / 255)
        ent.GetPlayerColor = function() return vec end
    end

    -----------------------------------------------------------------------
    -- Navigation
    -----------------------------------------------------------------------
    local nav = vgui.Create("DPanel", creation)
    nav:Dock(BOTTOM)
    nav:SetTall(S(50))
    nav:DockMargin(0, S(12), S(24), 0)
    nav:SetPaintBackground(false)

    local errorLabel = vgui.Create("DLabel", nav)
    errorLabel:Dock(FILL)
    errorLabel:SetFont("NRP.BodyBold")
    errorLabel:SetTextColor(theme.Error)
    errorLabel:SetText("")
    errorLabel:SetContentAlignment(5)

    local content = vgui.Create("NRP.Scroll", creation)
    content:Dock(FILL)
    content:DockMargin(0, 0, S(24), 0)

    local prevBtn, nextBtn
    local Build

    local validators = {
        function()
            local ok1, err1 = NRP.Char.ValidateNameClient(req.firstname)
            if not ok1 then return "Prénom : " .. err1 end
            local ok2, err2 = NRP.Char.ValidateNameClient(req.lastname)
            if not ok2 then return "Nom : " .. err2 end
        end,
        function() if not req.village then return "Choisissez un village." end end,
        function() if req.clan == nil then return "Choisissez un clan." end end,
        function() if not req.affinity then return "Choisissez une affinité." end end,
        function() end,
        function() end,
    }

    local builders = {}

    builders[1] = function(panel)
        UI.Section(panel, "Identité")
        UI.Label(panel, "Prénom", "NRP.Small", theme.TextDim)
        local first = UI.TextEntry(panel, "Prénom du ninja")
        first:Dock(TOP)
        first:SetText(req.firstname)
        first.OnChange = function(self) req.firstname = self:GetValue() end

        UI.Label(panel, "Nom de famille", "NRP.Small", theme.TextDim):DockMargin(0, S(10), 0, S(4))
        local last = UI.TextEntry(panel, "Nom de famille")
        last:Dock(TOP)
        last:SetText(req.lastname)
        last.OnChange = function(self) req.lastname = self:GetValue() end

        UI.Section(panel, "Sexe")
        for id, gender in SortedPairs(cfg.Genders) do
            local btn = UI.Button(panel, gender.name, function()
                if req.gender ~= id then
                    req.gender = id
                    req.modelIndex = FirstValidIndex()
                    req.skin = 0
                    req.bodygroups = {}
                    UpdatePreview()
                end
                Build()
            end, req.gender == id and "selected" or "ghost")
            btn:Dock(TOP)
            btn:DockMargin(0, 0, 0, S(6))
        end
    end

    builders[2] = function(panel)
        UI.Section(panel, "Choisissez votre village")
        for _, village in ipairs(NRP.Villages.SortedList()) do
            if village.selectable then
                UI.SelectCard(panel, village.name, village.country, village.fullName .. " — dirigé par le " .. village.kage,
                    village.color, req.village == village.id, function()
                        if req.village ~= village.id then req.clan = nil end
                        req.village = village.id
                        Build()
                    end)
            end
        end
    end

    builders[3] = function(panel)
        UI.Section(panel, "Choisissez votre clan")
        local available = (info.clans or {})[req.village] or {}

        if NRP.Config.ClanSettings.AllowNoClan then
            UI.SelectCard(panel, NRP.Config.ClanSettings.NoClanName, nil,
                "Aucun héritage particulier : un clan pourra vous être attribué en jeu.",
                theme.TextDim, req.clan == "", function() req.clan = "" Build() end)
        end

        for _, clanId in ipairs(available) do
            local clan = NRP.Clans.Get(clanId)
            if clan then
                local extra = StatsText(clan.stats)
                if clan.dojutsu then
                    local d = NRP.Dojutsu.Registry:Get(clan.dojutsu)
                    extra = extra .. (d and ("  •  " .. d.name) or "")
                end
                UI.SelectCard(panel, clan.name, extra, clan.description, clan.color, req.clan == clanId, function()
                    req.clan = clanId
                    Build()
                end)
            end
        end

        UI.Label(panel, "Certains clans rares ne sont attribués qu'en jeu par l'équipe RP.", "NRP.Small", theme.TextDim)
            :DockMargin(0, S(10), 0, 0)
    end

    builders[4] = function(panel)
        UI.Section(panel, "Affinité élémentaire")
        for _, element in ipairs(cfg.SelectableAffinities) do
            local def = NRP.Elements:Get(element)
            if def then
                UI.SelectCard(panel, def.name, def.description, nil, def.color, req.affinity == element, function()
                    req.affinity = element
                    Build()
                end)
            end
        end

        local clan = NRP.Clans.Get(req.clan)
        if clan and clan.affinity then
            local e = NRP.Elements:Get(clan.affinity)
            UI.Label(panel, "Le clan " .. clan.name .. " vous transmet aussi l'affinité " .. (e and e.name or clan.affinity) .. ".",
                "NRP.Small", theme.Accent):DockMargin(0, S(10), 0, 0)
        end
    end

    builders[5] = function(panel)
        UI.Section(panel, "Apparence")
        local grid = vgui.Create("DIconLayout", panel)
        grid:Dock(TOP)
        grid:SetSpaceX(S(8))
        grid:SetSpaceY(S(8))

        for i, def in ipairs(CurrentModels()) do
            if util.IsValidModel(def.model) then
                local icon = grid:Add("SpawnIcon")
                icon:SetSize(S(96), S(96))
                icon:SetModel(def.model)
                icon:SetTooltip(def.name)
                icon.PaintOver = function(self, w, h)
                    if req.modelIndex == i then
                        UI.Outline(0, 0, w, h, theme.Accent, S(3))
                    end
                end
                icon.DoClick = function()
                    req.modelIndex = i
                    req.skin = 0
                    req.bodygroups = {}
                    UpdatePreview()
                    Build()
                end
            end
        end

        local ent = preview:GetEntity()
        if IsValid(ent) then
            if ent:SkinCount() > 1 then
                UI.Section(panel, "Variante")
                local slider = vgui.Create("DNumSlider", panel)
                slider:Dock(TOP)
                slider:SetText("Skin")
                slider.Label:SetTextColor(theme.Text)
                slider:SetMinMax(0, ent:SkinCount() - 1)
                slider:SetDecimals(0)
                slider:SetValue(req.skin)
                slider.OnValueChanged = function(_, value)
                    req.skin = math.Round(value)
                    UpdatePreview()
                end
            end

            local shown = 0
            for id = 0, ent:GetNumBodyGroups() - 1 do
                local count = ent:GetBodygroupCount(id)
                if count > 1 and shown < (cfg.MaxBodygroups or 12) then
                    if shown == 0 then UI.Section(panel, "Détails") end
                    shown = shown + 1
                    local slider = vgui.Create("DNumSlider", panel)
                    slider:Dock(TOP)
                    slider:SetText(ent:GetBodygroupName(id))
                    slider.Label:SetTextColor(theme.Text)
                    slider:SetMinMax(0, count - 1)
                    slider:SetDecimals(0)
                    slider:SetValue(req.bodygroups[id] or 0)
                    slider.OnValueChanged = function(_, value)
                        req.bodygroups[id] = math.Round(value)
                        UpdatePreview()
                    end
                end
            end
        end

        if cfg.AllowPlayerColor then
            UI.Section(panel, "Couleur de la tenue")
            local mixer = vgui.Create("DColorMixer", panel)
            mixer:Dock(TOP)
            mixer:SetTall(S(180))
            mixer:SetPalette(false)
            mixer:SetAlphaBar(false)
            mixer:SetColor(Color(req.color[1], req.color[2], req.color[3]))
            mixer.ValueChanged = function(_, col)
                req.color = { col.r, col.g, col.b }
                UpdatePreview()
            end
        end
    end

    builders[6] = function(panel)
        UI.Section(panel, "Résumé")
        local village = NRP.Villages:Get(req.village)
        local element = NRP.Elements:Get(req.affinity)
        UI.KeyValue(panel, "Nom", req.firstname .. " " .. req.lastname)
        UI.KeyValue(panel, "Sexe", cfg.Genders[req.gender].name)
        UI.KeyValue(panel, "Village", village and village.name or "?", village and village.color)
        UI.KeyValue(panel, "Clan", req.clan ~= "" and NRP.Clans.GetName(req.clan) or NRP.Config.ClanSettings.NoClanName)
        UI.KeyValue(panel, "Affinité", element and element.name or "?", element and element.color)
        UI.KeyValue(panel, "Grade de départ", NRP.Ranks.GetName(cfg.StartRank))
        UI.KeyValue(panel, "Ryo de départ", NRP.Util.FormatNumber(cfg.StartRyo))
        UI.Label(panel, "Le nom, le village et le clan ne pourront plus être modifiés sans l'équipe du serveur.",
            "NRP.Small", theme.Warning):DockMargin(0, S(12), 0, 0)
    end

    Build = function()
        content:Clear()
        builders[step](content)
        errorLabel:SetText(errorText)
        prevBtn:SetEnabled(step > 1 and not waiting)
        nextBtn:SetLabel(step == #STEPS and (waiting and "Création…" or "Créer mon ninja") or "Suivant")
        nextBtn:SetEnabled(not waiting)
    end

    prevBtn = UI.Button(nav, "Précédent", function()
        errorText = ""
        step = math.max(1, step - 1)
        Build()
    end, "ghost")
    prevBtn:Dock(LEFT)
    prevBtn:SetWide(S(180))

    nextBtn = UI.Button(nav, "Suivant", function()
        local err = validators[step]()
        if err then
            errorText = err
            Build()
            return
        end
        errorText = ""
        if step < #STEPS then
            step = step + 1
            Build()
            return
        end

        if NRP.Char.RequestCreate(req) then
            waiting = true
            Build()
        end
    end)
    nextBtn:Dock(RIGHT)
    nextBtn:SetWide(S(220))

    creation.OnResult = function(ok, message)
        waiting = false
        if ok then
            creation:Remove()
            return
        end
        errorText = message
        if string.find(string.lower(message), "nom", 1, true) then
            step = 1
        end
        Build()
    end

    req.modelIndex = FirstValidIndex()
    UpdatePreview()
    Build()
end

-- Contrôle rapide du nom côté client (le serveur fait la vraie validation)
function NRP.Char.ValidateNameClient(name)
    local cfg = NRP.Config.Character
    name = string.Trim(name or "")
    local len = utf8.len(name) or 0
    if len < cfg.NameMinLength or len > cfg.NameMaxLength then
        return false, string.format("entre %d et %d caractères", cfg.NameMinLength, cfg.NameMaxLength)
    end
    if string.find(name, "%d") then
        return false, "pas de chiffres"
    end
    return true
end

hook.Add("NRP.OpenCreation", "NRP.UI.Creation", OpenCreation)

hook.Add("NRP.CreationResult", "NRP.UI.Creation", function(ok, message)
    if IsValid(creation) and creation.OnResult then
        creation.OnResult(ok, message)
    end
end)

hook.Add("NRP.CharSynced", "NRP.UI.CreationClose", function(_, full)
    if full and IsValid(creation) then
        creation:Remove()
    end
end)
