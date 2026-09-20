--[[
    UI : fiche d'inspection d'un personnage (commande !inspect / !inspectid)
]]

local UI = NRP.UI
local S = UI.S

local function AddNode(tree, parentNode, key, value, depth)
    if istable(value) then
        local node = (parentNode or tree):AddNode(tostring(key), "icon16/folder.png")
        local keys = table.GetKeys(value)
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            AddNode(tree, node, k, value[k], depth + 1)
        end
        if depth < 1 then node:SetExpanded(true) end
    else
        local text = tostring(key) .. " = " .. tostring(value)
        if isnumber(value) and math.floor(value) ~= value then
            text = tostring(key) .. " = " .. string.format("%.2f", value)
        end
        (parentNode or tree):AddNode(text, "icon16/bullet_orange.png")
    end
end

hook.Add("NRP.AdminInspect", "NRP.UI.Inspect", function(data)
    local theme = UI.Theme()
    local extra = data.extra or {}
    data.extra = nil

    local frame = vgui.Create("NRP.Frame")
    frame:SetSize(math.min(S(760), ScrW() - S(40)), math.min(S(760), ScrH() - S(40)))
    frame:Center()
    frame:SetHeader("Fiche : " .. (data.firstname or "?") .. " " .. (data.lastname or ""),
        extra.online and "en ligne" or "hors ligne")
    frame:MakePopup()

    local summary = vgui.Create("NRP.Card", frame)
    summary:Dock(TOP)
    summary:SetTall(S(150))
    summary:DockMargin(0, 0, 0, S(10))

    local village = NRP.Villages:Get(data.village)
    local rank = NRP.Ranks.Get(data.rank)
    UI.KeyValue(summary, "SteamID64", tostring(data.steamid))
    UI.KeyValue(summary, "Village / Clan", (village and village.name or "?") .. " / " .. NRP.Clans.GetName(data.clan))
    UI.KeyValue(summary, "Grade / Niveau", (rank and rank.name or "?") .. " / " .. tostring(data.level))
    UI.KeyValue(summary, "Ryo", NRP.Util.FormatNumber(data.ryo or 0), theme.Ryo)
    if extra.online then
        UI.KeyValue(summary, "Vie / Chakra", string.format("%d/%d  —  %d/%d", extra.health or 0, extra.maxHealth or 0,
            extra.chakra or 0, extra.maxChakra or 0))
    end

    local tree = vgui.Create("DTree", frame)
    tree:Dock(FILL)
    tree.Paint = function(_, w, h)
        UI.Box(0, 0, w, h, Color(235, 235, 235), S(6))
    end

    AddNode(tree, nil, "Personnage", data, 0)
    if next(extra) then
        AddNode(tree, nil, "Session", extra, 0)
    end

    local copy = UI.Button(frame, "Copier en JSON", function()
        SetClipboardText(util.TableToJSON(data, true))
        NRP.NotifyLocal("Fiche copiée dans le presse-papiers.", NRP.NOTIFY_SUCCESS, 2)
    end, "ghost")
    copy:Dock(BOTTOM)
    copy:DockMargin(0, S(8), 0, 0)
end)
