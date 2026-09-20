--[[
    Module : combat - effets visuels (client)

    Registre d'effets utilisé par les projectiles, les jutsu et les actions :
        NRP.FX.Register("mon_effet", {
            projectile = function(p, pos, dir) end,           -- dessin d'un projectile (chaque frame)
            impact = function(pos, color, scale) end,          -- fin d'un projectile
            burst = function(pos, pos2, color, scale, ent) end -- effet ponctuel (NRP.Combat.PlayFX)
        })
    Tous les effets sont purement visuels : aucune logique de jeu côté client.
]]

NRP.FX = NRP.FX or {}
local FX = NRP.FX
FX.Defs = FX.Defs or {}

local MAT_GLOW = Material("sprites/light_glow02_add")
local MAT_FIRE = Material("effects/fire_cloud1")
local MAT_SMOKE = Material("particle/particle_smokegrenade")
local MAT_BEAM = Material("sprites/physbeama")
local MAT_SPARK = Material("effects/spark")

local PART_SMOKE = "particle/particle_smokegrenade"
local PART_FIRE = "effects/fire_cloud1"
local PART_GLOW = "sprites/light_glow02_add"

function FX.Register(id, def)
    FX.Defs[id] = def
end

function FX.Get(id)
    return FX.Defs[id] or FX.Defs.generic
end

---------------------------------------------------------------------------
-- Effets temporaires dessinés dans le monde (anneaux, rayons...)
---------------------------------------------------------------------------

local temps = {}
local TEMP_HOOK = "NRP.FX.Temps"

local function DrawTemps(depth, skybox)
    if depth or skybox then return end
    local now = CurTime()
    for i = #temps, 1, -1 do
        local t = temps[i]
        if now >= t.die then
            table.remove(temps, i)
        else
            t.draw(t, 1 - (t.die - now) / t.duration)
        end
    end
    if #temps == 0 then
        hook.Remove("PostDrawTranslucentRenderables", TEMP_HOOK)
    end
end

function FX.AddTemp(duration, drawFn, data)
    data = data or {}
    data.duration = duration
    data.die = CurTime() + duration
    data.draw = drawFn
    if #temps == 0 then
        hook.Add("PostDrawTranslucentRenderables", TEMP_HOOK, DrawTemps)
    end
    temps[#temps + 1] = data
    if #temps > 64 then table.remove(temps, 1) end
end

---------------------------------------------------------------------------
-- Aides
---------------------------------------------------------------------------

function FX.Particles(pos, material, count, opts)
    local emitter = ParticleEmitter(pos)
    if not emitter then return end
    local c = opts.color or color_white

    for _ = 1, count do
        local p = emitter:Add(material, pos + VectorRand() * (opts.spread or 4))
        if p then
            p:SetVelocity(VectorRand() * (opts.speed or 80) + (opts.velocity or vector_origin))
            p:SetDieTime(opts.life or 0.8)
            p:SetStartAlpha(opts.alpha or 220)
            p:SetEndAlpha(0)
            p:SetStartSize(opts.size or 12)
            p:SetEndSize(opts.endSize or (opts.size or 12) * 2)
            p:SetRoll(math.Rand(0, 360))
            p:SetRollDelta(math.Rand(-2, 2))
            p:SetColor(c.r, c.g, c.b)
            p:SetGravity(opts.gravity or vector_origin)
            p:SetAirResistance(opts.air or 60)
            p:SetCollide(opts.collide or false)
        end
    end
    emitter:Finish()
end

function FX.Effect(name, pos, scale, normal)
    local e = EffectData()
    e:SetOrigin(pos)
    e:SetNormal(normal or Vector(0, 0, 1))
    e:SetScale(scale or 1)
    e:SetMagnitude(scale or 1)
    e:SetRadius(scale or 1)
    util.Effect(name, e, true, true)
end

function FX.Light(pos, color, size, duration)
    local light = DynamicLight(math.random(10000, 60000))
    if light then
        light.pos = pos
        light.r, light.g, light.b = color.r, color.g, color.b
        light.brightness = 2
        light.Decay = 1000
        light.Size = size or 200
        light.DieTime = CurTime() + (duration or 0.2)
    end
end

function FX.Ring(pos, color, radius, duration)
    FX.AddTemp(duration or 0.5, function(_, frac)
        local r = radius * frac
        local a = 200 * (1 - frac)
        render.SetMaterial(MAT_GLOW)
        for i = 0, 15 do
            local ang = i / 16 * math.pi * 2
            render.DrawSprite(pos + Vector(math.cos(ang) * r, math.sin(ang) * r, 4), 30, 30,
                Color(color.r, color.g, color.b, a))
        end
    end)
end

function FX.Beam(from, to, color, width, duration, jagged)
    FX.AddTemp(duration or 0.3, function(_, frac)
        local a = 255 * (1 - frac)
        local col = Color(color.r, color.g, color.b, a)
        render.SetMaterial(MAT_BEAM)
        if jagged then
            local segments = 8
            render.StartBeam(segments + 1)
            for i = 0, segments do
                local p = LerpVector(i / segments, from, to)
                if i > 0 and i < segments then
                    p = p + VectorRand() * 10
                end
                render.AddBeam(p, width, i / segments, col)
            end
            render.EndBeam()
        else
            render.DrawBeam(from, to, width, 0, 1, col)
        end
    end)
end

local function Glow(pos, size, color, alpha)
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(pos, size, size, Color(color.r, color.g, color.b, alpha or 255))
end

---------------------------------------------------------------------------
-- Effets de base
---------------------------------------------------------------------------

FX.Register("generic", {
    projectile = function(p, pos)
        Glow(pos, p.radius * 3, p.color)
    end,
    impact = function(pos, color)
        FX.Particles(pos, PART_GLOW, 10, { color = color, speed = 120, life = 0.4, size = 8, endSize = 0 })
    end,
    burst = function(pos, _, color, scale)
        FX.Particles(pos, PART_GLOW, 12, { color = color, speed = 100 * scale, life = 0.5, size = 10 })
    end,
})

local function FireProjectile(p, pos, dir)
    local size = p.radius * 2.6
    render.SetMaterial(MAT_FIRE)
    for i = 0, 4 do
        local back = pos - dir * (i * p.radius * 0.7)
        local s = size * (1 - i * 0.15)
        render.DrawSprite(back + VectorRand() * 2, s, s, Color(255, 180 - i * 25, 80, 230 - i * 40))
    end
    Glow(pos, size * 1.8, p.color, 200)
    if (p.nextLight or 0) < CurTime() then
        p.nextLight = CurTime() + 0.1
        FX.Light(pos, p.color, p.radius * 10, 0.15)
    end
end

FX.Register("fireball", {
    projectile = FireProjectile,
    impact = function(pos, color)
        FX.Particles(pos, PART_FIRE, 24, { color = Color(255, 170, 80), speed = 220, life = 0.9, size = 30, endSize = 60, gravity = Vector(0, 0, 120) })
        FX.Particles(pos, PART_SMOKE, 10, { color = Color(60, 60, 60), speed = 80, life = 2, size = 30, endSize = 90, alpha = 120, gravity = Vector(0, 0, 60) })
        FX.Light(pos, color, 400, 0.4)
        FX.Ring(pos, color, 180, 0.4)
    end,
})

FX.Register("fireball_small", {
    projectile = FireProjectile,
    impact = function(pos, color)
        FX.Particles(pos, PART_FIRE, 8, { color = Color(255, 170, 80), speed = 120, life = 0.5, size = 14, endSize = 30 })
        FX.Light(pos, color, 150, 0.2)
    end,
})

FX.Register("black_flame", {
    burst = function(pos, _, _, scale)
        FX.Particles(pos, PART_FIRE, 30, { color = Color(20, 0, 30), speed = 60, life = 3 * scale, size = 30, endSize = 50, gravity = Vector(0, 0, 80), alpha = 255 })
        FX.Particles(pos, PART_SMOKE, 10, { color = Color(10, 0, 10), speed = 40, life = 3, size = 40, endSize = 80, alpha = 180 })
    end,
})

local function WaterProjectile(p, pos, dir)
    render.SetMaterial(MAT_GLOW)
    for i = 0, 5 do
        local back = pos - dir * (i * p.radius * 0.8)
        local s = p.radius * (2.4 - i * 0.3)
        render.DrawSprite(back + VectorRand() * 1.5, s, s, Color(p.color.r, p.color.g, p.color.b, 220 - i * 30))
    end
end

FX.Register("water", {
    projectile = WaterProjectile,
    impact = function(pos, color)
        FX.Effect("watersplash", pos, 12)
        FX.Particles(pos, PART_GLOW, 16, { color = color, speed = 180, life = 0.6, size = 8, endSize = 2, gravity = Vector(0, 0, -400) })
    end,
})

FX.Register("water_dragon", {
    projectile = function(p, pos, dir)
        p.trail = p.trail or {}
        local trail = p.trail
        if (p.nextTrail or 0) < CurTime() then
            p.nextTrail = CurTime() + 0.03
            table.insert(trail, 1, pos)
            if #trail > 14 then trail[#trail] = nil end
        end

        render.SetMaterial(MAT_GLOW)
        local t = CurTime() * 8
        for i, tp in ipairs(trail) do
            local wave = Vector(0, 0, math.sin(t - i * 0.6) * 12)
            local s = p.radius * (3 - i * 0.15)
            render.DrawSprite(tp + wave, s, s, Color(p.color.r, p.color.g, p.color.b, 230 - i * 12))
        end
        render.DrawSprite(pos, p.radius * 4, p.radius * 4, Color(200, 230, 255, 200))
    end,
    impact = function(pos, color)
        FX.Effect("watersplash", pos, 40)
        FX.Particles(pos, PART_GLOW, 40, { color = color, speed = 350, life = 1, size = 14, endSize = 4, gravity = Vector(0, 0, -500) })
        FX.Ring(pos, color, 220, 0.6)
    end,
})

FX.Register("wind", {
    projectile = function(p, pos, dir)
        local right = dir:Cross(Vector(0, 0, 1))
        render.SetMaterial(MAT_GLOW)
        for i = -3, 3 do
            local off = right * i * p.radius * 0.6 - dir * math.abs(i) * 6
            render.DrawSprite(pos + off, p.radius * 1.4, p.radius * 0.6, Color(p.color.r, p.color.g, p.color.b, 160))
        end
    end,
    impact = function(pos, color)
        FX.Particles(pos, PART_SMOKE, 8, { color = Color(200, 220, 200), speed = 200, life = 0.5, size = 10, endSize = 40, alpha = 80 })
    end,
    burst = function(pos, pos2, color, scale)
        local dir = (pos2 - pos):GetNormalized()
        FX.Particles(pos, PART_SMOKE, 20, { color = Color(210, 230, 210), velocity = dir * 700 * scale, speed = 120, life = 0.8, size = 16, endSize = 60, alpha = 90 })
    end,
})

FX.Register("lightning", {
    projectile = function(p, pos)
        Glow(pos, p.radius * 3, p.color)
    end,
    impact = function(pos)
        FX.Effect("StunstickImpact", pos, 1)
    end,
    burst = function(pos, pos2, color)
        FX.Beam(pos, pos2, color, 18, 0.35, true)
        FX.Beam(pos, pos2, Color(255, 255, 255), 6, 0.25, true)
        FX.Effect("StunstickImpact", pos2, 1)
        FX.Light(pos2, color, 300, 0.3)
    end,
})

FX.Register("earth", {
    burst = function(pos, _, color, scale)
        FX.Effect("ThumperDust", pos, 60 * scale)
        FX.Particles(pos, PART_SMOKE, 16, { color = Color(120, 100, 80), speed = 160, life = 1.2, size = 20, endSize = 70, alpha = 160, gravity = Vector(0, 0, -100) })
    end,
})

FX.Register("smoke", {
    burst = function(pos, _, _, scale)
        FX.Particles(pos, PART_SMOKE, 18, { color = Color(230, 230, 230), speed = 90 * scale, life = 1.2, size = 20, endSize = 70, alpha = 200 })
    end,
})

FX.Register("dust", {
    burst = function(pos, _, _, scale)
        FX.Particles(pos + Vector(0, 0, 4), PART_SMOKE, 6, { color = Color(170, 160, 140), speed = 60 * scale, life = 0.6, size = 10, endSize = 35, alpha = 120 })
    end,
})

FX.Register("heal", {
    burst = function(pos, _, color)
        FX.Particles(pos, PART_GLOW, 20, { color = color, speed = 30, life = 1.2, size = 10, endSize = 0, velocity = Vector(0, 0, 60), spread = 20 })
    end,
})

FX.Register("insects", {
    projectile = function(p, pos)
        render.SetMaterial(MAT_GLOW)
        for _ = 1, 14 do
            render.DrawSprite(pos + VectorRand() * p.radius, 4, 4, Color(10, 10, 10, 255))
        end
    end,
    impact = function(pos)
        FX.Particles(pos, PART_GLOW, 30, { color = Color(15, 15, 15), speed = 120, life = 1.5, size = 3, endSize = 3, alpha = 255 })
    end,
})

FX.Register("shadow", {
    burst = function(pos, pos2, _, scale)
        FX.AddTemp(scale, function()
            render.SetMaterial(MAT_BEAM)
            render.DrawBeam(pos + Vector(0, 0, 2), pos2 + Vector(0, 0, 2), 16, 0, 1, Color(0, 0, 0, 230))
        end)
    end,
})

FX.Register("genjutsu", {
    burst = function(pos, _, color)
        FX.Particles(pos, PART_GLOW, 24, { color = color, speed = 60, life = 1.5, size = 12, endSize = 0, spread = 24 })
    end,
})

FX.Register("kunai", {
    projectile = function(p, pos, dir)
        render.SetMaterial(MAT_SPARK)
        render.DrawBeam(pos - dir * 14, pos, 3, 0, 1, Color(200, 200, 210, 255))
    end,
    impact = function(pos)
        FX.Effect("MetalSpark", pos, 1)
    end,
})

FX.Register("shuriken", {
    projectile = function(p, pos)
        Glow(pos, 8, Color(210, 210, 220), 255)
    end,
    impact = function(pos)
        FX.Effect("MetalSpark", pos, 1)
    end,
})

FX.Register("impact", {
    burst = function(pos, _, color)
        FX.Ring(pos, color, 90, 0.3)
        FX.Effect("cball_bounce", pos, 1)
    end,
})

FX.Register("aura", {
    burst = function(pos, _, color, scale, ent)
        if not IsValid(ent) then return end
        FX.AddTemp(scale, function()
            if not IsValid(ent) then return end
            local base = ent:GetPos()
            local t = CurTime() * 4
            render.SetMaterial(MAT_GLOW)
            for i = 0, 7 do
                local a = t + i * math.pi / 4
                render.DrawSprite(base + Vector(math.cos(a) * 20, math.sin(a) * 20, 10 + (t * 15 + i * 8) % 60), 14, 14,
                    Color(color.r, color.g, color.b, 150))
            end
        end)
    end,
})

FX.Register("chakra_dome", {
    burst = function(pos, _, color, scale)
        FX.Ring(pos, color, 220 * scale, 0.6)
        FX.Effect("VortDispel", pos, 1)
        FX.Particles(pos, PART_GLOW, 30, { color = color, speed = 300, life = 0.6, size = 16, endSize = 0 })
    end,
})

---------------------------------------------------------------------------
-- Réception
---------------------------------------------------------------------------

function FX.Play(id, pos, pos2, color, scale, ent)
    local def = FX.Get(id)
    if def.burst then
        def.burst(pos, pos2, color, scale, ent)
    elseif def.impact then
        def.impact(pos, color, scale)
    end
end

NRP.Net.Receive("FX", function()
    local id = net.ReadString()
    local pos = net.ReadVector()
    local pos2 = net.ReadVector()
    local color = net.ReadColor(false)
    local scale = net.ReadFloat()
    local ent = net.ReadEntity()
    FX.Play(id, pos, pos2, color, scale, ent)
end)

local HIT_EFFECTS = {
    [0] = function(pos) FX.Effect("cball_bounce", pos, 0.5) end,
    [1] = function(pos) FX.Effect("MetalSpark", pos, 1) end,
    [2] = function(pos)
        FX.Effect("cball_explode", pos, 1)
        FX.Ring(pos, Color(120, 200, 255), 60, 0.25)
    end,
    [3] = function(pos)
        FX.Effect("ManhackSparks", pos, 2)
        FX.Ring(pos, Color(255, 120, 60), 80, 0.35)
    end,
    [4] = function(pos)
        FX.Particles(pos, PART_SMOKE, 4, { color = Color(230, 230, 230), speed = 40, life = 0.4, size = 10, endSize = 30, alpha = 120 })
    end,
}

NRP.Net.Receive("HitFX", function()
    local pos = net.ReadVector()
    local kind = net.ReadUInt(3)
    local fn = HIT_EFFECTS[kind]
    if fn then fn(pos) end
end)
