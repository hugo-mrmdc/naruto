--[[
    Module : combat - projectiles simulés (serveur)

    Aucune entité n'est créée : les projectiles sont de simples tables déplacées par un
    hook Tick qui n'existe QUE tant qu'au moins un projectile est actif.
    Réseau : 1 message au lancement + 1 message à la fin. Le client simule la trajectoire.

        NRP.Projectile.Launch({
            owner = ply, pos = Vector, dir = Vector, speed = 1500,
            gravity = 0, radius = 20, lifetime = 1.5,
            fx = "fireball", color = Color(...),
            damage = { amount = 30, kind = "jutsu", ... },   -- voir NRP.Combat.Damage
            explosion = { radius = 150, falloff = 0.5 },
            pierce = false, impactSound = "…",
            onImpact = function(proj, pos, hitEnt) end,
        })
]]

NRP.Projectile = NRP.Projectile or {}
local Proj = NRP.Projectile
local Combat = NRP.Combat

NRP.Net.Pool("ProjStart")
NRP.Net.Pool("ProjEnd")

local active = {}
local nextId = 0
local HOOK_ID = "NRP.Projectiles"

local function Finish(p, pos, impact, hitEnt)
    active[p.id] = nil

    local recipients = {}
    for _, ply in ipairs(p.recipients) do
        if IsValid(ply) then recipients[#recipients + 1] = ply end
    end
    if #recipients > 0 then
        NRP.Net.Start("ProjEnd")
            net.WriteUInt(p.id, 16)
            net.WriteVector(pos)
            net.WriteBool(impact)
        net.Send(recipients)
    end

    if impact then
        if p.explosion and p.damage then
            Combat.RadiusDamage(pos, p.explosion.radius, p.damage, p.explosion.falloff, p.pierce and nil or hitEnt)
        end
        if p.impactSound then
            sound.Play(p.impactSound, pos, 80, 100)
        end
    end

    if p.onImpact then
        p.onImpact(p, pos, hitEnt, impact)
    end
end

local function DirectHit(p, ent, pos)
    if not p.damage then return end
    local info = {}
    for k, v in pairs(p.damage) do info[k] = v end
    info.dir = p.vel:GetNormalized()
    info.pos = pos
    info.sourcePos = pos - info.dir * 40
    Combat.Damage(ent, info)
end

local function Step()
    local now = CurTime()
    local dt = engine.TickInterval()

    for id, p in pairs(active) do
        if not IsValid(p.owner) then
            Finish(p, p.pos, false)
        else
            if p.gravity ~= 0 then
                p.vel.z = p.vel.z - p.gravity * dt
            end

            local from = p.pos
            local to = from + p.vel * dt
            local tr = util.TraceHull({
                start = from,
                endpos = to,
                mins = p.mins,
                maxs = p.maxs,
                mask = MASK_SHOT_HULL,
                filter = p.filter,
            })

            if tr.Hit then
                local ent = tr.Entity
                if IsValid(ent) and Combat.IsDamageable(ent) then
                    DirectHit(p, ent, tr.HitPos)
                    if p.pierce and not ent.NRPBlocksProjectiles then
                        p.ignore[ent] = true
                        p.pos = tr.HitPos
                    else
                        Finish(p, tr.HitPos, true, ent)
                    end
                else
                    Finish(p, tr.HitPos, true, IsValid(ent) and ent or nil)
                end
            elseif now >= p.dieAt then
                Finish(p, to, false)
            else
                p.pos = to
            end
        end
    end

    if next(active) == nil then
        hook.Remove("Tick", HOOK_ID)
    end
end

function Proj.Launch(opts)
    nextId = (nextId % 65535) + 1
    local id = nextId
    local r = opts.radius or 10
    local lifetime = opts.lifetime or 2
    local dir = opts.dir:GetNormalized()

    local p = {
        id = id,
        owner = opts.owner,
        pos = opts.pos,
        vel = dir * (opts.speed or 1000),
        gravity = opts.gravity or 0,
        mins = Vector(-r, -r, -r),
        maxs = Vector(r, r, r),
        dieAt = CurTime() + lifetime,
        damage = opts.damage,
        explosion = opts.explosion,
        pierce = opts.pierce,
        impactSound = opts.impactSound,
        onImpact = opts.onImpact,
        ignore = {},
    }

    local owner = opts.owner
    p.filter = function(ent)
        if ent == owner or p.ignore[ent] then return false end
        if ent.NRPProjectileOwnerPass and ent:GetOwner() == owner then return false end
        return true
    end

    local rf = RecipientFilter()
    local travel = (opts.speed or 1000) * lifetime
    rf:AddPVS(opts.pos)
    rf:AddPVS(opts.pos + dir * travel * 0.5)
    rf:AddPVS(opts.pos + dir * travel)
    p.recipients = rf:GetPlayers()

    if #p.recipients > 0 then
        NRP.Net.Start("ProjStart")
            net.WriteUInt(id, 16)
            net.WriteString(opts.fx or "generic")
            net.WriteVector(opts.pos)
            net.WriteVector(p.vel)
            net.WriteFloat(p.gravity)
            net.WriteFloat(lifetime)
            net.WriteFloat(r)
            net.WriteColor(opts.color or color_white, false)
            net.WriteString(opts.particle or "")
        net.Send(p.recipients)
    end

    local wasEmpty = next(active) == nil
    active[id] = p
    if wasEmpty then
        hook.Add("Tick", HOOK_ID, Step)
    end

    return p
end

function Proj.Count()
    return table.Count(active)
end
