--[[
    Module : progression (client)
]]

local Stats = NRP.Stats
local Prog = NRP.Progression

NRP.Net.Receive("Derived", function()
    local payload = NRP.Net.ReadTable()
    if not payload then return end
    Stats.LocalStats = payload.stats or {}
    Stats.LocalDerived = payload.derived or {}
    hook.Run("NRP.StatsSynced", Stats.LocalStats, Stats.LocalDerived)
end)

NRP.Net.Receive("LevelUp", function()
    local ply = net.ReadEntity()
    local level = net.ReadUInt(8)
    if not IsValid(ply) then return end

    local effect = EffectData()
    effect:SetOrigin(ply:GetPos() + Vector(0, 0, 40))
    effect:SetMagnitude(2)
    effect:SetScale(1)
    effect:SetRadius(40)
    util.Effect("cball_explode", effect, true, true)

    if ply == LocalPlayer() then
        hook.Run("NRP.Announce", "Niveau " .. level .. " !", "Nouveaux points de statistiques disponibles", Color(250, 200, 60), 4)
    end
end)

function Prog.RequestAllocate(statId, amount)
    if not NRP.Net.CanSend("AllocateStat", 0.15) then return end
    NRP.Net.Start("AllocateStat")
        net.WriteString(statId)
        net.WriteUInt(math.Clamp(amount or 1, 1, 100), 7)
    net.SendToServer()
end
