--[[
    Archetypes offensifs : projectile, aoe, cone, strike, dash_strike
    Tous les paramètres viennent de la définition du jutsu (config/jutsu.lua).
]]

local Jutsu = NRP.Jutsu
local Combat = NRP.Combat

local function PlayImpactSound(jutsu, pos)
    local snd = jutsu.sounds and jutsu.sounds.impact
    if snd then
        sound.Play(snd, pos, 80, math.random(95, 105))
    end
end

---------------------------------------------------------------------------
-- projectile : count, spread, speed, range, radius, gravity, pierce, explosion
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("projectile", {
    Execute = function(ply, jutsu, ctx)
        local count = math.max(1, jutsu.count or 1)
        local spread = jutsu.spread or 0
        local speed = jutsu.speed or 1200
        local eyeAng = ply:EyeAngles()
        local start = ply:EyePos() + ctx.aim * 24 - Vector(0, 0, 6)

        for i = 1, count do
            local ang = Angle(eyeAng.p, eyeAng.y, 0)
            if count > 1 then
                ang:RotateAroundAxis(ang:Up(), (i - (count + 1) / 2) * spread)
            end

            NRP.Projectile.Launch({
                owner = ply,
                pos = start,
                dir = ang:Forward(),
                speed = speed,
                gravity = jutsu.gravity or 0,
                radius = jutsu.radius or 16,
                lifetime = (jutsu.range or 1500) / speed,
                fx = jutsu.fx or "generic",
                color = jutsu.color,
                particle = jutsu.particles and jutsu.particles.travel,
                pierce = jutsu.pierce,
                explosion = jutsu.explosion,
                impactSound = jutsu.sounds and jutsu.sounds.impact,
                damage = Jutsu.BuildDamage(ply, jutsu, ctx),
            })
        end
        return true
    end,
})

---------------------------------------------------------------------------
-- aoe : zone au point visé (ou autour de soi si self = true)
--       radius, range, delay, falloff, iframes
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("aoe", {
    Execute = function(ply, jutsu, ctx)
        local center
        if jutsu.self then
            center = ply:GetPos() + Vector(0, 0, 30)
        else
            local tr = util.TraceLine({
                start = ctx.eye,
                endpos = ctx.eye + ctx.aim * (jutsu.range or 800),
                filter = ply,
                mask = MASK_SOLID,
            })
            center = tr.HitPos + tr.HitNormal * 10
        end

        local info = Jutsu.BuildDamage(ply, jutsu, ctx)
        local radius = jutsu.radius or 150

        if jutsu.iframes then
            NRP.Status.Apply(ply, "invuln", jutsu.iframes)
        end

        local function Detonate()
            if not IsValid(ply) then return end
            if jutsu.self then
                center = ply:GetPos() + Vector(0, 0, 30)
            end
            Combat.RadiusDamage(center, radius, info, jutsu.falloff or 0.3)
            Combat.PlayFX(jutsu.fx or "generic", center, { color = jutsu.color, scale = radius / 150 })
            PlayImpactSound(jutsu, center)
        end

        if (jutsu.delay or 0) > 0 then
            Combat.PlayFX("dust", center, { scale = radius / 100 })
            timer.Simple(jutsu.delay, Detonate)
        else
            Detonate()
        end
        return true
    end,
})

---------------------------------------------------------------------------
-- cone : souffle devant soi (range, angle)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("cone", {
    Execute = function(ply, jutsu, ctx)
        local info = Jutsu.BuildDamage(ply, jutsu, ctx)
        local flat = Vector(ctx.aim.x, ctx.aim.y, 0):GetNormalized()

        for _, ent in ipairs(Combat.FindInCone(ply, jutsu.range or 500, jutsu.angle or 30)) do
            local copy = table.Copy(info)
            copy.dir = flat
            copy.sourcePos = ply:GetPos()
            Combat.Damage(ent, copy)
        end

        Combat.PlayFX(jutsu.fx or "wind", ctx.eye + ctx.aim * 30, {
            pos2 = ctx.eye + ctx.aim * (jutsu.range or 500),
            color = jutsu.color,
        })
        return true
    end,
})

---------------------------------------------------------------------------
-- strike : frappe de taijutsu renforcée au contact (range, angle)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("strike", {
    Execute = function(ply, jutsu, ctx)
        local info = Jutsu.BuildDamage(ply, jutsu, ctx)
        info.kind = "melee"
        info.heavy = true
        local flat = Vector(ctx.aim.x, ctx.aim.y, 0):GetNormalized()

        NRP.Util.LagCompensate(ply, true)
        local targets = Combat.FindInCone(ply, jutsu.range or 100, jutsu.angle or 60)
        NRP.Util.LagCompensate(ply, false)

        for _, ent in ipairs(targets) do
            local copy = table.Copy(info)
            copy.dir = flat
            copy.sourcePos = ply:GetPos()
            Combat.Damage(ent, copy)
            Combat.PlayFX(jutsu.fx or "impact", ent:WorldSpaceCenter(), { color = jutsu.color })
        end

        ply:SetVelocity(flat * 180)
        if #targets > 0 then
            PlayImpactSound(jutsu, ply:GetPos())
        end
        return true
    end,
})

---------------------------------------------------------------------------
-- dash_strike : ruée qui traverse et frappe tout sur la trajectoire (range, radius)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("dash_strike", {
    Execute = function(ply, jutsu, ctx)
        local dir = Vector(ctx.aim.x, ctx.aim.y, math.Clamp(ctx.aim.z, -0.3, 0.3))
        dir:Normalize()

        local start = ply:GetPos() + Vector(0, 0, 4)
        local mins, maxs = ply:GetHull()
        local tr = util.TraceHull({
            start = start,
            endpos = start + dir * (jutsu.range or 500),
            mins = mins, maxs = maxs,
            mask = MASK_PLAYERSOLID,
            filter = function(ent)
                return ent ~= ply and not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
            end,
        })

        local dest = tr.HitPos
        local r = jutsu.radius or 32
        local info = Jutsu.BuildDamage(ply, jutsu, ctx)
        local hit = {}

        for _, ent in ipairs(ents.FindAlongRay(start, dest, Vector(-r, -r, 0), Vector(r, r, 72))) do
            if ent ~= ply and not hit[ent] and Combat.IsDamageable(ent) then
                hit[ent] = true
                local copy = table.Copy(info)
                copy.dir = dir
                copy.sourcePos = start
                Combat.Damage(ent, copy)
            end
        end

        if NRP.Util.IsHullFree(dest, ply) then
            ply:SetPos(dest)
        end
        ply:SetVelocity(-ply:GetVelocity() + dir * 150)
        NRP.Status.Apply(ply, "invuln", 0.15)

        Combat.PlayFX(jutsu.fx or "lightning", start + Vector(0, 0, 40), {
            pos2 = dest + Vector(0, 0, 40),
            color = jutsu.color,
        })
        if next(hit) then
            PlayImpactSound(jutsu, dest)
        end
        return true
    end,
})
