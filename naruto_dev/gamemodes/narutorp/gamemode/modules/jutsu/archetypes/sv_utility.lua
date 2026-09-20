--[[
    Archetypes utilitaires : wall, buff, heal, teleport, genjutsu, bind
]]

local Jutsu = NRP.Jutsu
local Combat = NRP.Combat
local Status = NRP.Status
local Stats = NRP.Stats

---------------------------------------------------------------------------
-- wall : mur défensif devant soi (range, duration, health, model)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("wall", {
    Execute = function(ply, jutsu, ctx)
        local fwd = ply:GetForward()
        fwd.z = 0
        fwd:Normalize()

        local pos = ply:GetPos() + fwd * (jutsu.range or 140)
        local tr = util.TraceLine({
            start = pos + Vector(0, 0, 60),
            endpos = pos - Vector(0, 0, 200),
            mask = MASK_SOLID_BRUSHONLY,
        })
        if not tr.Hit then
            return false, "Aucun sol pour élever le mur."
        end

        ply.NRPWalls = ply.NRPWalls or {}
        for i = #ply.NRPWalls, 1, -1 do
            if not IsValid(ply.NRPWalls[i]) then table.remove(ply.NRPWalls, i) end
        end
        while #ply.NRPWalls >= NRP.Config.JutsuSettings.MaxWallsPerPlayer do
            local oldest = table.remove(ply.NRPWalls, 1)
            if IsValid(oldest) then oldest:Remove() end
        end

        local wall = ents.Create("nrp_jutsu_wall")
        if not IsValid(wall) then return false end
        wall.WallModel = jutsu.model
        wall.WallHealth = (jutsu.health or 300) * ctx.power
        wall.Lifetime = jutsu.duration or 10
        wall:SetPos(tr.HitPos)
        wall:SetAngles(Angle(0, ply:EyeAngles().y + 90, 0))
        wall:SetOwner(ply)
        wall:Spawn()

        ply.NRPWalls[#ply.NRPWalls + 1] = wall
        Combat.PlayFX(jutsu.fx or "earth", tr.HitPos, { scale = 1.5, color = jutsu.color })
        return true
    end,
})

---------------------------------------------------------------------------
-- buff : modificateurs temporaires (modifiers, duration, healthDrain, scale)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("buff", {
    Execute = function(ply, jutsu)
        local duration = jutsu.duration or 10
        local source = "jutsu:" .. jutsu.id
        local idx = ply:EntIndex()

        Stats.SetTimedModifier(ply, source, jutsu.modifiers or {}, duration)

        if (jutsu.healthDrain or 0) > 0 then
            timer.Create("NRP.BuffDrain." .. idx .. "." .. jutsu.id, 1, duration, function()
                if IsValid(ply) and ply:Alive() then
                    ply:SetHealth(math.max(1, ply:Health() - jutsu.healthDrain))
                end
            end)
        end

        if jutsu.scale then
            ply:SetModelScale(jutsu.scale, 0.4)
            timer.Create("NRP.BuffScale." .. idx, duration, 1, function()
                if IsValid(ply) then ply:SetModelScale(1, 0.4) end
            end)
        end

        Combat.PlayFX(jutsu.fx or "aura", ply:GetPos(), { ent = ply, color = jutsu.color, scale = duration })
        return true
    end,
})

hook.Add("PlayerDeath", "NRP.Jutsu.BuffCleanup", function(ply)
    local idx = ply:EntIndex()
    timer.Remove("NRP.BuffScale." .. idx)
    for id in Jutsu.Registry:Iterate() do
        timer.Remove("NRP.BuffDrain." .. idx .. "." .. id)
    end
    if ply:GetModelScale() ~= 1 then
        ply:SetModelScale(1, 0)
    end
end)

---------------------------------------------------------------------------
-- heal : soigne la cible visée ou soi-même (heal, range)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("heal", {
    Execute = function(ply, jutsu, ctx)
        local target = Jutsu.FindTarget(ply, jutsu.range or 120, 16)
        if not IsValid(target) or not target:IsPlayer() then
            target = ply
        end

        local amount = (jutsu.heal or 30) * ctx.power
        target:SetHealth(math.min(target:GetMaxHealth(), target:Health() + amount))
        if jutsu.cure then
            Status.Cure(target, jutsu.cure)
        end

        Combat.PlayFX(jutsu.fx or "heal", target:WorldSpaceCenter(), { color = jutsu.color })
        if target ~= ply then
            NRP.Notify(target, ply:Nick() .. " vous a soigné (+" .. math.floor(amount) .. ")", NRP.NOTIFY_SUCCESS, 2)
        end
        return true
    end,
})

---------------------------------------------------------------------------
-- teleport : déplacement instantané vers le point visé (range)
---------------------------------------------------------------------------
Jutsu.RegisterArchetype("teleport", {
    Execute = function(ply, jutsu, ctx)
        local mins, maxs = ply:GetHull()
        local start = ply:GetPos() + Vector(0, 0, 8)
        local tr = util.TraceHull({
            start = start,
            endpos = start + ctx.aim * (jutsu.range or 500),
            mins = mins, maxs = maxs,
            mask = MASK_PLAYERSOLID,
            filter = ply,
        })

        local dest = tr.HitPos
        if tr.Fraction < 0.1 or not NRP.Util.IsHullFree(dest, ply) then
            return false, "Destination bloquée."
        end

        Combat.PlayFX(jutsu.fx or "smoke", ply:GetPos() + Vector(0, 0, 36))
        ply:SetPos(dest)
        ply:SetVelocity(-ply:GetVelocity())
        Combat.PlayFX(jutsu.fx or "smoke", dest + Vector(0, 0, 36))
        return true
    end,
})

---------------------------------------------------------------------------
-- genjutsu : applique les effets à la cible visée, modulés par la résistance
---------------------------------------------------------------------------
local function ValidHostileTarget(ply, target)
    if not IsValid(target) then return false end
    if target:IsPlayer() and not Combat.CanHarm(ply, target) then return false end
    return true
end

Jutsu.RegisterArchetype("genjutsu", {
    CanCast = function(ply, jutsu)
        if not ValidHostileTarget(ply, Jutsu.FindTarget(ply, jutsu.range or 800, 16)) then
            return false, "Visez une cible."
        end
        return true
    end,
    Execute = function(ply, jutsu, ctx)
        local target = Jutsu.FindTarget(ply, jutsu.range or 800, 16)
        if not ValidHostileTarget(ply, target) then
            return false, "La cible a quitté votre regard."
        end

        local resist = target:IsPlayer() and Stats.Get(target, "genjutsuResist") or 0
        local factor = math.Clamp(ctx.power - resist, 0.2, 2)

        for _, eff in ipairs(jutsu.effects or {}) do
            local def = Status.Registry:Get(eff.status)
            local duration = eff.duration or jutsu.duration or 3
            if def and not def.genjutsu then
                duration = duration * factor
            end
            Status.Apply(target, eff.status, duration, table.Copy(eff), ply)
        end

        if (jutsu.damage or 0) > 0 then
            Combat.Damage(target, Jutsu.BuildDamage(ply, jutsu, ctx))
        end

        Combat.Tag(target)
        Combat.PlayFX(jutsu.fx or "genjutsu", target:WorldSpaceCenter(), { color = jutsu.color })
        return true
    end,
})

---------------------------------------------------------------------------
-- bind : immobilise la cible ET le lanceur, avec consommation continue (range, duration, drain)
---------------------------------------------------------------------------
local function BindTimer(ply)
    return "NRP.Bind." .. ply:EntIndex()
end

function Jutsu.ReleaseBind(ply)
    local bind = ply.NRPBind
    if not bind then return end
    ply.NRPBind = nil
    timer.Remove(BindTimer(ply))
    NRP.Chakra.SetDrain(ply, "bind", nil)

    if IsValid(bind.target) then
        Status.Remove(bind.target, "root")
    end
    if IsValid(ply) then
        Status.Remove(ply, "root")
    end
end

Jutsu.RegisterArchetype("bind", {
    CanCast = function(ply, jutsu)
        if ply.NRPBind then return false, "Vous maintenez déjà une technique." end
        if not ValidHostileTarget(ply, Jutsu.FindTarget(ply, jutsu.range or 600, 16)) then
            return false, "Visez une cible."
        end
        return true
    end,
    Execute = function(ply, jutsu, ctx)
        local target = Jutsu.FindTarget(ply, jutsu.range or 600, 16)
        if not ValidHostileTarget(ply, target) then
            return false, "La cible a échappé à votre ombre."
        end

        local resist = target:IsPlayer() and Stats.Get(target, "genjutsuResist") or 0
        local duration = (jutsu.duration or 5) * math.Clamp(1 - resist * 0.5, 0.3, 1)

        Status.Apply(target, "root", duration, nil, ply)
        Status.Apply(ply, "root", duration)
        NRP.Chakra.SetDrain(ply, "bind", jutsu.drain or 5)

        ply.NRPBind = { target = target }
        timer.Create(BindTimer(ply), duration, 1, function()
            if IsValid(ply) then Jutsu.ReleaseBind(ply) end
        end)

        Combat.Tag(target)
        Combat.PlayFX(jutsu.fx or "shadow", ply:GetPos(), { pos2 = target:GetPos(), scale = duration, color = jutsu.color })
        return true
    end,
})

-- Le lien se rompt si le lanceur est touché, meurt ou n'a plus de chakra
hook.Add("NRP.PostDamage", "NRP.Jutsu.BindBreak", function(victim, info, amount)
    if victim.NRPBind and amount > 0 then
        Jutsu.ReleaseBind(victim)
    end
end)

hook.Add("NRP.ResourceDepleted", "NRP.Jutsu.BindChakra", function(ply, kind)
    if kind == "chakra" and ply.NRPBind then
        Jutsu.ReleaseBind(ply)
    end
end)

hook.Add("PlayerDeath", "NRP.Jutsu.BindDeath", Jutsu.ReleaseBind)
hook.Add("PlayerDisconnected", "NRP.Jutsu.BindCleanup", Jutsu.ReleaseBind)
