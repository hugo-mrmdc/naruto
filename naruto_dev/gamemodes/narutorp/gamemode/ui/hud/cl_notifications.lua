--[[
    HUD : notifications (toasts) et annonces plein écran
    Branchées sur les hooks "NRP.Notify" et "NRP.Announce" du core.
]]

local UI = NRP.UI
local S = UI.S

local toasts = {}
local announce

local KIND_COLORS = {
    [NRP.NOTIFY_INFO] = function(t) return t.Chakra end,
    [NRP.NOTIFY_SUCCESS] = function(t) return t.Success end,
    [NRP.NOTIFY_ERROR] = function(t) return t.Error end,
    [NRP.NOTIFY_WARNING] = function(t) return t.Warning end,
    [NRP.NOTIFY_XP] = function(t) return t.XP end,
}

hook.Add("NRP.Notify", "NRP.UI.Toasts", function(text, kind, duration)
    -- Fusionne les messages identiques successifs
    local last = toasts[#toasts]
    if last and last.text == text and last.die > CurTime() then
        last.count = last.count + 1
        last.die = CurTime() + (duration or 4)
        return true
    end

    toasts[#toasts + 1] = {
        text = text, kind = kind, count = 1,
        born = CurTime(), die = CurTime() + (duration or 4),
    }
    while #toasts > 6 do table.remove(toasts, 1) end

    if kind == NRP.NOTIFY_ERROR then
        surface.PlaySound("solve_naruto_base/ui/reroll_click_v2.wav")
    elseif kind ~= NRP.NOTIFY_XP then
        surface.PlaySound("solve_naruto_base/ui/menu_selection_v2.wav")
    end
    return true
end)

hook.Add("NRP.Announce", "NRP.UI.Announce", function(title, subtitle, color, duration)
    announce = { title = title, subtitle = subtitle, color = color, born = CurTime(), die = CurTime() + (duration or 5) }
    surface.PlaySound("solve_naruto_base/ui/unlock_jutsu.wav")
    return true
end)

hook.Add("HUDPaint", "NRP.UI.Notifications", function()
    local theme = UI.Theme()
    local now = CurTime()

    -- Toasts (colonne droite, sous les statuts)
    local y = ScrH() * 0.32
    for i = #toasts, 1, -1 do
        local t = toasts[i]
        if now > t.die + 0.3 then
            table.remove(toasts, i)
        end
    end

    for _, t in ipairs(toasts) do
        local fadeIn = math.Clamp((now - t.born) / 0.2, 0, 1)
        local fadeOut = math.Clamp((t.die + 0.3 - now) / 0.3, 0, 1)
        local alpha = 255 * math.min(fadeIn, fadeOut)
        local text = t.count > 1 and (t.text .. "  x" .. t.count) or t.text

        surface.SetFont("NRP.Small")
        local tw, th = surface.GetTextSize(text)
        local w, h = tw + S(28), th + S(14)
        local x = ScrW() - S(24) - w + (1 - fadeIn) * S(40)
        local col = (KIND_COLORS[t.kind] or KIND_COLORS[NRP.NOTIFY_INFO])(theme)

        UI.Box(x, y, w, h, UI.Alpha(theme.Background, 230 * alpha / 255), S(6))
        draw.RoundedBoxEx(S(6), x, y, S(4), h, UI.Alpha(col, alpha), true, false, true, false)
        UI.Text(text, "NRP.Small", x + S(16), y + h / 2, UI.Alpha(theme.Text, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        y = y + h + S(6)
    end

    -- Annonce centrale
    if announce then
        if now > announce.die then
            announce = nil
            return
        end
        local life = now - announce.born
        local alpha = 255 * math.min(1, life / 0.3, (announce.die - now) / 0.6)
        local cy = ScrH() * 0.18
        local col = announce.color or theme.Accent

        surface.SetDrawColor(0, 0, 0, alpha * 0.5)
        surface.DrawRect(0, cy - S(40), ScrW(), S(84))
        surface.SetDrawColor(col.r, col.g, col.b, alpha)
        surface.DrawRect(ScrW() / 2 - S(120), cy + S(42), S(240), S(2))

        UI.Text(announce.title, "NRP.Title", ScrW() / 2, cy - S(8), UI.Alpha(col, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
        UI.Text(announce.subtitle, "NRP.Body", ScrW() / 2, cy + S(22), UI.Alpha(theme.Text, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    end
end)
