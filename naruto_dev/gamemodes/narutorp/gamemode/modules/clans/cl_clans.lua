--[[
    Module : clans (client)
    Requête de déblocage + passif "keen_senses" (repérage des ninjas proches).
]]

local Clans = NRP.Clans
local Passives = NRP.Passives

function Clans.RequestUnlock(nodeId)
    if not NRP.Net.CanSend("UnlockClanNode", 0.5) then return end
    NRP.Net.Start("UnlockClanNode")
        net.WriteString(nodeId)
    net.SendToServer()
end

-- Flair : marqueurs discrets sur les joueurs proches (hors ligne de vue incluse)
local sensed = {}

timer.Create("NRP.Clans.Senses", 0.5, 0, function()
    sensed = {}
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local params = Passives.Has(ply, "keen_senses")
    if not params then return end

    local radiusSqr = (params.radius or 800) ^ 2
    local origin = ply:GetPos()
    for _, other in NRP.Util.PlayerIterator() do
        if other ~= ply and other:Alive() and origin:DistToSqr(other:GetPos()) <= radiusSqr then
            sensed[#sensed + 1] = other
        end
    end
end)

hook.Add("HUDPaint", "NRP.Clans.Senses", function()
    if #sensed == 0 then return end
    for _, other in ipairs(sensed) do
        if IsValid(other) then
            local screen = (other:GetPos() + Vector(0, 0, 40)):ToScreen()
            if screen.visible then
                surface.SetDrawColor(200, 120, 90, 160)
                surface.DrawOutlinedRect(screen.x - 6, screen.y - 6, 12, 12, 2)
            end
        end
    end
end)
