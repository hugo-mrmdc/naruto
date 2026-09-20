--[[
    Module : événements RP (serveur)
        !event start "<nom>" <minutes> [multXP] [multRyo]
        !event desc <texte>      !event pos      !event stop
        !event reward <xp> <ryo> (participants)   !event join (joueurs)
]]

local Events = NRP.Events

NRP.Net.Pool("Event")

local function Send(target)
    local ev = Events.GetCurrent()
    NRP.Net.Start("Event")
        net.WriteBool(ev ~= nil)
        if ev then
            NRP.Net.WriteTable({
                name = ev.name,
                description = ev.description,
                endTime = ev.endTime,
                multipliers = ev.multipliers,
                pos = ev.pos,
                organizer = ev.organizer,
                participants = table.Count(ev.participants),
            })
        end
    if target then net.Send(target) else net.Broadcast() end
end

function Events.Start(actor, name, minutes, xpMult, ryoMult)
    if Events.GetCurrent() then return false, "Un événement est déjà en cours (!event stop)." end

    minutes = math.Clamp(tonumber(minutes) or 30, 1, 600)
    Events.Current = {
        name = string.sub(name, 1, 64),
        description = "",
        endTime = CurTime() + minutes * 60,
        multipliers = {
            xp = math.Clamp(tonumber(xpMult) or 1, 0, 5),
            ryo = math.Clamp(tonumber(ryoMult) or 1, 0, 5),
        },
        organizer = IsValid(actor) and actor:Nick() or "Administration",
        participants = {},
    }

    timer.Create("NRP.Events.End", minutes * 60, 1, function()
        Events.Stop(nil, "Fin de l'événement")
    end)

    Send()
    NRP.Announce("Événement : " .. Events.Current.name, "Organisé par " .. Events.Current.organizer .. " — tapez !event join", Color(255, 170, 40), 8)
    NRP.LogAction("event", actor, nil, "début " .. name .. " (" .. minutes .. " min)")
    return true
end

function Events.Stop(actor, reason)
    local ev = Events.Current
    if not ev then return false, "Aucun événement en cours." end
    Events.Current = nil
    timer.Remove("NRP.Events.End")
    Send()
    NRP.Announce("Événement terminé", ev.name .. (reason and (" — " .. reason) or ""), Color(200, 200, 200), 5)
    NRP.LogAction("event", actor, nil, "fin " .. ev.name)
    return true
end

hook.Add("NRP.CharacterLoaded", "NRP.Events.Send", function(ply)
    if Events.GetCurrent() then Send(ply) end
end)

hook.Add("PlayerDisconnected", "NRP.Events.Cleanup", function(ply)
    if Events.Current then Events.Current.participants[ply] = nil end
end)

NRP.Commands.Add("event", {
    needChar = false, usage = "event <start|stop|desc|pos|reward|join|info> ...", description = "Événements RP",
    args = { "string", "string?", "string?", "string?", "string?" },
    run = function(caller, action, a1, a2, a3, a4)
        action = string.lower(action)
        local ev = Events.GetCurrent()

        if action == "join" then
            if not ev then return false, "Aucun événement en cours." end
            if caller == NULL or not caller.NRPChar then return false end
            ev.participants[caller] = true
            Send()
            return true, "Vous participez à « " .. ev.name .. " »."
        elseif action == "info" then
            if not ev then return true, "Aucun événement en cours." end
            return true, ev.name .. " : " .. (ev.description ~= "" and ev.description or "pas de description")
                .. " (" .. NRP.Util.FormatTime(ev.endTime - CurTime()) .. " restantes)"
        end

        if not NRP.Perm.Has(caller, "rp.event") and not NRP.Perm.Has(caller, "admin.event") then
            return false, "Permission insuffisante."
        end

        if action == "start" then
            return Events.Start(caller, a1 or "Événement", a2, a3, a4)
        elseif action == "stop" then
            return Events.Stop(caller)
        elseif action == "desc" then
            if not ev then return false, "Aucun événement en cours." end
            ev.description = string.sub(table.concat({ a1 or "", a2 or "", a3 or "", a4 or "" }, " "), 1, 200)
            Send()
            return true
        elseif action == "pos" then
            if not ev or caller == NULL then return false, "Aucun événement en cours." end
            ev.pos = caller:GetPos()
            Send()
            return true, "Lieu de l'événement défini."
        elseif action == "reward" then
            if not ev then return false, "Aucun événement en cours." end
            local xp, ryo = math.max(0, tonumber(a1) or 0), math.max(0, tonumber(a2) or 0)
            local count = 0
            for ply in pairs(ev.participants) do
                if IsValid(ply) and ply.NRPChar then
                    if xp > 0 then NRP.Progression.AddXP(ply, xp, "event") end
                    if ryo > 0 then NRP.Char.AddRyo(ply, ryo, "event") end
                    count = count + 1
                end
            end
            NRP.LogAction("event", caller, nil, "récompense " .. xp .. " XP / " .. ryo .. " Ryo x" .. count)
            return true, count .. " participant(s) récompensé(s)."
        end
        return false, "Action inconnue."
    end,
})
