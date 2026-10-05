--[[
    UI : composants réutilisables
        NRP.Frame     fenêtre sans barre Windows, titre + fermeture, fond flouté
        NRP.Button    bouton ("primary" | "ghost" | "danger"), état désactivé avec raison
        NRP.Scroll    zone défilante stylisée
        NRP.Card      panneau de fond
    Aides : UI.Label, UI.TextEntry, UI.Combo, UI.Section, UI.Confirm, UI.RequestText
]]

local UI = NRP.UI
local S = UI.S

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local FRAME = {}

function FRAME:Init()
    self:SetTitle("")
    self:ShowCloseButton(false)
    self:SetDraggable(true)
    self:DockPadding(S(16), S(56), S(16), S(16))
    self.TitleText = ""
    self.SubtitleText = ""

    self.CloseBtn = vgui.Create("DButton", self)
    self.CloseBtn:SetText("")
    self.CloseBtn.DoClick = function() self:Close() end
    self.CloseBtn.Paint = function(btn, w, h)
        local col = btn:IsHovered() and UI.Theme().Error or UI.Theme().TextDim
        UI.Text("×", "NRP.Title", w / 2, h / 2, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

function FRAME:SetHeader(title, subtitle)
    self.TitleText = title or ""
    self.SubtitleText = subtitle or ""
end

function FRAME:SetClosable(closable)
    self.CloseBtn:SetVisible(closable)
end

function FRAME:PerformLayout(w, h)
    self.CloseBtn:SetSize(S(40), S(40))
    self.CloseBtn:SetPos(w - S(48), S(8))
end

function FRAME:Paint(w, h)
    local theme = UI.Theme()
    UI.Blur(self, 3)
    UI.Box(0, 0, w, h, theme.Background, S(10))
    UI.Box(0, 0, w, S(48), theme.Panel, S(10))
    surface.SetDrawColor(theme.Accent)
    surface.DrawRect(0, S(46), w, S(2))

    local x = S(18)
    local tw = UI.Text(self.TitleText, "NRP.Header", x, S(24), theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if self.SubtitleText ~= "" then
        UI.Text(self.SubtitleText, "NRP.Small", x + tw + S(12), S(25), theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

vgui.Register("NRP.Frame", FRAME, "DFrame")

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------
local BUTTON = {}

function BUTTON:Init()
    self:SetText("")
    self.Label = ""
    self.Style = "primary"
    self.Font = "NRP.BodyBold"
    self:SetTall(S(36))
end

function BUTTON:SetLabel(text)
    self.Label = text
end

function BUTTON:SetStyle(style)
    self.Style = style
end

function BUTTON:SetFont(font)
    self.Font = font
end

function BUTTON:SetDisabledReason(reason)
    self:SetEnabled(reason == nil)
    self:SetTooltip(reason)
end

function BUTTON:Paint(w, h)
    local theme = UI.Theme()
    local enabled = self:IsEnabled()
    local hovered = enabled and self:IsHovered()
    local bg, fg

    if not enabled then
        bg, fg = Color(60, 60, 66, 200), theme.TextDim
    elseif self.Style == "ghost" then
        bg = hovered and theme.PanelLight or Color(0, 0, 0, 0)
        fg = hovered and theme.Accent or theme.Text
    elseif self.Style == "danger" then
        bg = hovered and Color(250, 90, 90) or theme.Error
        fg = color_white
    elseif self.Style == "selected" then
        bg, fg = theme.AccentDark, color_white
    else
        bg = hovered and theme.Accent or theme.AccentDark
        fg = color_white
    end

    UI.Box(0, 0, w, h, bg, S(6))
    if self.Style == "ghost" then
        UI.Outline(0, 0, w, h, UI.Alpha(theme.TextDim, 60))
    end
    UI.Text(self.Label, self.Font, w / 2, h / 2, fg, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function BUTTON:OnCursorEntered()
    if self:IsEnabled() then surface.PlaySound("solve_naruto_base/ui/menu_selection_v2.wav") end
end

vgui.Register("NRP.Button", BUTTON, "DButton")

---------------------------------------------------------------------------
-- Scroll
---------------------------------------------------------------------------
local SCROLL = {}

function SCROLL:Init()
    local bar = self:GetVBar()
    bar:SetWide(S(8))
    bar:SetHideButtons(true)
    bar.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, Color(0, 0, 0, 80), S(4))
    end
    bar.btnGrip.Paint = function(grip, w, h)
        UI.Box(0, 0, w, h, grip:IsHovered() and UI.Theme().Accent or UI.Theme().PanelLight, S(4))
    end
end

vgui.Register("NRP.Scroll", SCROLL, "DScrollPanel")

---------------------------------------------------------------------------
-- Card
---------------------------------------------------------------------------
local CARD = {}

function CARD:Init()
    self.Color = nil
    self:DockPadding(S(12), S(12), S(12), S(12))
end

function CARD:SetAccent(col)
    self.Color = col
end

function CARD:Paint(w, h)
    UI.Box(0, 0, w, h, UI.Theme().Panel, S(8))
    if self.Color then
        draw.RoundedBoxEx(S(8), 0, 0, S(4), h, self.Color, true, false, true, false)
    end
end

vgui.Register("NRP.Card", CARD, "DPanel")

---------------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------------

function UI.Label(parent, text, font, col, dock)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetFont(font or "NRP.Body")
    lbl:SetTextColor(col or UI.Theme().Text)
    lbl:SetText(text or "")
    lbl:SetWrap(true)
    lbl:SetAutoStretchVertical(true)
    if dock ~= false then
        lbl:Dock(dock or TOP)
        lbl:DockMargin(0, 0, 0, S(4))
    end
    return lbl
end

function UI.Section(parent, title)
    local lbl = UI.Label(parent, string.upper(title), "NRP.SmallBold", UI.Theme().Accent)
    lbl:DockMargin(0, S(10), 0, S(6))
    return lbl
end

function UI.Button(parent, label, onClick, style)
    local btn = vgui.Create("NRP.Button", parent)
    btn:SetLabel(label)
    btn:SetStyle(style or "primary")
    btn.DoClick = function(self)
        surface.PlaySound("naruto_sound/menu_select.mp3")
        if onClick then onClick(self) end
    end
    return btn
end

function UI.TextEntry(parent, placeholder)
    local entry = vgui.Create("DTextEntry", parent)
    entry:SetFont("NRP.Body")
    entry:SetTall(S(36))
    entry:SetPlaceholderText(placeholder or "")
    entry:SetPaintBackground(false)
    entry.Paint = function(self, w, h)
        local theme = UI.Theme()
        UI.Box(0, 0, w, h, theme.PanelLight, S(6))
        if self:HasFocus() then
            UI.Outline(0, 0, w, h, theme.Accent, S(1))
        end
        self:DrawTextEntryText(theme.Text, theme.Accent, theme.Text)
        if self:GetText() == "" and not self:HasFocus() then
            UI.Text(self:GetPlaceholderText() or "", "NRP.Body", S(6), h / 2, theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Les fenêtres qui laissent le clavier au jeu (menu principal) l'activent le temps de la saisie
    local function TopFrame()
        local top = entry
        while IsValid(top:GetParent()) and top:GetParent() ~= vgui.GetWorldPanel() do
            top = top:GetParent()
        end
        return top
    end
    entry.OnGetFocus = function()
        local top = TopFrame()
        if top.NRPKeyboardOff then top:SetKeyboardInputEnabled(true) end
    end
    entry.OnLoseFocus = function(self)
        local top = TopFrame()
        if top.NRPKeyboardOff then top:SetKeyboardInputEnabled(false) end
        self:UpdateConvarValue()
        hook.Call("OnTextEntryLoseFocus", nil, self)
    end
    return entry
end

function UI.Combo(parent, choices, onSelect)
    local combo = vgui.Create("DComboBox", parent)
    combo:SetTall(S(34))
    combo:SetFont("NRP.Body")
    combo:SetTextColor(UI.Theme().Text)
    combo.Paint = function(self, w, h)
        UI.Box(0, 0, w, h, UI.Theme().PanelLight, S(6))
    end
    for _, c in ipairs(choices or {}) do
        combo:AddChoice(c[1], c[2], c[3])
    end
    combo.OnSelect = function(_, _, text, data)
        if onSelect then onSelect(data, text) end
    end
    return combo
end

-- Petite fenêtre de confirmation (avec expiration optionnelle)
function UI.Confirm(title, text, onYes, onNo, timeout, yesLabel, noLabel)
    local frame = vgui.Create("NRP.Frame")
    frame:SetSize(S(440), S(210))
    frame:Center()
    frame:SetHeader(title)
    frame:MakePopup()

    UI.Label(frame, text, "NRP.Body")

    local buttons = vgui.Create("DPanel", frame)
    buttons:Dock(BOTTOM)
    buttons:SetTall(S(38))
    buttons:SetPaintBackground(false)

    local answered = false
    local function Answer(yes)
        if answered then return end
        answered = true
        if yes and onYes then onYes() end
        if not yes and onNo then onNo() end
        if IsValid(frame) then frame:Remove() end
    end

    local yes = UI.Button(buttons, yesLabel or "Accepter", function() Answer(true) end)
    yes:Dock(LEFT)
    yes:SetWide(S(196))
    local no = UI.Button(buttons, noLabel or "Refuser", function() Answer(false) end, "ghost")
    no:Dock(RIGHT)
    no:SetWide(S(196))

    frame.OnClose = function() Answer(false) end

    if timeout then
        timer.Simple(timeout, function()
            if IsValid(frame) then Answer(false) end
        end)
    end
    return frame
end

-- Saisie de texte / nombre
function UI.RequestText(title, text, default, onDone, numeric)
    local frame = vgui.Create("NRP.Frame")
    frame:SetSize(S(420), S(220))
    frame:Center()
    frame:SetHeader(title)
    frame:MakePopup()

    UI.Label(frame, text, "NRP.Body")
    local entry = UI.TextEntry(frame)
    entry:Dock(TOP)
    entry:SetText(tostring(default or ""))
    entry:SetNumeric(numeric == true)
    entry:RequestFocus()

    local function Submit()
        local value = entry:GetValue()
        frame:Remove()
        if onDone then onDone(value) end
    end
    entry.OnEnter = Submit

    local ok = UI.Button(frame, "Valider", Submit)
    ok:Dock(BOTTOM)
    return frame
end
