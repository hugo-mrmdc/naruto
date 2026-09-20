--[[
    Core : cooldowns

    Le serveur est la seule source de vérité. Chaque cooldown posé est envoyé au seul joueur
    concerné (pour l'affichage HUD) ; les autres joueurs ne reçoivent rien.

        NRP.Cooldown.Set(ply, "jutsu:katon_fireball", 6)
        NRP.Cooldown.IsActive(ply, "dash")
        NRP.Cooldown.Remaining(ply, "dash")
]]

NRP.Cooldown = NRP.Cooldown or {}
local CD = NRP.Cooldown

if SERVER then
    NRP.Net.Pool("Cooldown")

    local function Store(ply)
        local t = ply.NRPCooldowns
        if not t then
            t = {}
            ply.NRPCooldowns = t
        end
        return t
    end

    function CD.Get(ply, key)
        local entry = Store(ply)[key]
        return entry and entry[1] or 0, entry and entry[2] or 0
    end

    function CD.Set(ply, key, duration, silent)
        duration = math.max(0, tonumber(duration) or 0)
        local endTime = CurTime() + duration
        local store = Store(ply)

        if duration <= 0 then
            store[key] = nil
        else
            store[key] = { endTime, duration }
        end

        if not silent then
            NRP.Net.Start("Cooldown")
                net.WriteString(key)
                net.WriteDouble(endTime)
                net.WriteFloat(duration)
            net.Send(ply)
        end
    end

    function CD.Reset(ply, key)
        CD.Set(ply, key, 0)
    end

    function CD.ClearAll(ply)
        ply.NRPCooldowns = {}
        NRP.Net.Start("Cooldown")
            net.WriteString("*")
            net.WriteDouble(0)
            net.WriteFloat(0)
        net.Send(ply)
    end
else
    local store = {}

    NRP.Net.Receive("Cooldown", function()
        local key = net.ReadString()
        local endTime = net.ReadDouble()
        local duration = net.ReadFloat()

        if key == "*" then
            store = {}
            return
        end

        if duration <= 0 then
            store[key] = nil
        else
            store[key] = { endTime, duration }
        end
    end)

    function CD.Get(ply, key)
        if ply ~= LocalPlayer() then return 0, 0 end
        local entry = store[key]
        return entry and entry[1] or 0, entry and entry[2] or 0
    end
end

function CD.Remaining(ply, key)
    local endTime = CD.Get(ply, key)
    return math.max(0, endTime - CurTime())
end

function CD.IsActive(ply, key)
    return CD.Remaining(ply, key) > 0
end

-- Fraction restante (1 -> vient de commencer, 0 -> terminé), pour les HUD.
function CD.Fraction(ply, key)
    local endTime, duration = CD.Get(ply, key)
    if duration <= 0 then return 0 end
    return math.Clamp((endTime - CurTime()) / duration, 0, 1)
end
