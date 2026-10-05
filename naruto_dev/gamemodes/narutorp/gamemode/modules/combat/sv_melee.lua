--[[
    Module : combat - corps à corps (serveur)
    Appelé par l'arme nrp_hands. Le serveur applique ses propres cooldowns, indépendamment
    du rythme de tir de l'arme (un client modifié ne peut pas frapper plus vite).
]]

local Combat = NRP.Combat
local Status = NRP.Status
local Stats = NRP.Stats
local CD = NRP.Cooldown
local Cfg = Combat.Cfg

function Combat.CanAttack(ply)
    if not ply.NRPChar or not ply:Alive() then return false end
    if not Status.CanAct(ply) or Combat.IsBlocking(ply) then return false end
    if NRP.Jutsu and NRP.Jutsu.IsCasting(ply) then return false end
    if CD.IsActive(ply, "melee") then return false end
    return true
end

function Combat.MeleeHit(ply, info)
    local cfg = Cfg().Melee
    local hull = Vector(cfg.HullSize, cfg.HullSize, cfg.HullSize)
    local start = ply:GetShootPos()
    local dir = ply:GetAimVector()

    NRP.Util.LagCompensate(ply, true)
    local tr = util.TraceHull({
        start = start,
        endpos = start + dir * cfg.Range,
        filter = ply,
        mins = -hull, maxs = hull,
        mask = MASK_SHOT_HULL,
    })
    NRP.Util.LagCompensate(ply, false)

    local ent = tr.Entity
    if IsValid(ent) and Combat.IsDamageable(ent) then
        info.attacker = ply
        info.inflictor = ply:GetActiveWeapon()
        info.dir = dir
        info.pos = tr.HitPos
        info.sourcePos = ply:GetPos()
        if not ent:IsPlayer() then
            info.amount = info.amount * cfg.NPCDamageMultiplier
        end

        Combat.Damage(ent, info)
        ply:EmitSound("dimix/sond/taijutsu/hit1.wav", 70, math.random(95, 110))
        return true, ent
    end

    if IsValid(ent) then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) and phys:IsMoveable() then
            phys:ApplyForceOffset(dir * 60 * phys:GetMass(), tr.HitPos)
        end
    end

    if tr.Hit then
        ply:EmitSound("physics/flesh/flesh_impact_hard" .. math.random(1, 3) .. ".wav", 60, 90)
    else
        ply:EmitSound("npc/zombie/claw_miss" .. math.random(1, 2) .. ".wav", 60, 110)
    end
    return false
end

function Combat.LightAttack(ply)
    local cfg = Cfg().Melee
    if not Combat.CanAttack(ply) then return false end

    if not NRP.Stamina.Take(ply, cfg.LightStamina, true) then
        return false
    end

    if CurTime() - (ply.NRPComboTime or 0) > cfg.ComboWindow then
        ply.NRPCombo = 0
    end
    local combo = ((ply.NRPCombo or 0) % #cfg.LightDamage) + 1
    ply.NRPCombo = combo
    ply.NRPComboTime = CurTime()

    local finisher = combo == #cfg.LightDamage
    CD.Set(ply, "melee", cfg.LightDelay * 0.9, true)
    NRP.Chakra.StopFocus(ply)

    Combat.MeleeHit(ply, {
        amount = cfg.LightDamage[combo] * Stats.Get(ply, "meleePower"),
        kind = "melee",
        knockback = finisher and cfg.FinisherKnockback or cfg.LightKnockback,
        stun = finisher and cfg.FinisherStun or nil,
    })
    return true, combo
end

function Combat.HeavyAttack(ply)
    local cfg = Cfg().Melee
    if not Combat.CanAttack(ply) or CD.IsActive(ply, "heavy") then return false end
    if not NRP.Stamina.Take(ply, cfg.HeavyStamina) then
        NRP.Notify(ply, "Pas assez d'endurance.", NRP.NOTIFY_ERROR, 1.5)
        return false
    end

    CD.Set(ply, "heavy", cfg.HeavyDelay)
    CD.Set(ply, "melee", cfg.HeavyWindup + 0.15, true)
    NRP.Chakra.StopFocus(ply)
    ply:SetNW2Float("NRP_HeavyWindup", CurTime() + cfg.HeavyWindup)
    ply:EmitSound("npc/zombie/zo_attack1.wav", 60, 150)

    timer.Create("NRP.Heavy." .. ply:EntIndex(), cfg.HeavyWindup, 1, function()
        if not IsValid(ply) or not ply:Alive() or not Status.CanAct(ply) then return end
        Combat.MeleeHit(ply, {
            amount = cfg.HeavyDamage * Stats.Get(ply, "meleePower"),
            kind = "melee",
            heavy = true,
            knockback = cfg.HeavyKnockback,
            knockup = 120,
        })
    end)
    return true
end
