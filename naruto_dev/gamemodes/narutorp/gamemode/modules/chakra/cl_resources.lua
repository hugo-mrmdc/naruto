--[[
    Module : chakra & endurance (client)
    Réception des états + aura visuelle des joueurs en concentration.
]]

local Res = NRP.Resource
Res.Local = Res.Local or {}

NRP.Net.Receive("Resource", function()
    local kind = Res.Kinds[net.ReadUInt(2)]
    if not kind then return end

    Res.Local[kind] = {
        value = net.ReadFloat(),
        max = net.ReadFloat(),
        regen = net.ReadFloat(),
        drain = net.ReadFloat(),
        time = net.ReadDouble(),
        delayUntil = net.ReadDouble(),
    }
end)

local auraMat = Material("sprites/light_glow02_add")
local auraColor = Color(80, 160, 255, 120)

hook.Add("PostPlayerDraw", "NRP.Chakra.FocusAura", function(ply)
    if not ply:GetNW2Bool("NRP_Focus", false) or ply:IsDormant() then return end

    local pos = ply:GetPos()
    local t = CurTime() * 3
    render.SetMaterial(auraMat)
    for i = 0, 5 do
        local a = t + i * (math.pi / 3)
        local height = 10 + ((t * 20 + i * 12) % 60)
        render.DrawSprite(pos + Vector(math.cos(a) * 22, math.sin(a) * 22, height), 18, 18, auraColor)
    end
    render.DrawSprite(pos + Vector(0, 0, 36), 90, 110, Color(60, 140, 255, 40))
end)
