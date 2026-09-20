--[[
    Core : notifications, messages de chat colorés et annonces globales

    Serveur :
        NRP.Notify(ply, "texte", NRP.NOTIFY_ERROR)   -- ply peut être une table de joueurs ou nil (= tous)
        NRP.ChatPrint(ply, Color(...), "texte", ...)
        NRP.Announce("Titre", "Sous-titre", color, durée)
    Client :
        hook "NRP.Notify"(text, kind, duration)  -> l'UI dessine les toasts
        hook "NRP.Announce"(title, subtitle, color, duration)
]]

NRP.NOTIFY_INFO = 0
NRP.NOTIFY_SUCCESS = 1
NRP.NOTIFY_ERROR = 2
NRP.NOTIFY_WARNING = 3
NRP.NOTIFY_XP = 4

if SERVER then
    NRP.Net.Pool("Notify")
    NRP.Net.Pool("ChatMsg")
    NRP.Net.Pool("Announce")

    local function Send(target)
        if target == nil then
            net.Broadcast()
        else
            net.Send(target)
        end
    end

    function NRP.Notify(target, text, kind, duration)
        if target == NULL then
            NRP.Print(text)
            return
        end
        if target ~= nil and not istable(target) and not IsValid(target) then return end

        NRP.Net.Start("Notify")
            net.WriteString(string.sub(tostring(text), 1, 512))
            net.WriteUInt(kind or NRP.NOTIFY_INFO, 3)
            net.WriteFloat(duration or 4)
        Send(target)
    end

    function NRP.ChatPrint(target, ...)
        local args = { ... }
        if target == NULL then
            local plain = {}
            for _, v in ipairs(args) do
                if isstring(v) then plain[#plain + 1] = v end
            end
            NRP.Print(table.concat(plain))
            return
        end

        NRP.Net.Start("ChatMsg")
            net.WriteUInt(math.min(#args, 31), 5)
            for i = 1, math.min(#args, 31) do
                local v = args[i]
                if IsColor(v) or (istable(v) and v.r) then
                    net.WriteBool(true)
                    net.WriteColor(Color(v.r, v.g, v.b, 255), false)
                else
                    net.WriteBool(false)
                    net.WriteString(tostring(v))
                end
            end
        Send(target)
    end

    function NRP.Announce(title, subtitle, color, duration, target)
        NRP.Net.Start("Announce")
            net.WriteString(tostring(title or ""))
            net.WriteString(tostring(subtitle or ""))
            net.WriteColor(color or Color(255, 140, 30), false)
            net.WriteFloat(duration or 6)
        Send(target)
    end
else
    NRP.Net.Receive("Notify", function()
        local text = net.ReadString()
        local kind = net.ReadUInt(3)
        local duration = net.ReadFloat()
        NRP.NotifyLocal(text, kind, duration)
    end)

    function NRP.NotifyLocal(text, kind, duration)
        if hook.Run("NRP.Notify", text, kind, duration) then return end

        local legacy = {
            [NRP.NOTIFY_INFO] = NOTIFY_GENERIC,
            [NRP.NOTIFY_SUCCESS] = NOTIFY_GENERIC,
            [NRP.NOTIFY_ERROR] = NOTIFY_ERROR,
            [NRP.NOTIFY_WARNING] = NOTIFY_HINT,
            [NRP.NOTIFY_XP] = NOTIFY_GENERIC,
        }
        notification.AddLegacy(text, legacy[kind] or NOTIFY_GENERIC, duration or 4)
    end

    NRP.Net.Receive("ChatMsg", function()
        local parts = {}
        for _ = 1, net.ReadUInt(5) do
            if net.ReadBool() then
                parts[#parts + 1] = net.ReadColor(false)
            else
                parts[#parts + 1] = net.ReadString()
            end
        end
        chat.AddText(unpack(parts))
    end)

    NRP.Net.Receive("Announce", function()
        local title = net.ReadString()
        local subtitle = net.ReadString()
        local color = net.ReadColor(false)
        local duration = net.ReadFloat()
        if not hook.Run("NRP.Announce", title, subtitle, color, duration) then
            chat.AddText(color, title, " ", color_white, subtitle)
        end
    end)
end
