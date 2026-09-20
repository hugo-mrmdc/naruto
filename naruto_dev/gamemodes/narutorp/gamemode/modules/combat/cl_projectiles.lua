--[[
    Module : combat - rendu des projectiles (client)
    Trajectoire recalculée localement à partir du message de lancement ; le message de fin
    donne la position exacte d'impact. Le hook de rendu n'existe que si un projectile est actif.
]]

local FX = NRP.FX
local active = {}
local HOOK_ID = "NRP.ProjectilesDraw"

local function Remove(id)
    local p = active[id]
    if not p then return end
    if p.system and p.system:IsValid() then
        p.system:StopEmission(false, true)
    end
    active[id] = nil
end

local function Draw(depth, skybox)
    if depth or skybox then return end
    local now = CurTime()

    for id, p in pairs(active) do
        local t = now - p.start
        if t > p.lifetime + 0.25 then
            Remove(id)
        else
            local pos = p.origin + p.vel * t
            pos.z = pos.z - 0.5 * p.gravity * t * t
            local dir = Vector(p.vel.x, p.vel.y, p.vel.z - p.gravity * t)
            dir:Normalize()

            p.pos = pos
            if p.system and p.system:IsValid() then
                p.system:SetControlPoint(0, pos)
            end

            local def = FX.Get(p.fx)
            if def.projectile then
                def.projectile(p, pos, dir)
            end
        end
    end

    if next(active) == nil then
        hook.Remove("PostDrawTranslucentRenderables", HOOK_ID)
    end
end

NRP.Net.Receive("ProjStart", function()
    local id = net.ReadUInt(16)
    local p = {
        fx = net.ReadString(),
        origin = net.ReadVector(),
        vel = net.ReadVector(),
        gravity = net.ReadFloat(),
        lifetime = net.ReadFloat(),
        radius = net.ReadFloat(),
        color = net.ReadColor(false),
        start = CurTime(),
    }
    local particle = net.ReadString()

    if particle ~= "" and CreateParticleSystemNoEntity then
        p.system = CreateParticleSystemNoEntity(particle, p.origin)
    end

    Remove(id)
    if next(active) == nil then
        hook.Add("PostDrawTranslucentRenderables", HOOK_ID, Draw)
    end
    active[id] = p
end)

NRP.Net.Receive("ProjEnd", function()
    local id = net.ReadUInt(16)
    local pos = net.ReadVector()
    local impact = net.ReadBool()

    local p = active[id]
    if not p then return end
    Remove(id)

    if impact then
        local def = FX.Get(p.fx)
        if def.impact then
            def.impact(pos, p.color, 1)
        end
    end
end)
