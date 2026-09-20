--[[
    Module : effets de statut (partagé)

    Ajouter un statut :
        NRP.Status.Registry:Register("freeze", {
            name = "Gelé", color = Color(...),
            blocksMove = true, blocksAction = true, blocksJutsu = true,
            genjutsu = true,                    -- durée réduite par la résistance aux genjutsu
            modifier = function(data) return { runSpeed = { mul = -0.5 } } end,
            tick = 1, onTick = function(ent, data, source) end,     -- serveur
            onApply = function(ent, data, source) end, onRemove = function(ent, data) end,
        })
    Côté effets de jutsu : effects = { { status = "burn", duration = 4, dps = 5 } }
]]

NRP.Status = NRP.Status or {}
local Status = NRP.Status

Status.Registry = NRP.CreateRegistry("statuses")

local function DamageTick(kind)
    return function(ent, data, source)
        local dps = tonumber(data.dps) or 3
        NRP.Combat.Damage(ent, {
            attacker = source,
            amount = dps * (data.tickInterval or 1),
            kind = "status",
            status = kind,
            unblockable = true,
            element = data.element,
        })
    end
end

local function NPCFreeze(ent, on)
    if SERVER and ent:IsNPC() then
        local cond = on and ((COND and COND.NPC_FREEZE) or 67) or ((COND and COND.NPC_UNFREEZE) or 68)
        ent:SetCondition(cond)
    end
end

Status.Registry:Register("stun", {
    name = "Étourdi", color = Color(250, 220, 80),
    blocksMove = true, blocksAction = true, blocksJutsu = true,
    onApply = function(ent)
        NPCFreeze(ent, true)
        if ent:IsPlayer() then hook.Run("NRP.PlayerStunned", ent) end
    end,
    onRemove = function(ent) NPCFreeze(ent, false) end,
})

Status.Registry:Register("root", {
    name = "Immobilisé", color = Color(120, 90, 60),
    blocksMove = true,
    onApply = function(ent) NPCFreeze(ent, true) end,
    onRemove = function(ent) NPCFreeze(ent, false) end,
})

Status.Registry:Register("slow", {
    name = "Ralenti", color = Color(120, 170, 255),
    modifier = function(data)
        local amount = -math.Clamp(tonumber(data.amount) or 0.3, 0, 0.9)
        return { walkSpeed = { mul = amount }, runSpeed = { mul = amount } }
    end,
})

Status.Registry:Register("silence", {
    name = "Chakra scellé", color = Color(160, 160, 200),
    blocksJutsu = true,
})

Status.Registry:Register("genjutsu", {
    name = "Sous genjutsu", color = Color(190, 90, 220),
    genjutsu = true,
})

Status.Registry:Register("burn", {
    name = "Brûlure", color = Color(255, 110, 30),
    tick = 1, onTick = DamageTick("burn"),
})

Status.Registry:Register("poison", {
    name = "Empoisonné", color = Color(120, 200, 60),
    tick = 1, onTick = DamageTick("poison"),
})

Status.Registry:Register("bleed", {
    name = "Saignement", color = Color(200, 30, 30),
    tick = 1, onTick = DamageTick("bleed"),
})

Status.Registry:Register("chakra_drain", {
    name = "Chakra dévoré", color = Color(60, 60, 60),
    tick = 1,
    onTick = function(ent, data)
        if ent:IsPlayer() then
            NRP.Chakra.Drain(ent, tonumber(data.dps) or 5)
        end
    end,
})

Status.Registry:Register("regen", {
    name = "Régénération", color = Color(90, 230, 120),
    tick = 1,
    onTick = function(ent, data)
        if ent:Health() < ent:GetMaxHealth() then
            ent:SetHealth(math.min(ent:GetMaxHealth(), ent:Health() + (tonumber(data.hps) or 5)))
        end
    end,
})

Status.Registry:Register("invuln", {
    name = "Intouchable", color = Color(255, 255, 255), hidden = true,
})

---------------------------------------------------------------------------
-- Lecture (partagée, basée sur NW2)
---------------------------------------------------------------------------

function Status.GetEnd(ent, id)
    return ent:GetNW2Float("NRP_St_" .. id, 0)
end

function Status.Has(ent, id)
    return Status.GetEnd(ent, id) > CurTime()
end

function Status.Remaining(ent, id)
    return math.max(0, Status.GetEnd(ent, id) - CurTime())
end

function Status.IsStunned(ent)
    return Status.Has(ent, "stun")
end

function Status.CanMove(ent)
    return not Status.Has(ent, "stun") and not Status.Has(ent, "root")
end

function Status.CanAct(ent)
    if ent:IsPlayer() and not ent:Alive() then return false end
    for id, def in Status.Registry:Iterate() do
        if def.blocksAction and Status.Has(ent, id) then
            return false
        end
    end
    return true
end

function Status.CanCast(ent)
    if not Status.CanAct(ent) then return false end
    for id, def in Status.Registry:Iterate() do
        if def.blocksJutsu and Status.Has(ent, id) then
            return false
        end
    end
    return true
end

-- Liste des statuts actifs (HUD)
function Status.GetActive(ent)
    local out = {}
    for id, def in Status.Registry:Iterate() do
        if not def.hidden then
            local remaining = Status.Remaining(ent, id)
            if remaining > 0 then
                out[#out + 1] = { id = id, def = def, remaining = remaining }
            end
        end
    end
    return out
end
