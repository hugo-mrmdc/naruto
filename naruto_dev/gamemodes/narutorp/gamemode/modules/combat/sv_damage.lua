--[[
    Module : combat - pipeline de dégâts (serveur, autoritaire)

    Toute source de dégâts du gamemode passe par NRP.Combat.Damage :
        NRP.Combat.Damage(victim, {
            attacker = ply, inflictor = ent,
            amount = 30,
            kind = "melee" | "jutsu" | "tool" | "status",
            element = "katon", jutsu = "katon_fireball",
            heavy = true, unblockable = false,
            knockback = 300, knockup = 100, dir = Vector, sourcePos = Vector, pos = Vector,
            stun = 0.5, statuses = { { status = "burn", duration = 3, dps = 4 } },
        })

    Étapes : validité -> autorisation (villages, duel, zones sûres) -> invulnérabilité
             -> hook "NRP.ScaleDamage" (passifs) -> avantage élémentaire -> garde/parade
             -> réduction de dégâts -> application -> recul/statuts -> hook "NRP.PostDamage"
]]

local Combat = NRP.Combat
local Status = NRP.Status
local Stats = NRP.Stats

NRP.Net.Pool("HitFX")

Combat.FX_HIT = 0
Combat.FX_BLOCK = 1
Combat.FX_PARRY = 2
Combat.FX_GUARDBREAK = 3
Combat.FX_DODGE = 4
Combat.FX_SMOKE = 5

local Cfg = Combat.Cfg

function Combat.HitFX(pos, kind)
    NRP.Net.Start("HitFX", true)
        net.WriteVector(pos)
        net.WriteUInt(kind or 0, 3)
    net.SendPVS(pos)
end

---------------------------------------------------------------------------
-- État de combat
---------------------------------------------------------------------------

function Combat.Tag(ent)
    if IsValid(ent) and ent:IsPlayer() then
        ent.NRPLastCombat = CurTime()
    end
end

function Combat.InCombatFor(ply, seconds)
    return (ply.NRPLastCombat or -1e9) + (seconds or Cfg().CombatTagDuration) > CurTime()
end

function Combat.InSafeZone(ent)
    local zones = Cfg().SafeZones[game.GetMap()]
    if not zones then return false end
    local pos = ent:GetPos()
    for _, zone in ipairs(zones) do
        if pos:WithinAABox(zone.min, zone.max) then
            return true, zone
        end
    end
    return false
end

-- attacker peut-il blesser victim ? (joueurs uniquement, le reste est toujours autorisé)
function Combat.CanHarm(attacker, victim)
    if not IsValid(attacker) or not attacker:IsPlayer() then return true end
    if not IsValid(victim) or not victim:IsPlayer() then return true end
    if attacker == victim then return true end
    if not attacker.NRPChar or not victim.NRPChar then return false end
    if Combat.InSafeZone(attacker) or Combat.InSafeZone(victim) then return false end
    if Combat.HasSpawnProtection(victim) then return false end
    if Combat.InDuel(attacker, victim) then return true end

    local result = hook.Run("NRP.CanHarm", attacker, victim)
    if result ~= nil then return result end
    return true
end

---------------------------------------------------------------------------
-- Recul
---------------------------------------------------------------------------

function Combat.Knockback(ent, dir, force, up)
    force, up = force or 0, up or 0
    if force <= 0 and up <= 0 then return end

    local flat = dir and Vector(dir.x, dir.y, 0) or Vector(0, 0, 0)
    if not flat:IsZero() then flat:Normalize() end

    local vel = flat * force + Vector(0, 0, up)
    if force > 150 then
        vel.z = math.max(vel.z, 110)
    end

    if ent:IsPlayer() then
        ent:SetGroundEntity(NULL)
        ent:SetVelocity(vel)
    elseif ent:IsNPC() then
        ent:SetVelocity(vel)
    elseif ent:IsNextBot() then
        if ent.loco then ent.loco:SetVelocity(ent.loco:GetVelocity() + vel) end
    else
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) and phys:IsMoveable() then
            phys:ApplyForceCenter(vel * phys:GetMass())
        end
    end
end

---------------------------------------------------------------------------
-- Garde
---------------------------------------------------------------------------

function Combat.HandleBlock(victim, info)
    local cfg = Cfg().Block
    local attacker = info.attacker

    if info.kind == "melee" and CurTime() - (victim.NRPBlockStart or 0) <= cfg.ParryWindow then
        if IsValid(attacker) then
            Status.Apply(attacker, "stun", cfg.ParryStun, nil, victim)
        end
        NRP.Stamina.Add(victim, 10)
        victim:EmitSound("physics/metal/metal_solid_impact_hard1.wav", 75, 130)
        Combat.HitFX(victim:WorldSpaceCenter(), Combat.FX_PARRY)
        hook.Run("NRP.Parry", victim, attacker)
        return "parry"
    end

    local reduction = cfg.MeleeReduction
    if info.kind == "jutsu" then
        reduction = cfg.JutsuReduction
    elseif info.kind == "tool" then
        reduction = cfg.ToolReduction
    end

    local cost = info.amount * cfg.StaminaPerDamage * (info.heavy and Cfg().Melee.HeavyGuardMultiplier or 1)
    local taken = NRP.Stamina.Drain(victim, cost)

    if taken + 0.01 < cost then
        Combat.StopBlock(victim)
        Status.Apply(victim, "stun", cfg.GuardBreakStun, nil, attacker)
        victim:EmitSound("physics/wood/wood_crate_break" .. math.random(1, 5) .. ".wav", 75, 90)
        Combat.HitFX(victim:WorldSpaceCenter(), Combat.FX_GUARDBREAK)
        info.amount = info.amount * (1 - reduction * 0.5)
        return "broken"
    end

    info.amount = info.amount * (1 - reduction)
    victim:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 70, 120)
    return "blocked"
end

---------------------------------------------------------------------------
-- Dégâts
---------------------------------------------------------------------------

function Combat.Damage(victim, info)
    if not IsValid(victim) then return 0 end
    local attacker = info.attacker

    if victim:IsPlayer() then
        if not victim:Alive() or not victim.NRPChar or victim:HasGodMode() then return 0 end
    end

    if IsValid(attacker) and attacker:IsPlayer() then
        if not Combat.CanHarm(attacker, victim) then return 0 end
        if victim ~= attacker then
            attacker:SetNW2Float("NRP_SpawnProtect", 0)
        end
    end

    if Status.Has(victim, "invuln") then
        if info.kind ~= "status" then
            Combat.HitFX(victim:WorldSpaceCenter(), Combat.FX_DODGE)
        end
        return 0
    end

    info.amount = tonumber(info.amount) or 0
    local sourcePos = info.sourcePos or (IsValid(attacker) and attacker:WorldSpaceCenter()) or info.pos
    local dir = info.dir
    if not dir and sourcePos then
        dir = (victim:WorldSpaceCenter() - sourcePos):GetNormalized()
    end

    hook.Run("NRP.ScaleDamage", victim, info)

    -- Avantage élémentaire contre l'affinité principale de la cible
    if info.element and victim:IsPlayer() then
        local element = NRP.Elements:Get(info.element)
        local primary = NRP.Char.PrimaryAffinity(victim.NRPChar)
        if element and primary and element.strongAgainst == primary then
            info.amount = info.amount * NRP.Config.ElementSettings.StrongMultiplier
        end
    end

    local blockResult
    if victim:IsPlayer() and not info.unblockable and info.kind ~= "status" and Combat.IsBlocking(victim)
        and sourcePos and Combat.IsFacing(victim, sourcePos, Cfg().Block.Angle) then
        blockResult = Combat.HandleBlock(victim, info)
        if blockResult == "parry" then
            return 0
        end
    end
    local blocked = blockResult == "blocked"

    if victim:IsPlayer() then
        info.amount = info.amount * (1 - math.Clamp(Stats.Get(victim, "damageReduction"), 0, 0.9))
    end

    local amount = math.max(0, info.amount)
    local hitPos = info.pos or victim:WorldSpaceCenter()

    if amount > 0 then
        local dmg = DamageInfo()
        dmg:SetDamage(amount)
        dmg:SetAttacker(IsValid(attacker) and attacker or game.GetWorld())
        dmg:SetInflictor(IsValid(info.inflictor) and info.inflictor or dmg:GetAttacker())
        dmg:SetDamageType(info.damageType or (info.kind == "status" and DMG_DIRECT or DMG_CLUB))
        dmg:SetDamagePosition(hitPos)
        if dir then
            dmg:SetDamageForce(dir * math.max(1000, (info.knockback or 0) * 30))
        end

        victim.NRPApplyingDamage = true
        -- kind connu ici -> on tranche nous-mêmes plutôt que de laisser sv_degats_type.lua deviner
        victim.NRPTypeDegats = (info.kind == "melee" or info.kind == "tool") and "physique" or "jutsu"
        victim:TakeDamageInfo(dmg)
        victim.NRPTypeDegats = nil
        victim.NRPApplyingDamage = nil
    end

    if not IsValid(victim) then return amount end

    local kbScale = blocked and 0.3 or 1
    Combat.Knockback(victim, dir, (info.knockback or 0) * kbScale, (info.knockup or 0) * kbScale)

    if not blocked then
        if (info.stun or 0) > 0 then
            Status.Apply(victim, "stun", info.stun, nil, attacker)
        end
        for _, eff in ipairs(info.statuses or {}) do
            Status.Apply(victim, eff.status, eff.duration, table.Copy(eff), attacker)
        end
    end

    if info.kind ~= "status" then
        Combat.Tag(victim)
        Combat.Tag(attacker)
        victim.NRPLastHitTime = CurTime()
        victim.NRPLastAttacker = attacker
        if not blockResult then
            Combat.HitFX(hitPos, Combat.FX_HIT)
        end
    end

    hook.Run("NRP.PostDamage", victim, info, amount, blocked)
    return amount
end

-- Dégâts de zone avec atténuation et ligne de vue
function Combat.RadiusDamage(center, radius, info, falloff, exclude)
    local hits = 0
    for _, ent in ipairs(ents.FindInSphere(center, radius)) do
        if Combat.IsDamageable(ent) and ent ~= exclude and (ent ~= info.attacker or info.selfDamage) then
            local target = ent:WorldSpaceCenter()
            local tr = util.TraceLine({ start = center, endpos = target, mask = MASK_SOLID_BRUSHONLY })
            if not tr.Hit then
                local scale = 1 - math.Clamp(center:Distance(target) / radius, 0, 1) * (falloff or 0)
                local copy = {}
                for k, v in pairs(info) do copy[k] = v end
                copy.amount = (info.amount or 0) * scale
                copy.sourcePos = center
                copy.pos = target
                copy.dir = (target - center):GetNormalized()
                Combat.Damage(ent, copy)
                hits = hits + 1
            end
        end
    end
    return hits
end

-- Cibles dans un cône devant ply
function Combat.FindInCone(ply, range, halfAngle)
    local out = {}
    local origin = ply:GetShootPos()
    local aim = ply:GetAimVector()
    local cosA = math.cos(math.rad(halfAngle))

    for _, ent in ipairs(ents.FindInSphere(origin, range)) do
        if ent ~= ply and Combat.IsDamageable(ent) then
            local to = ent:WorldSpaceCenter() - origin
            local len = to:Length()
            if len > 0 and aim:Dot(to / len) >= cosA then
                local tr = util.TraceLine({ start = origin, endpos = ent:WorldSpaceCenter(), mask = MASK_SOLID_BRUSHONLY })
                if not tr.Hit then
                    out[#out + 1] = ent
                end
            end
        end
    end
    return out
end

---------------------------------------------------------------------------
-- Filtrage des dégâts extérieurs (armes, chutes, PNJ...)
---------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "NRP.Combat.Filter", function(target, dmg)
    if target.NRPApplyingDamage then return end

    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker.NRPDamageScale then
        dmg:ScaleDamage(attacker.NRPDamageScale)
    end

    if not target:IsPlayer() then return end
    if not target.NRPChar then return true end
    if Status.Has(target, "invuln") then return true end

    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= target then
        if Cfg().ExternalDamageVillageRules then
            if not Combat.CanHarm(attacker, target) then return true end
        elseif Combat.InSafeZone(target) or Combat.HasSpawnProtection(target) then
            return true
        end
    end

    if IsValid(attacker) and attacker ~= target then
        Combat.Tag(target)
        target.NRPLastHitTime = CurTime()
        target.NRPLastAttacker = attacker
    end
end)

-- Protection d'apparition
hook.Add("NRP.PostSpawnStats", "NRP.Combat.SpawnProtect", function(ply)
    ply:SetNW2Float("NRP_SpawnProtect", CurTime() + (NRP.Config.General.SpawnProtection or 0))
    ply.NRPLastCombat = nil
end)
