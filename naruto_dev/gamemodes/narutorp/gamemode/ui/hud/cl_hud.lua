--[[
    HUD principal
        - bas gauche : identité, niveau, vie / chakra / endurance, XP, Ryo, dojutsu actif
        - bas centre : emplacements de jutsu (sélection, recharge, coût), incantation, outil équipé
        - haut droite : statuts actifs
        - centre : concentration, protection d'apparition, écran de K.O.
    Tout est calculé à partir de données déjà présentes côté client (aucune requête réseau).
]]

local UI = NRP.UI
local S = UI.S
local Jutsu = NRP.Jutsu
local CD = NRP.Cooldown

local cvHud = CreateClientConVar("nrp_hud", "1", true, false, "Afficher le HUD Naruto RP")

local smooth = { health = 0, chakra = 0, stamina = 0 }

local function Approach(key, target)
    smooth[key] = Lerp(math.min(1, FrameTime() * 10), smooth[key], target)
    return smooth[key]
end

local function DrawResourceBar(x, y, w, h, label, value, max, col)
    local theme = UI.Theme()
    UI.Bar(x, y, w, h, value / math.max(1, max), col)
    UI.Text(label, "NRP.Tiny", x + S(8), y + h / 2, theme.Text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, true)
    UI.Text(math.floor(value) .. " / " .. math.floor(max), "NRP.Tiny", x + w - S(8), y + h / 2, theme.Text,
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER, true)
end

---------------------------------------------------------------------------
-- Carte du personnage
---------------------------------------------------------------------------
local function DrawPlayerCard(ply, data)
    local theme = UI.Theme()
    local w, h = S(360), S(168)
    local x, y = S(24), ScrH() - h - S(24)

    UI.Box(x, y, w, h, theme.Background, S(10))

    -- Badge de niveau
    local badge = S(52)
    local bx, by = x + S(14), y + S(14)
    draw.RoundedBox(badge / 2, bx, by, badge, badge, theme.AccentDark)
    UI.Text(tostring(data.level or 1), "NRP.Header", bx + badge / 2, by + badge / 2 - S(2), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    UI.Text("NIV", "NRP.Tiny", bx + badge / 2, by + badge - S(8), UI.Alpha(color_white, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Identité
    local tx = bx + badge + S(12)
    UI.Text(NRP.Char.GetName(ply), "NRP.BodyBold", tx, by + S(2), theme.Text)

    local rank = NRP.Ranks.Get(data.rank)
    local village = NRP.Villages:Get(data.village)
    local rankW = UI.Text(rank and rank.name or "", "NRP.Small", tx, by + S(26), rank and rank.color or theme.TextDim)
    if village then
        UI.Text("  •  " .. village.name, "NRP.Small", tx + rankW, by + S(26), village.color)
    end

    -- Ryo
    UI.Text(NRP.Util.FormatNumber(data.ryo or 0) .. " Ryo", "NRP.SmallBold", x + w - S(14), by + S(4), theme.Ryo, TEXT_ALIGN_RIGHT)

    -- Barres
    local barX, barW, barH = x + S(14), w - S(28), S(18)
    local barY = by + badge + S(10)
    local hp = Approach("health", ply:Health())
    DrawResourceBar(barX, barY, barW, barH, "VIE", hp, ply:GetMaxHealth(), theme.Health)

    local chakra = Approach("chakra", NRP.Chakra.Get(ply))
    DrawResourceBar(barX, barY + barH + S(6), barW, barH, "CHAKRA", chakra, NRP.Chakra.GetMax(ply), theme.Chakra)

    local stamina = Approach("stamina", NRP.Stamina.Get(ply))
    DrawResourceBar(barX, barY + (barH + S(6)) * 2, barW, barH * 0.75, "ENDURANCE", stamina, NRP.Stamina.GetMax(ply), theme.Stamina)

    -- XP
    local xp, need = NRP.Progression.GetLevelProgress(data)
    local xpY = y + h - S(10)
    UI.Bar(barX, xpY, barW, S(4), xp / math.max(1, need), theme.XP)
    UI.Text(NRP.Util.FormatNumber(xp) .. " / " .. NRP.Util.FormatNumber(need) .. " XP", "NRP.Tiny", barX + barW, xpY - S(2),
        theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)

    -- Dojutsu actif
    local id, stageIndex, def = NRP.Dojutsu.GetActive(ply)
    if id and def then
        local stage = def.stages[stageIndex]
        local label = (stage and stage.name or def.name) .. string.format("  (-%.1f chakra/s)", stage and stage.drain or 0)
        UI.Text(label, "NRP.SmallBold", x + S(4), y - S(6), def.eye.color or theme.Accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, true)
    end

    -- Statut déserteur
    if NRP.Char.IsDeserter(ply) then
        UI.Text("DÉSERTEUR", "NRP.SmallBold", x + w - S(4), y - S(6), theme.Error, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, true)
    end
end

---------------------------------------------------------------------------
-- Emplacements de jutsu
---------------------------------------------------------------------------
local function DrawJutsuBar(ply, data)
    local theme = UI.Theme()
    local count = Jutsu.SlotCount()
    local size, gap = S(64), S(8)
    local total = count * size + (count - 1) * gap
    local x0 = math.floor(ScrW() / 2 - total / 2)
    local y = ScrH() - size - S(34)
    local loadout = data.loadout or {}

    UI.Box(x0 - S(10), y - S(10), total + S(20), size + S(36), UI.Alpha(theme.Background, 180), S(10))

    for i = 1, count do
        local x = x0 + (i - 1) * (size + gap)
        local id = loadout[i]
        local jutsu = id and id ~= "" and Jutsu.Registry:Get(id)
        local selected = Jutsu.SelectedSlot == i

        UI.Box(x, y, size, size, theme.Panel, S(6))
        if jutsu then
            UI.Icon(x + S(4), y + S(4), size - S(8), jutsu.icon, jutsu.name, UI.CategoryColor(jutsu))

            local frac = CD.Fraction(ply, "jutsu:" .. id)
            if frac > 0 then
                surface.SetDrawColor(0, 0, 0, 190)
                surface.DrawRect(x, y, size, size * frac)
                UI.Text(string.format("%.0f", math.ceil(CD.Remaining(ply, "jutsu:" .. id))), "NRP.Header",
                    x + size / 2, y + size / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
            end

            local cost = math.ceil(Jutsu.GetCost(ply, jutsu))
            local canPay = NRP.Chakra.Get(ply) >= cost
            UI.Text(tostring(cost), "NRP.Tiny", x + size - S(4), y + size - S(2),
                canPay and theme.Chakra or theme.Error, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, true)
        end

        UI.Text(tostring(i), "NRP.Tiny", x + S(5), y + S(2), theme.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, true)

        if selected then
            surface.SetDrawColor(theme.Accent)
            surface.DrawOutlinedRect(x - S(2), y - S(2), size + S(4), size + S(4), S(2))
        end
    end

    local selectedJutsu = Jutsu.GetSelected()
    local keyName = input.GetKeyName(NRP.Keys.Get(ply, "cast")) or "?"
    UI.Text(selectedJutsu and selectedJutsu.name or "Aucun jutsu", "NRP.SmallBold", ScrW() / 2, y + size + S(6),
        theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, true)
    UI.Text("[" .. string.upper(keyName) .. "]", "NRP.Tiny", x0 + total, y + size + S(8), theme.TextDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- Incantation en cours
    local castEnd = ply:GetNW2Float("NRP_CastEnd", 0)
    if castEnd > CurTime() then
        local duration = ply.NRPCastDuration or 1
        local frac = 1 - (castEnd - CurTime()) / math.max(0.01, duration)
        local casting = Jutsu.GetCasting(ply)
        local bw = S(300)
        UI.Bar(ScrW() / 2 - bw / 2, y - S(40), bw, S(14), frac, theme.Accent, casting and casting.name or "", "NRP.Tiny")
    end

    -- Recharges des actions
    local actions = {
        { "dash", "Dash" }, { "dodge", "Esquive" }, { "substitution", "Kawarimi" },
        { "throw", "Lancer" }, { "dojutsu", "Dojutsu" },
    }
    local ax = x0 + total + S(24)
    local ay = y + S(2)
    for i, a in ipairs(actions) do
        local remaining = CD.Remaining(ply, a[1])
        local col = remaining > 0 and theme.TextDim or theme.Text
        local text = a[2] .. (remaining > 0 and string.format(" %.0f", math.ceil(remaining)) or "")
        UI.Text(text, "NRP.Tiny", ax, ay + (i - 1) * S(13), col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, true)
    end

    -- Outil équipé
    local inv = data.inventory
    local toolId = inv and inv.equipped and inv.equipped.tool
    local tool = toolId and NRP.Inventory.Items:Get(toolId)
    if tool then
        local tx = x0 - S(24)
        UI.Icon(tx - S(40), y + S(12), S(40), tool.icon, tool.name, theme.TextDim)
        UI.Text("x" .. (inv.items[toolId] or 0), "NRP.SmallBold", tx - S(20), y + S(56), theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, true)
    end
end

---------------------------------------------------------------------------
-- Statuts
---------------------------------------------------------------------------
local function DrawStatuses(ply)
    local theme = UI.Theme()
    local list = NRP.Status.GetActive(ply)
    if #list == 0 then return end

    local x, y = ScrW() - S(24), S(24)
    for _, st in ipairs(list) do
        local text = st.def.name .. string.format("  %.1fs", st.remaining)
        surface.SetFont("NRP.SmallBold")
        local tw = surface.GetTextSize(text)
        UI.Box(x - tw - S(20), y, tw + S(20), S(26), UI.Alpha(theme.Background, 220), S(6))
        draw.RoundedBoxEx(S(6), x - tw - S(20), y, S(4), S(26), st.def.color or theme.Accent, true, false, true, false)
        UI.Text(text, "NRP.SmallBold", x - S(8), y + S(13), st.def.color or theme.Text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        y = y + S(30)
    end
end

---------------------------------------------------------------------------
-- Indications centrales
---------------------------------------------------------------------------
local function DrawCenter(ply)
    local theme = UI.Theme()
    local cx, cy = ScrW() / 2, ScrH() * 0.62

    if NRP.Chakra.IsFocusing(ply) then
        local pulse = 150 + math.sin(CurTime() * 4) * 80
        UI.Text("Concentration du chakra…", "NRP.BodyBold", cx, cy, UI.Alpha(theme.Chakra, pulse), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    end

    local protect = ply:GetNW2Float("NRP_SpawnProtect", 0) - CurTime()
    if protect > 0 then
        UI.Text(string.format("Protection d'apparition : %.0f s", math.ceil(protect)), "NRP.Small", cx, cy + S(24),
            theme.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    end

    if NRP.Combat.IsBlocking(ply) then
        UI.Text("GARDE", "NRP.SmallBold", cx, cy - S(24), theme.Chakra, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    end
end

local function DrawDeathScreen(ply)
    local theme = UI.Theme()
    surface.SetDrawColor(0, 0, 0, 170)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    local delay = NRP.Config.General.RespawnDelay or 5
    ply.NRPDeathSeen = ply.NRPDeathSeen or CurTime()
    local left = math.max(0, delay - (CurTime() - ply.NRPDeathSeen))

    UI.Text("K.O.", "NRP.Huge", ScrW() / 2, ScrH() / 2 - S(30), theme.Error, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
    UI.Text(left > 0 and string.format("Réapparition possible dans %.0f s", math.ceil(left)) or "Cliquez pour réapparaître",
        "NRP.Body", ScrW() / 2, ScrH() / 2 + S(20), theme.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, true)
end

local function DrawLowHealth(ply)
    local frac = ply:Health() / math.max(1, ply:GetMaxHealth())
    if frac > 0.3 then return end
    local a = (0.3 - frac) / 0.3 * (120 + math.sin(CurTime() * 5) * 40)
    local edge = S(120)
    surface.SetDrawColor(180, 0, 0, a)
    for i = 0, 8 do
        local alpha = a * (1 - i / 8)
        surface.SetDrawColor(180, 0, 0, alpha)
        local t = edge * i / 8
        surface.DrawOutlinedRect(t, t, ScrW() - t * 2, ScrH() - t * 2, math.ceil(edge / 8))
    end
end

hook.Add("HUDPaint", "NRP.HUD", function()
    if not cvHud:GetBool() then return end
    local ply = LocalPlayer()
    local data = NRP.Char.Local
    if not IsValid(ply) or not data then return end

    if not ply:Alive() then
        DrawDeathScreen(ply)
        return
    end
    ply.NRPDeathSeen = nil

    DrawLowHealth(ply)
    DrawPlayerCard(ply, data)
    DrawJutsuBar(ply, data)
    DrawStatuses(ply)
    DrawCenter(ply)
end)

-- Durée de l'incantation locale (pour la barre de progression)
hook.Add("NRP.JutsuFX", "NRP.HUD.CastDuration", function(ply, jutsu, event, duration)
    if event == 1 then
        ply.NRPCastDuration = duration
    end
end)

-- Le sélecteur d'arme par défaut reste visible pour les joueurs ayant le sandbox
hook.Add("HUDShouldDraw", "NRP.HUD.WeaponSelection", function(name)
    if name == "CHudWeaponSelection" and NRP.Perm.Has(LocalPlayer(), "admin.sandbox") then
        return true
    end
end)
