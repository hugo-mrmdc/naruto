--[[
    Module : Jutsu (serveur) - apprentissage, équipement, incantation

    Pipeline d'incantation (100 % serveur) :
        "NRP.CastJutsu"(slot) -> TryCast : vivant, jutsu connu, pas d'incantation en cours,
        statut, garde, cooldown global + jutsu, conditions, CanCast, chakra
        -> incantation (castTime, NW2 NRP_CastEnd) -> FinishCast : revalidation,
        consommation du chakra, cooldown, archetype.Execute, XP d'entraînement.
    Une incantation interrompue (étourdissement...) consomme une partie du chakra.

    API :
        NRP.Jutsu.Learn(ply, id, { force = true, silent = true })
        NRP.Jutsu.Forget(ply, id)
        NRP.Jutsu.SetSlot(ply, slot, id)
        NRP.Jutsu.CancelCast(ply, raison)
        NRP.Jutsu.BuildDamage(ply, jutsu, ctx)
        NRP.Jutsu.FindTarget(ply, portée, rayon)
]]

local Jutsu = NRP.Jutsu
local Char = NRP.Char
local CD = NRP.Cooldown
local Status = NRP.Status

NRP.Net.Pool("JutsuFX")

Jutsu.EVENT_CAST = 1
Jutsu.EVENT_FIRE = 2
Jutsu.EVENT_CANCEL = 3

local function Settings()
    return NRP.Config.JutsuSettings
end

local function Fail(ply, message)
    if (ply.NRPNextJutsuFail or 0) > CurTime() then return end
    ply.NRPNextJutsuFail = CurTime() + Settings().FailNotifyInterval
    NRP.Notify(ply, message, NRP.NOTIFY_ERROR, 1.5)
end

function Jutsu.BroadcastFX(ply, id, event, duration)
    NRP.Net.Start("JutsuFX", true)
        net.WriteEntity(ply)
        net.WriteString(id)
        net.WriteUInt(event, 2)
        net.WriteFloat(duration or 0)
    net.SendPVS(ply:GetPos())
end

---------------------------------------------------------------------------
-- Données
---------------------------------------------------------------------------

hook.Add("NRP.InitCharacter", "NRP.Jutsu.Init", function(ply, data)
    data.jutsus = {}
    data.loadout = {}
end)

hook.Add("NRP.PreCharacterLoaded", "NRP.Jutsu.Sanitize", function(ply, data)
    for id in pairs(data.jutsus) do
        if not Jutsu.Registry:Exists(id) then
            data.jutsus[id] = nil
        end
    end

    local loadout = {}
    for i = 1, Jutsu.SlotCount() do
        local id = data.loadout[i]
        loadout[i] = (isstring(id) and data.jutsus[id]) and id or ""
    end
    data.loadout = loadout
end)

function Jutsu.Learn(ply, id, opts)
    opts = opts or {}
    local data = ply.NRPChar
    local jutsu = Jutsu.Registry:Get(id)
    if not data or not jutsu then return false, "Jutsu inconnu." end
    if Jutsu.Knows(data, id) then return false, "Vous connaissez déjà cette technique." end

    if not opts.force then
        local ok, reason = Jutsu.CheckRequirements(data, jutsu, ply, true)
        if not ok then return false, reason end
    end

    data.jutsus[id] = true
    Char.Touch(ply, "jutsus")

    for i = 1, Jutsu.SlotCount() do
        if data.loadout[i] == "" then
            data.loadout[i] = id
            Char.Touch(ply, "loadout")
            break
        end
    end

    if not opts.silent then
        local category = Jutsu.Categories:Get(jutsu.category)
        NRP.Announce("Nouvelle technique", jutsu.name, category and category.color or color_white, 4, ply)
    end

    hook.Run("NRP.JutsuLearned", ply, id, opts.source)
    return true
end

function Jutsu.Forget(ply, id)
    local data = ply.NRPChar
    if not data or not data.jutsus[id] then return false end

    data.jutsus[id] = nil
    Char.Touch(ply, "jutsus")
    for i = 1, Jutsu.SlotCount() do
        if data.loadout[i] == id then
            data.loadout[i] = ""
        end
    end
    Char.Touch(ply, "loadout")
    return true
end

function Jutsu.CheckAutoUnlocks(ply, silent)
    local data = ply.NRPChar
    if not data then return end

    for id, jutsu in Jutsu.Registry:Iterate() do
        if jutsu.unlock == "auto" and not data.jutsus[id]
            and Jutsu.CheckRequirements(data, jutsu, ply, true) then
            Jutsu.Learn(ply, id, { force = true, silent = silent, source = "auto" })
        end
    end
end

-- Regroupe les vérifications déclenchées plusieurs fois dans le même tick
local function QueueAutoUnlock(ply)
    if ply.NRPAutoUnlockPending then return end
    ply.NRPAutoUnlockPending = true
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        ply.NRPAutoUnlockPending = nil
        Jutsu.CheckAutoUnlocks(ply, false)
    end)
end

local UNLOCK_KEYS = { level = true, rank = true, clan = true, affinities = true, stats = true, dojutsu = true }

hook.Add("NRP.CharacterChanged", "NRP.Jutsu.AutoUnlock", function(ply, key)
    if UNLOCK_KEYS[key] then
        QueueAutoUnlock(ply)
    end
end)

hook.Add("NRP.CharacterLoaded", "NRP.Jutsu.AutoUnlock", function(ply)
    Jutsu.CheckAutoUnlocks(ply, true)
end)

function Jutsu.SetSlot(ply, slot, id)
    local data = ply.NRPChar
    if not data or slot < 1 or slot > Jutsu.SlotCount() then return false end

    if id ~= "" then
        if not data.jutsus[id] then return false end
        for i = 1, Jutsu.SlotCount() do
            if data.loadout[i] == id then
                data.loadout[i] = data.loadout[slot]
            end
        end
    end

    data.loadout[slot] = id
    Char.Touch(ply, "loadout")
    return true
end

---------------------------------------------------------------------------
-- Ciblage et dégâts communs aux archetypes
---------------------------------------------------------------------------

function Jutsu.BuildDamage(ply, jutsu, ctx)
    return {
        attacker = ply,
        inflictor = ply,
        amount = (jutsu.damage or 0) * (ctx.power or 1),
        kind = "jutsu",
        element = jutsu.element,
        jutsu = jutsu.id,
        knockback = jutsu.knockback,
        knockup = jutsu.knockup,
        stun = jutsu.stun,
        statuses = jutsu.effects,
    }
end

function Jutsu.FindTarget(ply, range, radius)
    radius = radius or 12
    local hull = Vector(radius, radius, radius)

    NRP.Util.LagCompensate(ply, true)
    local tr = util.TraceHull({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * range,
        filter = ply,
        mins = -hull, maxs = hull,
        mask = MASK_SHOT_HULL,
    })
    NRP.Util.LagCompensate(ply, false)

    local ent = tr.Entity
    if IsValid(ent) and (ent:IsPlayer() and ent:Alive() or ent:IsNPC() or ent:IsNextBot()) then
        return ent
    end
end

local function PlaySound(ply, jutsu, key)
    local snd = jutsu.sounds and jutsu.sounds[key]
    if snd then
        ply:EmitSound(snd, 75, math.random(95, 105))
    end
end

---------------------------------------------------------------------------
-- Incantation
---------------------------------------------------------------------------

local function CastTimerName(ply)
    return "NRP.Cast." .. ply:EntIndex()
end

local function ClearCastState(ply)
    ply.NRPCast = nil
    timer.Remove(CastTimerName(ply))
    ply:SetNW2Float("NRP_CastEnd", 0)
    ply:SetNW2Bool("NRP_CastRoot", false)
end

local function GiveUsageXP(ply, jutsu)
    local cfg = NRP.Config.Progression.XP
    if (cfg.JutsuUse or 0) <= 0 then return end
    ply.NRPJutsuXP = ply.NRPJutsuXP or {}
    if (ply.NRPJutsuXP[jutsu.id] or 0) > CurTime() then return end
    ply.NRPJutsuXP[jutsu.id] = CurTime() + (cfg.JutsuUseCooldown or 20)
    NRP.Progression.AddTrainingXP(ply, jutsu.xp or cfg.JutsuUse)
end

function Jutsu.FinishCast(ply, token)
    local cast = ply.NRPCast
    if not cast or cast.token ~= token then return end
    ClearCastState(ply)

    local jutsu = Jutsu.Registry:Get(cast.id)
    if not jutsu or not ply:Alive() or not Status.CanCast(ply) then return end

    local ok, reason = Jutsu.CheckRequirements(ply.NRPChar, jutsu, ply)
    if not ok then
        Fail(ply, reason)
        return
    end

    if not NRP.Chakra.Take(ply, cast.cost) then
        Fail(ply, "Pas assez de chakra.")
        return
    end

    local ctx = {
        power = Jutsu.GetPower(ply, jutsu),
        aim = ply:GetAimVector(),
        eye = ply:EyePos(),
        cost = cast.cost,
    }

    local executor = jutsu.OnCast
    if not executor then
        local archetype = Jutsu.Archetypes[jutsu.archetype]
        executor = archetype and archetype.Execute
    end
    if not executor then
        NRP.Error("Archetype introuvable pour le jutsu " .. jutsu.id .. " : " .. tostring(jutsu.archetype))
        NRP.Chakra.Add(ply, cast.cost)
        return
    end

    local success, result, failReason = pcall(executor, ply, jutsu, ctx)
    if not success then
        NRP.Error("Jutsu " .. jutsu.id .. " :", result)
        NRP.Chakra.Add(ply, cast.cost)
        return
    end

    if result == false then
        NRP.Chakra.Add(ply, cast.cost)
        CD.Set(ply, "jutsu:" .. jutsu.id, 0.5)
        Fail(ply, failReason or "Aucune cible valide.")
        return
    end

    CD.Set(ply, "jutsu:" .. jutsu.id, Jutsu.GetCooldown(ply, jutsu))
    PlaySound(ply, jutsu, "fire")
    Jutsu.BroadcastFX(ply, jutsu.id, Jutsu.EVENT_FIRE)
    NRP.Combat.Tag(ply)
    GiveUsageXP(ply, jutsu)

    hook.Run("NRP.JutsuCast", ply, jutsu, ctx)
end

function Jutsu.TryCast(ply, slot)
    local data = ply.NRPChar
    if not data or not ply:Alive() then return end

    local id = data.loadout[slot]
    if not isstring(id) or id == "" then return end

    local jutsu = Jutsu.Registry:Get(id)
    if not jutsu or not data.jutsus[id] then return end
    if ply.NRPCast or Jutsu.IsCasting(ply) then return end
    if CD.IsActive(ply, "gcd") then return end

    if not Status.CanCast(ply) then
        return Fail(ply, "Impossible de former les mudras maintenant.")
    end
    if NRP.Combat.IsBlocking(ply) then
        return Fail(ply, "Baissez votre garde pour lancer un jutsu.")
    end

    local remaining = CD.Remaining(ply, "jutsu:" .. id)
    if remaining > 0 then
        return Fail(ply, string.format("%s : %.1f s", jutsu.name, remaining))
    end

    local ok, reason = Jutsu.CheckRequirements(data, jutsu, ply)
    if not ok then return Fail(ply, reason) end

    if jutsu.CanCast then
        ok, reason = jutsu.CanCast(ply, jutsu)
        if ok == false then return Fail(ply, reason or "Impossible maintenant.") end
    end

    local archetype = Jutsu.Archetypes[jutsu.archetype]
    if archetype and archetype.CanCast and not jutsu.OnCast then
        ok, reason = archetype.CanCast(ply, jutsu)
        if ok == false then return Fail(ply, reason or "Impossible maintenant.") end
    end

    local cost = Jutsu.GetCost(ply, jutsu)
    if not NRP.Chakra.Has(ply, cost) then
        return Fail(ply, "Pas assez de chakra (" .. math.ceil(cost) .. ").")
    end

    NRP.Chakra.StopFocus(ply)
    CD.Set(ply, "gcd", NRP.Config.Combat.GlobalCooldown, true)

    local token = (ply.NRPCastToken or 0) + 1
    ply.NRPCastToken = token
    ply.NRPCast = { id = id, token = token, cost = cost }

    local castTime = Jutsu.GetCastTime(ply, jutsu)
    if castTime <= 0.05 then
        Jutsu.FinishCast(ply, token)
        return
    end

    ply:SetNW2String("NRP_CastJutsu", id)
    ply:SetNW2Bool("NRP_CastRoot", jutsu.rootWhileCasting ~= false)
    ply:SetNW2Float("NRP_CastEnd", CurTime() + castTime)
    PlaySound(ply, jutsu, "cast")
    Jutsu.BroadcastFX(ply, id, Jutsu.EVENT_CAST, castTime)

    timer.Create(CastTimerName(ply), castTime, 1, function()
        if IsValid(ply) then
            Jutsu.FinishCast(ply, token)
        end
    end)
end

function Jutsu.CancelCast(ply, reason, noPenalty)
    local cast = ply.NRPCast
    if not cast then return end

    local jutsu = Jutsu.Registry:Get(cast.id)
    if jutsu and jutsu.interruptible == false and ply:Alive() then return end

    ClearCastState(ply)
    Jutsu.BroadcastFX(ply, cast.id, Jutsu.EVENT_CANCEL)

    if not noPenalty and ply:Alive() then
        NRP.Chakra.Drain(ply, cast.cost * Settings().InterruptChakraRatio)
        NRP.Notify(ply, "Incantation " .. (reason or "annulée") .. " !", NRP.NOTIFY_WARNING, 1.5)
    end
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------

NRP.Net.Receive("CastJutsu", function(ply)
    local slot = net.ReadUInt(4)
    Jutsu.TryCast(ply, slot)
end, { rate = 6, burst = 6, alive = true, maxBytes = 16 })

NRP.Net.Receive("SetLoadout", function(ply)
    local slot = net.ReadUInt(4)
    local id = net.ReadString()
    if id ~= "" and not NRP.Util.IsValidId(id) then return end
    Jutsu.SetSlot(ply, slot, id)
end, { rate = 8, burst = 12, maxBytes = 96 })

hook.Add("PlayerDeath", "NRP.Jutsu.Death", function(ply)
    Jutsu.CancelCast(ply, nil, true)
end)

hook.Add("PlayerDisconnected", "NRP.Jutsu.Cleanup", function(ply)
    timer.Remove(CastTimerName(ply))
    for _, wall in ipairs(ply.NRPWalls or {}) do
        if IsValid(wall) then wall:Remove() end
    end
end)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

NRP.Commands.Add("givejutsu", {
    perm = "admin.jutsu", usage = "givejutsu <joueur> <jutsu|all>", description = "Donner une technique (sans conditions)",
    args = { "player", "string" },
    run = function(caller, target, id)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        if id == "all" then
            for jid in Jutsu.Registry:Iterate() do
                Jutsu.Learn(target, jid, { force = true, silent = true, source = "admin" })
            end
            NRP.LogAction("admin", caller, target, "tous les jutsu")
            return true, "Toutes les techniques données à " .. target:Nick()
        end
        local ok, err = Jutsu.Learn(target, id, { force = true, source = "admin" })
        if not ok then return false, err end
        NRP.LogAction("admin", caller, target, "jutsu +" .. id)
        return true, id .. " donné à " .. target:Nick()
    end,
})

NRP.Commands.Add("takejutsu", {
    perm = "admin.jutsu", usage = "takejutsu <joueur> <jutsu>", description = "Retirer une technique",
    args = { "player", "string" },
    run = function(caller, target, id)
        if not Jutsu.Forget(target, id) then return false, "Ce joueur ne connaît pas cette technique." end
        NRP.LogAction("admin", caller, target, "jutsu -" .. id)
        return true, id .. " retiré à " .. target:Nick()
    end,
})

NRP.Commands.Add("jutsulist", {
    perm = "admin.jutsu", description = "Identifiants des jutsu (console)",
    run = function(caller)
        for id, def in Jutsu.Registry:Iterate() do
            local line = id .. " - " .. def.name .. " [" .. def.category .. ", " .. def.unlock .. "]"
            if caller == NULL then NRP.Print(line) else caller:PrintMessage(HUD_PRINTCONSOLE, line) end
        end
        return true, Jutsu.Registry:Count() .. " jutsu (voir console)"
    end,
})
