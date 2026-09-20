--[[
    Module : chakra & endurance (partagé)

    Optimisation réseau : une ressource est décrite par un état
        { value, max, regen, drain, time, delayUntil }
    envoyé UNIQUEMENT quand il change (dépense, gain, changement de stats, concentration).
    Le client extrapole la valeur à chaque frame avec NRP.Resource.Compute : aucune
    synchronisation périodique, aucun Think serveur pour la régénération.
]]

NRP.Resource = NRP.Resource or {}
local Res = NRP.Resource

Res.Kinds = { "chakra", "stamina" }
Res.KindIndex = { chakra = 1, stamina = 2 }
Res.Defs = {
    chakra = { name = "Chakra", maxKey = "maxChakra", regenKey = "chakraRegen", delayKey = "RegenDelay" },
    stamina = { name = "Endurance", maxKey = "maxStamina", regenKey = "staminaRegen", delayKey = "StaminaRegenDelay" },
}

NRP.Keys.Register("focus", { name = "Concentrer le chakra (maintenir)", default = KEY_M, order = 20 })

-- Valeur d'un état à l'instant t (drain immédiat, régénération après le délai)
function Res.Compute(st, t)
    if not st then return 0 end

    local value = st.value
    local drain = st.drain or 0
    local delayEnd = math.max(st.time, st.delayUntil or 0)

    local phase1End = math.min(t, delayEnd)
    if phase1End > st.time and drain > 0 then
        value = math.Clamp(value - drain * (phase1End - st.time), 0, st.max)
    end

    if t > delayEnd then
        value = value + ((st.regen or 0) - drain) * (t - delayEnd)
    end

    return math.Clamp(value, 0, st.max)
end

function Res.GetState(ply, kind)
    if SERVER then
        return ply.NRPRes and ply.NRPRes[kind]
    end
    if ply == LocalPlayer() then
        return Res.Local and Res.Local[kind]
    end
end

function Res.GetValue(ply, kind)
    return Res.Compute(Res.GetState(ply, kind), CurTime())
end

function Res.GetMax(ply, kind)
    local st = Res.GetState(ply, kind)
    return st and st.max or 100
end

function Res.Has(ply, kind, amount)
    return Res.GetValue(ply, kind) + 0.001 >= amount
end

-- Raccourcis
NRP.Chakra = NRP.Chakra or {}
NRP.Stamina = NRP.Stamina or {}

for kind, api in pairs({ chakra = NRP.Chakra, stamina = NRP.Stamina }) do
    api.Get = function(ply) return Res.GetValue(ply, kind) end
    api.GetMax = function(ply) return Res.GetMax(ply, kind) end
    api.Has = function(ply, amount) return Res.Has(ply, kind, amount) end
end

function NRP.Chakra.IsFocusing(ply)
    return ply:GetNW2Bool("NRP_Focus", false)
end

-- Immobilisation pendant la concentration (prédit côté client)
hook.Add("SetupMove", "NRP.Chakra.FocusFreeze", function(ply, mv)
    if ply:GetNW2Bool("NRP_Focus", false) and NRP.Config.Chakra.Focus.Freeze then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
    end
end)
