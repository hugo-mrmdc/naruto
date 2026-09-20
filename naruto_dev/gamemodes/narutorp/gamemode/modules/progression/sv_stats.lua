--[[
    Module : statistiques (serveur)

    Recalcul événementiel : toute modification de modificateur ou de points programme UN
    recalcul au tick suivant (plusieurs changements dans le même tick = un seul calcul/envoi).

    Hooks :
        "NRP.StatsUpdated"(ply, stats, derived)
        "NRP.PostSpawnStats"(ply)   -- statistiques appliquées après une apparition
]]

local Stats = NRP.Stats

NRP.Net.Pool("Derived")

function Stats.SetModifier(ply, source, mods)
    ply.NRPModifiers = ply.NRPModifiers or {}
    if mods == nil or next(mods) == nil then
        mods = nil
    end
    ply.NRPModifiers[source] = mods
    Stats.Invalidate(ply)
end

function Stats.RemoveModifier(ply, source)
    if ply.NRPModifiers and ply.NRPModifiers[source] ~= nil then
        ply.NRPModifiers[source] = nil
        Stats.Invalidate(ply)
    end
end

function Stats.HasModifier(ply, source)
    return ply.NRPModifiers ~= nil and ply.NRPModifiers[source] ~= nil
end

local function TimerName(ply, source)
    return "NRP.Mod." .. ply:EntIndex() .. "." .. source
end

function Stats.SetTimedModifier(ply, source, mods, duration)
    Stats.SetModifier(ply, source, mods)
    timer.Create(TimerName(ply, source), duration, 1, function()
        if IsValid(ply) then
            Stats.RemoveModifier(ply, source)
        end
    end)
end

function Stats.ClearTimedModifiers(ply)
    for source in pairs(ply.NRPModifiers or {}) do
        if timer.Exists(TimerName(ply, source)) then
            timer.Remove(TimerName(ply, source))
            ply.NRPModifiers[source] = nil
        end
    end
    Stats.Invalidate(ply)
end

function Stats.Invalidate(ply)
    if ply.NRPStatsPending then return end
    ply.NRPStatsPending = true
    timer.Simple(0, function()
        if IsValid(ply) then
            Stats.Recompute(ply)
        end
    end)
end

function Stats.Apply(ply)
    local d = ply.NRPDerived
    if not d then return end

    local oldMax = ply:GetMaxHealth()
    local newMax = math.max(1, math.floor(d.maxHealth))
    local wasFull = ply:Health() >= oldMax
    local freshSpawn = (ply.NRPSpawnTime or 0) + 0.5 > CurTime()

    ply:SetMaxHealth(newMax)
    if freshSpawn or (wasFull and newMax > oldMax) then
        ply:SetHealth(newMax)
    elseif ply:Health() > newMax then
        ply:SetHealth(newMax)
    end

    ply:SetWalkSpeed(math.max(60, d.walkSpeed))
    ply:SetRunSpeed(math.max(80, d.runSpeed))
    ply:SetJumpPower(math.max(100, d.jumpPower))
end

function Stats.Recompute(ply)
    ply.NRPStatsPending = false
    local data = ply.NRPChar
    if not data then return end

    local s, d = Stats.Compute(data.stats, ply.NRPModifiers)
    ply.NRPStats = s
    ply.NRPDerived = d

    if ply:Alive() then
        Stats.Apply(ply)
    end

    NRP.Net.Start("Derived")
        NRP.Net.WriteTable({ stats = s, derived = d })
    net.Send(ply)

    hook.Run("NRP.StatsUpdated", ply, s, d)
end

hook.Add("NRP.PlayerSpawned", "NRP.Stats.Spawn", function(ply)
    if not ply.NRPChar then return end
    ply.NRPSpawnTime = CurTime()
    Stats.Recompute(ply)
    hook.Run("NRP.PostSpawnStats", ply)
end)

hook.Add("PlayerDeath", "NRP.Stats.ClearBuffs", function(ply)
    Stats.ClearTimedModifiers(ply)
end)

hook.Add("NRP.CharacterUnloaded", "NRP.Stats.Clear", function(ply)
    ply.NRPModifiers = {}
    ply.NRPDerived = nil
    ply.NRPStats = nil
end)
