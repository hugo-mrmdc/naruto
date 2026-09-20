--[[
    UI : thème, mise à l'échelle et aides de dessin

    Toutes les tailles sont exprimées pour un écran 1080p et converties avec NRP.UI.S(px).
    Les polices sont recréées quand la résolution change (hook "NRP.UIScaleChanged").
]]

NRP.UI = NRP.UI or {}
local UI = NRP.UI

function UI.Theme()
    return NRP.Config.General.Theme
end

function UI.S(px)
    return math.max(1, math.Round(px * ScrH() / 1080))
end

local FONTS = {
    { "NRP.Huge", 44, 800 },
    { "NRP.Title", 30, 700 },
    { "NRP.Header", 22, 700 },
    { "NRP.Body", 18, 500 },
    { "NRP.BodyBold", 18, 700 },
    { "NRP.Small", 15, 500 },
    { "NRP.SmallBold", 15, 700 },
    { "NRP.Tiny", 12, 600 },
}

function UI.CreateFonts()
    for _, f in ipairs(FONTS) do
        surface.CreateFont(f[1], {
            font = "Roboto",
            extended = true,
            size = UI.S(f[2]),
            weight = f[3],
            antialias = true,
        })
    end
end

UI.CreateFonts()

hook.Add("OnScreenSizeChanged", "NRP.UI.Fonts", function()
    UI.CreateFonts()
    hook.Run("NRP.UIScaleChanged")
end)

---------------------------------------------------------------------------
-- Dessin
---------------------------------------------------------------------------

function UI.Alpha(col, a)
    return Color(col.r, col.g, col.b, a)
end

function UI.Box(x, y, w, h, col, radius)
    draw.RoundedBox(radius or UI.S(6), x, y, w, h, col)
end

function UI.Outline(x, y, w, h, col, thickness)
    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, thickness or 1)
end

function UI.Text(text, font, x, y, col, ax, ay, shadow)
    if shadow then
        draw.SimpleText(text, font, x + 1, y + 1, Color(0, 0, 0, math.min(col.a or 255, 180)), ax, ay)
    end
    return draw.SimpleText(text, font, x, y, col, ax, ay)
end

-- Barre de progression avec texte optionnel centré
function UI.Bar(x, y, w, h, frac, col, text, font)
    local theme = UI.Theme()
    frac = math.Clamp(frac or 0, 0, 1)
    local r = math.floor(h / 2)
    draw.RoundedBox(r, x, y, w, h, Color(0, 0, 0, 150))
    if frac > 0 then
        draw.RoundedBox(r, x, y, math.max(h, w * frac), h, col)
        surface.SetDrawColor(255, 255, 255, 25)
        surface.DrawRect(x + r, y + 1, math.max(0, w * frac - r * 2), math.floor(h / 3))
    end
    if text then
        UI.Text(text, font or "NRP.Tiny", x + w / 2, y + h / 2, theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    end
end

-- Matériaux d'icônes (avec repli si le fichier n'existe pas)
local materials = {}
function UI.Material(path)
    if not path or path == "" then return nil end
    local mat = materials[path]
    if mat == nil then
        mat = Material(path, "smooth mips")
        if mat:IsError() then mat = false end
        materials[path] = mat
    end
    return mat or nil
end

local function Initials(name)
    name = tostring(name or "?")
    local clean = string.gsub(name, "^[^:]*:%s*", "")
    local out = ""
    for word in string.gmatch(clean, "[^%s%-']+") do
        out = out .. utf8.char(utf8.codepoint(word, 1))
        if #out >= 2 then break end
    end
    return string.upper(out ~= "" and out or "?")
end

-- Icône d'un contenu : matériau, sinon pastille colorée avec initiales
function UI.Icon(x, y, size, iconPath, name, col)
    local mat = UI.Material(iconPath)
    if mat then
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(mat)
        surface.DrawTexturedRect(x, y, size, size)
        return
    end

    col = col or UI.Theme().Accent
    draw.RoundedBox(UI.S(6), x, y, size, size, Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 240))
    surface.SetDrawColor(col.r, col.g, col.b, 200)
    surface.DrawOutlinedRect(x, y, size, size, math.max(1, UI.S(2)))
    local font = size >= UI.S(56) and "NRP.Header" or (size >= UI.S(36) and "NRP.BodyBold" or "NRP.Tiny")
    UI.Text(Initials(name), font, x + size / 2, y + size / 2, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local blur = Material("pp/blurscreen")
function UI.Blur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blur)
    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * (amount or 4))
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, ScrW(), ScrH())
    end
end

-- Tronque un texte avec "…" pour tenir dans maxWidth
local ellipsisCache, ellipsisCount = {}, 0

function UI.Ellipsis(text, font, maxWidth)
    local key = font .. maxWidth .. text
    local cached = ellipsisCache[key]
    if cached then return cached end

    surface.SetFont(font)
    local result = "…"
    if surface.GetTextSize(text) <= maxWidth then
        result = text
    else
        local len = utf8.len(text) or #text
        while len > 1 do
            len = len - 1
            local cut = utf8.sub and utf8.sub(text, 1, len) or string.sub(text, 1, len)
            if surface.GetTextSize(cut .. "…") <= maxWidth then
                result = cut .. "…"
                break
            end
        end
    end

    ellipsisCount = ellipsisCount + 1
    if ellipsisCount > 512 then
        ellipsisCache, ellipsisCount = {}, 0
    end
    ellipsisCache[key] = result
    return result
end

function UI.FormatPercent(value)
    return string.format("%+.0f%%", (value - 1) * 100)
end

function UI.CategoryColor(jutsu)
    local cat = NRP.Jutsu.Categories:Get(jutsu.category)
    return cat and cat.color or UI.Theme().Accent
end
