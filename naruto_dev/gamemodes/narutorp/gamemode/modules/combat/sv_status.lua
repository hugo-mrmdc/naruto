--[[
    Module : effets de statut (serveur)

        NRP.Status.Apply(ent, "stun", 1.5, data, source)
        NRP.Status.Remove(ent, "stun")
        NRP.Status.Cure(ent, { "burn", "poison" })
        NRP.Status.ClearAll(ent)

    Hook : "NRP.StatusApply"(ent, id, duration, data, source) -> false pour annuler,
           ou un nombre pour remplacer la durée.
]]

local Status = NRP.Status

local function TimerName(ent, id, kind)
    return "NRP.Status." .. kind .. "." .. ent:EntIndex() .. "." .. id
end

function Status.Apply(ent, id, duration, data, source)
    local def = Status.Registry:Get(id)
    duration = tonumber(duration) or 0
    if not def or duration <= 0 or not IsValid(ent) then return false end
    if ent:IsPlayer() and not ent:Alive() then return false end

    data = data or {}

    if def.genjutsu and ent:IsPlayer() then
        local resist = math.Clamp(NRP.Stats.Get(ent, "genjutsuResist"), 0, 0.9)
        local power = 1
        if IsValid(source) and source:IsPlayer() then
            power = NRP.Stats.Get(source, "genjutsuPower")
        end
        duration = duration * math.Clamp(1 - resist + (power - 1) * 0.5, 0.1, 2)
    end

    local override = hook.Run("NRP.StatusApply", ent, id, duration, data, source)
    if override == false then return false end
    if isnumber(override) then duration = override end

    local now = CurTime()
    ent.NRPStatus = ent.NRPStatus or {}
    local current = ent.NRPStatus[id]
    local endTime = now + duration
    if current and current.endTime > endTime then
        endTime = current.endTime
    end

    data.tickInterval = def.tick
    ent.NRPStatus[id] = { endTime = endTime, data = data, source = source }
    ent:SetNW2Float("NRP_St_" .. id, endTime)

    if not current and def.onApply then
        def.onApply(ent, data, source)
    end

    if def.modifier and ent:IsPlayer() then
        NRP.Stats.SetModifier(ent, "status:" .. id, def.modifier(data))
    end

    if def.tick and def.onTick and not timer.Exists(TimerName(ent, id, "tick")) then
        timer.Create(TimerName(ent, id, "tick"), def.tick, 0, function()
            if not IsValid(ent) then return end
            local st = ent.NRPStatus and ent.NRPStatus[id]
            if not st or st.endTime <= CurTime() then return end
            def.onTick(ent, st.data, st.source)
        end)
    end

    timer.Create(TimerName(ent, id, "end"), endTime - now, 1, function()
        if IsValid(ent) then Status.Remove(ent, id) end
    end)

    return true
end

function Status.Remove(ent, id)
    local st = ent.NRPStatus and ent.NRPStatus[id]
    if not st then return end

    local def = Status.Registry:Get(id)
    ent.NRPStatus[id] = nil
    ent:SetNW2Float("NRP_St_" .. id, 0)
    timer.Remove(TimerName(ent, id, "tick"))
    timer.Remove(TimerName(ent, id, "end"))

    if def then
        if def.modifier and ent:IsPlayer() then
            NRP.Stats.RemoveModifier(ent, "status:" .. id)
        end
        if def.onRemove then
            def.onRemove(ent, st.data)
        end
    end
end

function Status.Cure(ent, ids)
    for _, id in ipairs(ids or {}) do
        Status.Remove(ent, id)
    end
end

function Status.ClearAll(ent)
    for id in pairs(ent.NRPStatus or {}) do
        Status.Remove(ent, id)
    end
end

-- Un joueur étourdi perd sa garde, son incantation et sa concentration.
hook.Add("NRP.PlayerStunned", "NRP.Status.Interrupt", function(ply)
    NRP.Combat.StopBlock(ply)
    NRP.Chakra.StopFocus(ply)
    if NRP.Jutsu and NRP.Jutsu.CancelCast then
        NRP.Jutsu.CancelCast(ply, "interrompue")
    end
end)

hook.Add("PlayerDeath", "NRP.Status.Death", Status.ClearAll)
hook.Add("PlayerSpawn", "NRP.Status.Spawn", Status.ClearAll)

hook.Add("EntityRemoved", "NRP.Status.Cleanup", function(ent)
    if not ent.NRPStatus then return end
    for id in pairs(ent.NRPStatus) do
        timer.Remove(TimerName(ent, id, "tick"))
        timer.Remove(TimerName(ent, id, "end"))
    end
end)
