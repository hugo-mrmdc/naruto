--[[
    Module : combat - actions défensives et mobilité (serveur)
    Garde, esquive, dash, substitution. Déclenchées par les touches USERINFO (sh_combat.lua),
    donc sans message réseau : le serveur lit directement l'appui et valide tout.
]]

local Combat = NRP.Combat
local Status = NRP.Status
local CD = NRP.Cooldown
local Cfg = Combat.Cfg

NRP.Net.Pool("FX")

-- Effet visuel générique (voir cl_fx.lua) envoyé aux joueurs proches
function Combat.PlayFX(fxId, pos, opts)
    opts = opts or {}
    NRP.Net.Start("FX", true)
        net.WriteString(fxId)
        net.WriteVector(pos)
        net.WriteVector(opts.pos2 or pos)
        net.WriteColor(opts.color or color_white, false)
        net.WriteFloat(opts.scale or 1)
        net.WriteEntity(opts.ent or NULL)
    net.SendPVS(pos)
end

local function CanUseAction(ply)
    return ply.NRPChar ~= nil and ply:Alive() and Status.CanAct(ply)
        and not (NRP.Jutsu and NRP.Jutsu.IsCasting(ply))
end

local function MoveDirection(ply)
    local ang = ply:EyeAngles()
    ang.p = 0
    local fwd, right = ang:Forward(), ang:Right()
    local dir = Vector(0, 0, 0)

    if ply:KeyDown(IN_FORWARD) then dir = dir + fwd end
    if ply:KeyDown(IN_BACK) then dir = dir - fwd end
    if ply:KeyDown(IN_MOVERIGHT) then dir = dir + right end
    if ply:KeyDown(IN_MOVELEFT) then dir = dir - right end

    if dir:IsZero() then
        return nil, fwd
    end
    dir:Normalize()
    return dir, fwd
end

---------------------------------------------------------------------------
-- Garde
---------------------------------------------------------------------------

function Combat.StartBlock(ply)
    local cfg = Cfg().Block
    if not CanUseAction(ply) or Combat.IsBlocking(ply) then return end
    if CD.IsActive(ply, "block") then return end
    if NRP.Stamina.Get(ply) < cfg.MinStamina then
        NRP.Notify(ply, "Pas assez d'endurance pour bloquer.", NRP.NOTIFY_ERROR, 1.5)
        return
    end

    NRP.Chakra.StopFocus(ply)
    ply:SetNW2Bool("NRP_Block", true)
    ply.NRPBlockStart = CurTime()
end

function Combat.StopBlock(ply)
    if not Combat.IsBlocking(ply) then return end
    ply:SetNW2Bool("NRP_Block", false)
    CD.Set(ply, "block", Cfg().Block.ReleaseCooldown, true)
end

NRP.Keys.OnPress("block", Combat.StartBlock)
NRP.Keys.OnRelease("block", Combat.StopBlock)

---------------------------------------------------------------------------
-- Esquive : courte, invulnérable quelques instants
---------------------------------------------------------------------------

function Combat.Dodge(ply)
    local cfg = Cfg().Dodge
    if not CanUseAction(ply) or Combat.IsBlocking(ply) then return end
    if CD.IsActive(ply, "dodge") then return end
    if not NRP.Stamina.Take(ply, cfg.Stamina) then
        NRP.Notify(ply, "Pas assez d'endurance.", NRP.NOTIFY_ERROR, 1.5)
        return
    end

    local dir, fwd = MoveDirection(ply)
    dir = dir or -fwd

    NRP.Chakra.StopFocus(ply)
    ply:SetGroundEntity(NULL)
    ply:SetVelocity(dir * cfg.Force + Vector(0, 0, cfg.UpForce))
    Status.Apply(ply, "invuln", cfg.IFrames)
    CD.Set(ply, "dodge", cfg.Cooldown)
    ply:EmitSound("npc/fast_zombie/claw_miss2.wav", 65, 140)
    Combat.PlayFX("dust", ply:GetPos())
end

NRP.Keys.OnPress("dodge", Combat.Dodge)

---------------------------------------------------------------------------
-- Dash : longue distance, sans invulnérabilité
---------------------------------------------------------------------------

function Combat.Dash(ply)
    local cfg = Cfg().Dash
    if not CanUseAction(ply) or Combat.IsBlocking(ply) then return end
    if not cfg.AllowInAir and not ply:IsOnGround() then return end
    if CD.IsActive(ply, "dash") then return end
    if not NRP.Stamina.Take(ply, cfg.Stamina) then
        NRP.Notify(ply, "Pas assez d'endurance.", NRP.NOTIFY_ERROR, 1.5)
        return
    end

    local dir, fwd = MoveDirection(ply)
    dir = dir or fwd

    NRP.Chakra.StopFocus(ply)
    ply:SetGroundEntity(NULL)
    ply:SetVelocity(dir * cfg.Force + Vector(0, 0, cfg.UpForce))
    CD.Set(ply, "dash", cfg.Cooldown)
    ply:EmitSound("npc/fast_zombie/claw_miss1.wav", 65, 90)
    Combat.PlayFX("dust", ply:GetPos(), { scale = 1.5 })
end

NRP.Keys.OnPress("dash", Combat.Dash)

---------------------------------------------------------------------------
-- Substitution (Kawarimi) : utilisable même étourdi, juste après un coup
---------------------------------------------------------------------------

local function TraceDestination(ply, from, dir, distance)
    local mins, maxs = ply:GetHull()
    local tr = util.TraceHull({
        start = from,
        endpos = from + dir * distance,
        mins = mins, maxs = maxs,
        mask = MASK_PLAYERSOLID,
        filter = ply,
    })
    local pos = tr.HitPos
    if NRP.Util.IsHullFree(pos, ply) then return pos end
    pos = pos + Vector(0, 0, 18)
    if NRP.Util.IsHullFree(pos, ply) then return pos end
end

function Combat.Substitution(ply)
    local cfg = Cfg().Substitution
    if not ply.NRPChar or not ply:Alive() or Status.Has(ply, "silence") then return end

    if CD.IsActive(ply, "substitution") then
        NRP.Notify(ply, string.format("Substitution disponible dans %.0f s", CD.Remaining(ply, "substitution")), NRP.NOTIFY_ERROR, 1.5)
        return
    end
    if cfg.RequireRecentHit and (ply.NRPLastHitTime or -1e9) + cfg.RecentHitWindow < CurTime() then
        NRP.Notify(ply, "La substitution s'utilise juste après avoir été touché.", NRP.NOTIFY_ERROR, 1.5)
        return
    end
    if not NRP.Chakra.Has(ply, cfg.Chakra) then
        NRP.Notify(ply, "Pas assez de chakra.", NRP.NOTIFY_ERROR, 1.5)
        return
    end

    local oldPos = ply:GetPos()
    local lift = Vector(0, 0, 4)
    local dest
    local attacker = ply.NRPLastAttacker

    if IsValid(attacker) and attacker:GetPos():DistToSqr(oldPos) < 700 * 700 then
        local back = -attacker:GetForward()
        back.z = 0
        back:Normalize()
        dest = TraceDestination(ply, attacker:GetPos() + lift, back, 70)
    end

    if not dest then
        local back = -ply:GetForward()
        back.z = 0
        back:Normalize()
        dest = TraceDestination(ply, oldPos + lift, back, cfg.Distance)
    end

    if not dest then
        NRP.Notify(ply, "Aucun endroit sûr pour la substitution.", NRP.NOTIFY_ERROR, 1.5)
        return
    end

    NRP.Chakra.Take(ply, cfg.Chakra)

    local log = ents.Create("nrp_substitution_log")
    if IsValid(log) then
        log:SetPos(oldPos + Vector(0, 0, 36))
        log:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        log.Lifetime = cfg.LogLifetime
        log:Spawn()
    end

    Status.Remove(ply, "stun")
    Status.Remove(ply, "root")
    ply:SetPos(dest)
    ply:SetVelocity(-ply:GetVelocity())

    if IsValid(attacker) then
        local ang = (attacker:WorldSpaceCenter() - ply:EyePos()):Angle()
        ply:SetEyeAngles(Angle(ang.p, ang.y, 0))
    end

    Status.Apply(ply, "invuln", cfg.IFrames)
    CD.Set(ply, "substitution", cfg.Cooldown)
    ply.NRPLastHitTime = nil

    ply:EmitSound("ambient/wind/wind_hit1.wav", 70, 120)
    Combat.PlayFX("smoke", oldPos + Vector(0, 0, 36))
    Combat.PlayFX("smoke", dest + Vector(0, 0, 36))
end

NRP.Keys.OnPress("substitution", Combat.Substitution)

hook.Add("PlayerDeath", "NRP.Combat.ResetActions", function(ply)
    Combat.StopBlock(ply)
end)
