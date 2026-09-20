--[[
    Core : touches configurables

    Chaque action déclare une touche. Le client choisit sa touche via une convar
    "nrp_bind_<id>" marquée USERINFO : le serveur la lit avec ply:GetInfoNum() et
    réagit directement à PlayerButtonDown. Aucun message réseau n'est nécessaire
    et le serveur reste seul juge de ce qui se passe.

        NRP.Keys.Register("block", { name = "Bloquer", default = KEY_F, order = 10 })
        NRP.Keys.OnPress("block", function(ply) ... end)       -- serveur ou client
        NRP.Keys.OnRelease("block", function(ply) ... end)

    Une touche "clientOnly" (menu, lancement de jutsu) n'est traitée que côté client ;
    "allowWithCursor" l'autorise quand un menu est ouvert.
]]

NRP.Keys = NRP.Keys or {}
local Keys = NRP.Keys

Keys.List = Keys.List or {}
Keys.Press = Keys.Press or {}
Keys.Release = Keys.Release or {}

function Keys.Register(id, def)
    def.id = id
    def.convar = "nrp_bind_" .. id
    Keys.List[id] = def

    if CLIENT then
        CreateClientConVar(def.convar, tostring(def.default or KEY_NONE), true, not def.clientOnly,
            "Touche Naruto RP : " .. (def.name or id))
    end
end

function Keys.Get(ply, id)
    local def = Keys.List[id]
    if not def then return KEY_NONE end

    if CLIENT then
        local cvar = GetConVar(def.convar)
        return cvar and cvar:GetInt() or (def.default or KEY_NONE)
    end
    return ply:GetInfoNum(def.convar, def.default or KEY_NONE)
end

function Keys.OnPress(id, fn)
    Keys.Press[id] = fn
end

function Keys.OnRelease(id, fn)
    Keys.Release[id] = fn
end

function Keys.Sorted()
    local out = {}
    for _, def in pairs(Keys.List) do
        out[#out + 1] = def
    end
    table.sort(out, function(a, b) return (a.order or 99) < (b.order or 99) end)
    return out
end

if SERVER then
    -- Touches de gameplay : le serveur reçoit directement les appuis (aussi en solo).
    local function Dispatch(handlers, ply, button)
        for id, fn in pairs(handlers) do
            local def = Keys.List[id]
            if def and not def.clientOnly and Keys.Get(ply, id) == button then
                fn(ply, button)
            end
        end
    end

    hook.Add("PlayerButtonDown", "NRP.Keys", function(ply, button)
        Dispatch(Keys.Press, ply, button)
    end)

    hook.Add("PlayerButtonUp", "NRP.Keys", function(ply, button)
        Dispatch(Keys.Release, ply, button)
    end)
else
    --[[
        Touches purement client (menu, lancement de jutsu).
        PlayerButtonDown est un hook prédit : en solo il n'est pas appelé côté client.
        On détecte donc les fronts d'appui nous-mêmes, uniquement pour ces quelques touches.
    ]]
    local held = {}

    hook.Add("Think", "NRP.Keys.Client", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local blocked = vgui.GetKeyboardFocus() ~= nil or gui.IsGameUIVisible() or ply:IsTyping()
        local cursor = vgui.CursorVisible()

        for id, def in pairs(Keys.List) do
            if def.clientOnly then
                local code = Keys.Get(ply, id)
                local down = code ~= KEY_NONE and input.IsButtonDown(code)
                if down ~= (held[id] == true) then
                    held[id] = down
                    local usable = not blocked and (not cursor or def.allowWithCursor)
                    local fn = down and Keys.Press[id] or Keys.Release[id]
                    if fn and usable then
                        fn(ply, code)
                    end
                end
            end
        end
    end)
end
