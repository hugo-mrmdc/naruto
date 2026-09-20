--[[
    Module : chakra & endurance (serveur)

        NRP.Chakra.Take(ply, 25)                        -> bool
        NRP.Chakra.Add(ply, 50)
        NRP.Chakra.Fill(ply)
        NRP.Chakra.SetDrain(ply, "dojutsu", 2)          -- consommation continue (nil pour retirer)
        NRP.Chakra.SetRegenMultiplier(ply, "focus", 4)  -- (nil pour retirer)
        (mêmes fonctions pour NRP.Stamina)

    Hook : "NRP.ResourceDepleted"(ply, kind) quand une ressource atteint 0.
]]

local Res = NRP.Resource
local Stats = NRP.Stats

NRP.Net.Pool("Resource")

local function Cfg()
    return NRP.Config.Chakra
end

local function State(ply, kind)
    ply.NRPRes = ply.NRPRes or {}
    local st = ply.NRPRes[kind]
    if not st then
        st = {
            value = 0, max = 100, regen = 0, drain = 0,
            time = CurTime(), delayUntil = 0,
            drains = {}, regenMults = {},
        }
        ply.NRPRes[kind] = st
    end
    return st
end

local function Rebase(st)
    local now = CurTime()
    st.value = Res.Compute(st, now)
    st.time = now
end

local function RefreshRates(ply, kind, st)
    local def = Res.Defs[kind]
    st.max = math.max(1, Stats.Get(ply, def.maxKey))

    local mult = 1
    for _, m in pairs(st.regenMults) do mult = mult * m end
    st.regen = math.max(0, Stats.Get(ply, def.regenKey)) * mult

    local drain = 0
    for _, d in pairs(st.drains) do drain = drain + d end
    st.drain = drain
    st.value = math.min(st.value, st.max)
end

local function DepletionTimerName(ply, kind)
    return "NRP.Res." .. kind .. "." .. ply:EntIndex()
end

-- Programme un événement au moment exact où la ressource tombera à 0 (drains).
local function ScheduleDepletion(ply, kind, st)
    local name = DepletionTimerName(ply, kind)
    if st.drain <= 0 then
        timer.Remove(name)
        return
    end

    local now = CurTime()
    local delayLeft = math.max(0, st.delayUntil - now)
    local afterDelay = st.value - st.drain * delayLeft
    local eta

    if afterDelay <= 0 then
        eta = st.value / st.drain
    elseif st.regen < st.drain then
        eta = delayLeft + afterDelay / (st.drain - st.regen)
    end

    if not eta then
        timer.Remove(name)
        return
    end

    timer.Create(name, math.max(0.05, eta + 0.05), 1, function()
        if IsValid(ply) and Res.GetValue(ply, kind) <= 0.05 then
            hook.Run("NRP.ResourceDepleted", ply, kind)
        end
    end)
end

function Res.Send(ply, kind)
    local st = ply.NRPRes and ply.NRPRes[kind]
    if not st then return end

    NRP.Net.Start("Resource")
        net.WriteUInt(Res.KindIndex[kind], 2)
        net.WriteFloat(st.value)
        net.WriteFloat(st.max)
        net.WriteFloat(st.regen)
        net.WriteFloat(st.drain)
        net.WriteDouble(st.time)
        net.WriteDouble(st.delayUntil)
    net.Send(ply)
end

function Res.Update(ply, kind)
    local st = State(ply, kind)
    Rebase(st)
    RefreshRates(ply, kind, st)
    ScheduleDepletion(ply, kind, st)
    Res.Send(ply, kind)
end

function Res.Take(ply, kind, amount, noDelay)
    amount = tonumber(amount) or 0
    if amount <= 0 then return true end

    local st = State(ply, kind)
    Rebase(st)
    if st.value + 0.001 < amount then
        return false
    end

    st.value = math.max(0, st.value - amount)
    if not noDelay then
        st.delayUntil = CurTime() + (Cfg()[Res.Defs[kind].delayKey] or 1)
    end

    Res.Update(ply, kind)
    if st.value <= 0.05 then
        hook.Run("NRP.ResourceDepleted", ply, kind)
    end
    return true
end

-- Retire jusqu'à amount (sans échec), renvoie la quantité retirée.
function Res.Drain(ply, kind, amount)
    local st = State(ply, kind)
    Rebase(st)
    local taken = math.min(st.value, math.max(0, amount))
    st.value = st.value - taken
    st.delayUntil = CurTime() + (Cfg()[Res.Defs[kind].delayKey] or 1)
    Res.Update(ply, kind)
    if st.value <= 0.05 and taken > 0 then
        hook.Run("NRP.ResourceDepleted", ply, kind)
    end
    return taken
end

function Res.Add(ply, kind, amount)
    local st = State(ply, kind)
    Rebase(st)
    st.value = math.Clamp(st.value + (tonumber(amount) or 0), 0, st.max)
    Res.Update(ply, kind)
end

function Res.Set(ply, kind, value)
    local st = State(ply, kind)
    st.value = math.Clamp(tonumber(value) or 0, 0, st.max)
    st.time = CurTime()
    Res.Update(ply, kind)
end

function Res.Fill(ply, kind)
    local st = State(ply, kind)
    RefreshRates(ply, kind, st)
    st.value = st.max
    st.time = CurTime()
    st.delayUntil = 0
    Res.Update(ply, kind)
end

function Res.SetDrain(ply, kind, source, perSecond)
    local st = State(ply, kind)
    Rebase(st)
    st.drains[source] = (perSecond and perSecond > 0) and perSecond or nil
    Res.Update(ply, kind)
end

function Res.SetRegenMultiplier(ply, kind, source, mult)
    local st = State(ply, kind)
    Rebase(st)
    st.regenMults[source] = mult
    Res.Update(ply, kind)
end

function Res.Reset(ply)
    for _, kind in ipairs(Res.Kinds) do
        local st = State(ply, kind)
        st.drains = {}
        st.regenMults = {}
        timer.Remove(DepletionTimerName(ply, kind))
    end
end

for kind, api in pairs({ chakra = NRP.Chakra, stamina = NRP.Stamina }) do
    api.Take = function(ply, amount, noDelay) return Res.Take(ply, kind, amount, noDelay) end
    api.Drain = function(ply, amount) return Res.Drain(ply, kind, amount) end
    api.Add = function(ply, amount) return Res.Add(ply, kind, amount) end
    api.Set = function(ply, value) return Res.Set(ply, kind, value) end
    api.Fill = function(ply) return Res.Fill(ply, kind) end
    api.SetDrain = function(ply, source, perSecond) return Res.SetDrain(ply, kind, source, perSecond) end
    api.SetRegenMultiplier = function(ply, source, mult) return Res.SetRegenMultiplier(ply, kind, source, mult) end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

hook.Add("NRP.StatsUpdated", "NRP.Resource.Stats", function(ply)
    for _, kind in ipairs(Res.Kinds) do
        Res.Update(ply, kind)
    end
end)

hook.Add("NRP.PostSpawnStats", "NRP.Resource.Spawn", function(ply)
    Res.Reset(ply)
    for _, kind in ipairs(Res.Kinds) do
        Res.Fill(ply, kind)
    end
end)

hook.Add("PlayerDeath", "NRP.Resource.Death", function(ply)
    Res.Reset(ply)
end)

hook.Add("PlayerDisconnected", "NRP.Resource.Cleanup", function(ply)
    Res.Reset(ply)
end)

-- Épuisement du chakra : ralentissement temporaire
hook.Add("NRP.ResourceDepleted", "NRP.Chakra.Exhaustion", function(ply, kind)
    local cfg = Cfg().Exhaustion
    if kind ~= "chakra" or not cfg.Enabled or not ply:Alive() then return end

    Stats.SetTimedModifier(ply, "exhaustion", {
        walkSpeed = { mul = cfg.SpeedMultiplier },
        runSpeed = { mul = cfg.SpeedMultiplier },
    }, cfg.Duration)
    NRP.Notify(ply, "Chakra épuisé !", NRP.NOTIFY_WARNING, 2)
end)
