--[[
    Module : événements RP (partagé)
    Un événement est annoncé à tous, peut multiplier l'XP / les Ryo et récompenser ses participants.
        NRP.Events.GetMultiplier("xp")
]]

NRP.Events = NRP.Events or {}
local Events = NRP.Events

function Events.GetCurrent()
    local ev = Events.Current
    if ev and ev.endTime and ev.endTime < CurTime() then
        return nil
    end
    return ev
end

function Events.GetMultiplier(kind)
    local ev = Events.GetCurrent()
    return ev and ev.multipliers and tonumber(ev.multipliers[kind]) or 1
end

if CLIENT then
    NRP.Net.Receive("Event", function()
        if net.ReadBool() then
            Events.Current = NRP.Net.ReadTable()
        else
            Events.Current = nil
        end
        hook.Run("NRP.EventUpdated", Events.Current)
    end)

    function Events.RequestJoin()
        RunConsoleCommand("nrp", "event", "join")
    end
end
