--[[
    UI : menu principal (touche configurable, F3 par défaut)

    PERSONNAGE | JUTSU | INVENTAIRE | CLAN | STATISTIQUES (+ VILLAGE, ADMIN)

    Ajouter un onglet depuis n'importe quel fichier client :
        NRP.UI.RegisterTab("mon_onglet", {
            name = "MON ONGLET", order = 50,
            visible = function() return true end,
            build = function(panel) ... end,
            refreshOn = { inventory = true },     -- clés de personnage qui déclenchent un rafraîchissement
            refreshOnStats = true,                -- rafraîchir quand les stats changent
        })
]]

local UI = NRP.UI
local S = UI.S

UI.Tabs = UI.Tabs or {}

NRP.Keys.Register("menu", { name = "Menu principal", default = KEY_F3, order = 0, clientOnly = true, allowWithCursor = true })

function UI.RegisterTab(id, def)
    def.id = id
    UI.Tabs[id] = def
end

local function SortedTabs()
    local list = {}
    for _, def in pairs(UI.Tabs) do
        if not def.visible or def.visible() then
            list[#list + 1] = def
        end
    end
    table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
    return list
end

local menu

local function BuildContent()
    if not IsValid(menu) then return end
    local def = UI.Tabs[menu.CurrentTab]
    menu.Content:Clear()
    menu.Content.PerformLayout = nil
    if def then
        local ok, err = pcall(def.build, menu.Content)
        if not ok then
            NRP.Error("Onglet " .. def.id .. " :", err)
            UI.Label(menu.Content, "Erreur d'affichage de l'onglet (voir console).", "NRP.Body", UI.Theme().Error)
        end
    end
end

function UI.SelectTab(id)
    if not IsValid(menu) or not UI.Tabs[id] then return end
    menu.CurrentTab = id
    UI.LastTab = id
    for tabId, btn in pairs(menu.TabButtons) do
        btn:SetStyle(tabId == id and "selected" or "ghost")
    end
    BuildContent()
end

function UI.RefreshMenu()
    if IsValid(menu) then BuildContent() end
end

function UI.IsMenuOpen()
    return IsValid(menu)
end

function UI.CloseMenu()
    if IsValid(menu) then menu:Remove() end
end

function UI.OpenMenu(tabId)
    if not NRP.Char.Local then return end
    UI.CloseMenu()

    local w = math.min(S(1280), ScrW() - S(40))
    local h = math.min(S(800), ScrH() - S(40))

    menu = vgui.Create("NRP.Frame")
    menu:SetSize(w, h)
    menu:Center()
    menu:SetHeader(NRP.Config.General.ServerName, NRP.Char.GetName(LocalPlayer()))
    menu:MakePopup()
    menu:SetKeyboardInputEnabled(false)
    menu.NRPKeyboardOff = true
    menu.TabButtons = {}

    local bar = vgui.Create("DPanel", menu)
    bar:Dock(TOP)
    bar:SetTall(S(40))
    bar:DockMargin(0, 0, 0, S(12))
    bar:SetPaintBackground(false)

    for _, def in ipairs(SortedTabs()) do
        local btn = vgui.Create("NRP.Button", bar)
        btn:SetLabel(def.name)
        btn:SetStyle("ghost")
        btn:SetFont("NRP.SmallBold")
        surface.SetFont("NRP.SmallBold")
        btn:SetWide(surface.GetTextSize(def.name) + S(32))
        btn:Dock(LEFT)
        btn:DockMargin(0, 0, S(6), 0)
        btn.DoClick = function()
            surface.PlaySound("naruto_sound/menu_select.mp3")
            UI.SelectTab(def.id)
        end
        menu.TabButtons[def.id] = btn
    end

    menu.Content = vgui.Create("DPanel", menu)
    menu.Content:Dock(FILL)
    menu.Content:SetPaintBackground(false)

    local first = SortedTabs()[1]
    local wanted = tabId or UI.LastTab
    UI.SelectTab((wanted and menu.TabButtons[wanted]) and wanted or (first and first.id))
    return menu
end

function UI.ToggleMenu()
    if IsValid(menu) then
        UI.CloseMenu()
    else
        UI.OpenMenu()
    end
end

NRP.Keys.OnPress("menu", UI.ToggleMenu)
concommand.Add("nrp_menu", function() UI.ToggleMenu() end)

-- Rafraîchissement ciblé (regroupé sur un court délai)
local function QueueRefresh()
    timer.Create("NRP.UI.MenuRefresh", 0.1, 1, UI.RefreshMenu)
end

hook.Add("NRP.CharSynced", "NRP.UI.MenuRefresh", function(changed, full)
    if not IsValid(menu) then return end
    local def = UI.Tabs[menu.CurrentTab]
    if not def then return end
    if full then return QueueRefresh() end
    for key in pairs(changed) do
        if def.refreshOn and def.refreshOn[key] then
            return QueueRefresh()
        end
    end
end)

hook.Add("NRP.StatsSynced", "NRP.UI.MenuRefresh", function()
    if not IsValid(menu) then return end
    local def = UI.Tabs[menu.CurrentTab]
    if def and def.refreshOnStats then QueueRefresh() end
end)

hook.Add("NRP.UIScaleChanged", "NRP.UI.MenuRebuild", function()
    if IsValid(menu) then
        local tab = menu.CurrentTab
        UI.OpenMenu(tab)
    end
end)

---------------------------------------------------------------------------
-- Aides partagées par les onglets
---------------------------------------------------------------------------

-- Deux colonnes redimensionnées automatiquement
function UI.Columns(parent, leftRatio)
    local left = vgui.Create("NRP.Scroll", parent)
    left:Dock(LEFT)
    left:DockMargin(0, 0, S(12), 0)

    local right = vgui.Create("NRP.Scroll", parent)
    right:Dock(FILL)

    parent.PerformLayout = function(self, w)
        if IsValid(left) then
            left:SetWide(math.floor(w * (leftRatio or 0.5)))
        end
    end
    return left, right
end

-- Ligne "clé : valeur"
function UI.KeyValue(parent, key, value, valueColor)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(S(26))
    row:SetPaintBackground(false)
    row.Paint = function(_, w, h)
        local theme = UI.Theme()
        UI.Text(key, "NRP.Small", 0, h / 2, theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        UI.Text(tostring(value), "NRP.BodyBold", w, h / 2, valueColor or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 8)
        surface.DrawRect(0, h - 1, w, 1)
    end
    return row
end

function UI.Local()
    return NRP.Char.Local or {}
end
