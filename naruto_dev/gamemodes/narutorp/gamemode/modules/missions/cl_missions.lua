--[[
    Module : missions (client)
    NRP.Missions.Current : état de la mission du joueur (nil si aucune)
    Hooks : "NRP.MissionBoard"(npc, list), "NRP.MissionUpdated"(state), "NRP.MissionInvite"(from, missionId)
]]

local Missions = NRP.Missions

NRP.Net.Receive("MissionBoard", function()
    local npc = net.ReadEntity()
    local list = NRP.Net.ReadTable() or {}
    hook.Run("NRP.MissionBoard", npc, list)
end)

NRP.Net.Receive("MissionState", function()
    if not net.ReadBool() then
        Missions.Current = nil
        hook.Run("NRP.MissionUpdated", nil)
        return
    end

    local state = NRP.Net.ReadTable()
    if not state then return end
    state.isLeader = net.ReadBool()
    state.def = Missions.Registry:Get(state.id)
    Missions.Current = state
    hook.Run("NRP.MissionUpdated", state)
end)

NRP.Net.Receive("MissionInvitePrompt", function()
    local from = net.ReadEntity()
    local missionId = net.ReadString()
    if IsValid(from) then
        hook.Run("NRP.MissionInvite", from, missionId)
    end
end)

function Missions.RequestAccept(npc, id)
    if not NRP.Net.CanSend("MissionAccept", 1) then return end
    NRP.Net.Start("MissionAccept")
        net.WriteEntity(npc)
        net.WriteString(id)
    net.SendToServer()
end

function Missions.RequestAbandon()
    if not NRP.Net.CanSend("MissionAbandon", 1) then return end
    NRP.Net.Start("MissionAbandon")
    net.SendToServer()
end

function Missions.RequestBegin()
    if not NRP.Net.CanSend("MissionBegin", 1) then return end
    NRP.Net.Start("MissionBegin")
    net.SendToServer()
end

function Missions.RequestInvite(target)
    if not NRP.Net.CanSend("MissionInvite", 1) then return end
    NRP.Net.Start("MissionInvite")
        net.WriteEntity(target)
    net.SendToServer()
end

function Missions.ReplyInvite(accept)
    NRP.Net.Start("MissionInviteReply")
        net.WriteBool(accept)
    net.SendToServer()
end
