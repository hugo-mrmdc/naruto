--[[
    HUD : bannière d'événement (avec balise) + fenêtre d'invitation d'échange
]]

local UI = NRP.UI
local S = UI.S

local UNITS_TO_METERS = 0.01905

local function DrawWaypoint(pos, label, col)
    local screen = (pos + Vector(0, 0, 40)):ToScreen()
    local x, y = screen.x, screen.y
    local margin = S(40)
    local onScreen = screen.visible and x > margin and x < ScrW() - margin and y > margin and y < ScrH() - margin

    if not onScreen then
        -- Ramène la balise sur le bord de l'écran
        if not screen.visible then
            x, y = ScrW() - x, ScrH() - y
        end
        x = math.Clamp(x, margin, ScrW() - margin)
        y = math.Clamp(y, margin, ScrH() - margin)
    end

    local dist = math.floor(LocalPlayer():GetPos():Distance(pos) * UNITS_TO_METERS)
    local size = S(10)
    draw.NoTexture()
    surface.SetDrawColor(col)
    surface.DrawPoly({
        { x = x, y = y - size }, { x = x + size, y = y }, { x = x, y = y + size }, { x = x - size, y = y },
    })
    UI.Text(label, "NRP.SmallBold", x, y - size - S(2), col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, true)
    UI.Text(dist .. " m", "NRP.Tiny", x, y + size + S(2), UI.Theme().Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, true)
end

hook.Add("HUDPaint", "NRP.UI.Tracker", function()
    local theme = UI.Theme()
    local x, y = ScrW() - S(344), ScrH() * 0.55
    local w = S(320)

    -- Événement
    local ev = NRP.Events.GetCurrent()
    if ev then
        local lines = ev.name
        local mult = ev.multipliers or {}
        local bonus = {}
        if (mult.xp or 1) ~= 1 then bonus[#bonus + 1] = "XP x" .. mult.xp end
        if (mult.ryo or 1) ~= 1 then bonus[#bonus + 1] = "Ryo x" .. mult.ryo end

        UI.Box(x, y - S(74), w, S(64), UI.Alpha(theme.Background, 220), S(8))
        draw.RoundedBoxEx(S(8), x, y - S(74), S(4), S(64), theme.Warning, true, false, true, false)
        UI.Text("ÉVÉNEMENT", "NRP.Tiny", x + S(14), y - S(68), theme.Warning)
        UI.Text(UI.Ellipsis(lines, "NRP.BodyBold", w - S(28)), "NRP.BodyBold", x + S(14), y - S(54), theme.Text)
        UI.Text(NRP.Util.FormatTime((ev.endTime or 0) - CurTime()) .. "   " .. table.concat(bonus, "  ") .. "   !event join",
            "NRP.Tiny", x + S(14), y - S(30), theme.TextDim)

        if ev.pos then
            DrawWaypoint(ev.pos, ev.name, theme.Warning)
        end
    end
end)

---------------------------------------------------------------------------
-- Invitations
---------------------------------------------------------------------------

hook.Add("NRP.TradePrompt", "NRP.UI.TradePrompt", function(from)
    UI.Confirm("Demande d'échange", from:Nick() .. " souhaite faire un échange avec vous.",
        function() NRP.Inventory.RespondTrade(true) end,
        function() NRP.Inventory.RespondTrade(false) end,
        NRP.Config.InventorySettings.TradeRequestTimeout)
end)
