--[[
    Module : progression (serveur) - XP, niveaux, points de statistiques

        NRP.Progression.AddXP(ply, 100, "mission")
        NRP.Progression.AddTrainingXP(ply, 2)     -- plafonné par heure
        NRP.Progression.SetLevel(ply, 20)
        NRP.Progression.AddStatPoints(ply, 3)     -- points bonus (conservés lors d'un reset)
        NRP.Progression.ResetStats(ply)

    Hooks : "NRP.ModifyXP"(ply, amount, source) -> nouveau montant
            "NRP.LevelUp"(ply, newLevel, oldLevel)
]]

local Prog = NRP.Progression
local Char = NRP.Char
local Stats = NRP.Stats

NRP.Net.Pool("LevelUp")

local function Cfg()
    return NRP.Config.Progression
end

hook.Add("NRP.InitCharacter", "NRP.Progression.Init", function(ply, data)
    local cfg = NRP.Config.Character
    data.level = math.Clamp(cfg.StartLevel or 1, 1, Cfg().MaxLevel)
    data.rank = NRP.Ranks.Get(cfg.StartRank) and cfg.StartRank or NRP.Config.Ranks[1].id
    data.statPoints = Prog.StatPointsForLevel(data.level)
    data.stats = {}
end)

-- Nettoie des données incohérentes (stat supprimée de la config, grade inconnu...)
hook.Add("NRP.PreCharacterLoaded", "NRP.Progression.Sanitize", function(ply, data)
    for id in pairs(data.stats) do
        if not Stats.Defs:Exists(id) then
            data.statPoints = data.statPoints + (tonumber(data.stats[id]) or 0)
            data.stats[id] = nil
        end
    end
    if not NRP.Ranks.Get(data.rank) then
        data.rank = NRP.Config.Ranks[1].id
    end
    data.level = math.Clamp(data.level, 1, Cfg().MaxLevel)
end)

function Prog.OnLevelUp(ply, oldLevel, newLevel)
    local data = ply.NRPChar
    local cfg = Cfg()

    Char.Set(ply, "level", newLevel)
    if newLevel > oldLevel then
        Char.Set(ply, "statPoints", data.statPoints + (newLevel - oldLevel) * cfg.StatPointsPerLevel)
    end

    hook.Run("NRP.LevelUp", ply, newLevel, oldLevel)
    Stats.Invalidate(ply)

    if newLevel > oldLevel and ply:Alive() then
        ply:SetHealth(ply:GetMaxHealth())
        ply:EmitSound("garrysmod/save_load4.wav", 70, 110)
        NRP.Net.Start("LevelUp")
            net.WriteEntity(ply)
            net.WriteUInt(newLevel, 8)
        net.SendPVS(ply:GetPos())
    end
end

function Prog.AddXP(ply, amount, source, silent)
    local data = ply.NRPChar
    amount = tonumber(amount) or 0
    if not data or amount == 0 then return 0 end

    if amount > 0 then
        amount = hook.Run("NRP.ModifyXP", ply, amount, source) or amount
        local mult = (Cfg().XPMultiplier or 1) * Stats.Get(ply, "xpMultiplier")
        if NRP.Events and NRP.Events.GetMultiplier then
            mult = mult * NRP.Events.GetMultiplier("xp")
        end
        amount = math.floor(amount * mult + 0.5)
    end

    local maxLevel = Cfg().MaxLevel
    local level = data.level
    local xp = math.max(0, data.xp + amount)

    while level < maxLevel and xp >= Prog.XPForLevel(level) do
        xp = xp - Prog.XPForLevel(level)
        level = level + 1
    end
    if level >= maxLevel then
        xp = math.min(xp, Prog.XPForLevel(level))
    end

    Char.Set(ply, "xp", xp)
    if level ~= data.level then
        Prog.OnLevelUp(ply, data.level, level)
    end

    if not silent and amount ~= 0 then
        NRP.Notify(ply, (amount > 0 and "+" or "") .. amount .. " XP", NRP.NOTIFY_XP, 2)
    end
    return amount
end

function Prog.AddTrainingXP(ply, amount)
    local cap = Cfg().XP.TrainingHourlyCap or 0
    local t = ply.NRPTraining
    if not t or t.reset < CurTime() then
        t = { reset = CurTime() + 3600, gained = 0 }
        ply.NRPTraining = t
    end
    if cap > 0 and t.gained >= cap then return 0 end

    amount = math.min(amount, cap > 0 and (cap - t.gained) or amount)
    local gained = Prog.AddXP(ply, amount, "training", true)
    t.gained = t.gained + gained
    return gained
end

function Prog.SetLevel(ply, level)
    local data = ply.NRPChar
    if not data then return false end
    level = math.Clamp(math.floor(level), 1, Cfg().MaxLevel)

    local old = data.level
    Char.Set(ply, "xp", 0)
    Prog.OnLevelUp(ply, old, level)

    -- Recalcule les points : gagnés - dépensés (reset si négatif)
    local spent = 0
    for _, v in pairs(data.stats) do spent = spent + (tonumber(v) or 0) end
    local total = Prog.StatPointsForLevel(level) + (Char.GetFlag(ply, "bonusStatPoints", 0))
    if spent > total then
        Prog.ResetStats(ply)
    else
        Char.Set(ply, "statPoints", total - spent)
    end

    hook.Run("NRP.LevelSet", ply, level, old)
    return true
end

function Prog.AddStatPoints(ply, amount)
    if not ply.NRPChar then return end
    Char.SetFlag(ply, "bonusStatPoints", Char.GetFlag(ply, "bonusStatPoints", 0) + amount)
    Char.Set(ply, "statPoints", math.max(0, ply.NRPChar.statPoints + amount))
end

function Prog.ResetStats(ply)
    local data = ply.NRPChar
    if not data then return end
    data.stats = {}
    Char.Touch(ply, "stats")
    Char.Set(ply, "statPoints", Prog.StatPointsForLevel(data.level) + Char.GetFlag(ply, "bonusStatPoints", 0))
    Stats.Invalidate(ply)
end

function Prog.AllocateStat(ply, statId, amount)
    local data = ply.NRPChar
    local def = Stats.Defs:Get(statId)
    if not data or not def then return false, "Statistique inconnue." end

    amount = math.floor(amount)
    if amount < 1 or amount > data.statPoints then
        return false, "Pas assez de points."
    end

    local current = tonumber(data.stats[statId]) or 0
    if current + amount > (def.max or math.huge) then
        return false, def.name .. " est au maximum."
    end

    data.stats[statId] = current + amount
    Char.Touch(ply, "stats")
    Char.Set(ply, "statPoints", data.statPoints - amount)
    Stats.Invalidate(ply)
    return true
end

NRP.Net.Receive("AllocateStat", function(ply)
    local statId = NRP.Net.ReadId()
    local amount = net.ReadUInt(7)
    if not statId then return end

    local ok, err = Prog.AllocateStat(ply, statId, amount)
    if not ok then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR)
    end
end, { rate = 8, burst = 12 })

---------------------------------------------------------------------------
-- XP de combat
---------------------------------------------------------------------------

hook.Add("PlayerDeath", "NRP.Progression.KillXP", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    if not attacker.NRPChar or not victim.NRPChar then return end

    local cfg = Cfg().XP
    attacker.NRPKillLog = attacker.NRPKillLog or {}
    local key = victim.NRPChar.steamid
    if (attacker.NRPKillLog[key] or 0) > CurTime() then return end
    attacker.NRPKillLog[key] = CurTime() + (cfg.SameVictimCooldown or 600)

    local ratio = math.Clamp(victim.NRPChar.level / math.max(1, attacker.NRPChar.level), 0.25, 2)
    Prog.AddXP(attacker, math.floor((cfg.KillPlayer or 0) * ratio), "kill_player")
end)

hook.Add("OnNPCKilled", "NRP.Progression.NPCXP", function(npc, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() or not attacker.NRPChar then return end
    local amount = npc.NRPXPReward or Cfg().XP.KillNPC or 0
    if amount > 0 then
        Prog.AddXP(attacker, amount, "kill_npc")
    end
end)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

NRP.Commands.Add("givexp", {
    perm = "admin.xp", usage = "givexp <joueur> <xp>", description = "Donner (ou retirer) de l'XP",
    args = { "player", "number" }, aliases = { "addxp" },
    run = function(caller, target, amount)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        local gained = Prog.AddXP(target, math.floor(amount), "admin", false)
        NRP.LogAction("admin", caller, target, "XP " .. gained .. " -> " .. target:Nick())
        return true, gained .. " XP donnés à " .. target:Nick()
    end,
})

NRP.Commands.Add("setlevel", {
    perm = "admin.xp", usage = "setlevel <joueur> <niveau>", description = "Définir le niveau",
    args = { "player", "number" },
    run = function(caller, target, level)
        if not Prog.SetLevel(target, level) then return false, "Ce joueur n'a pas de personnage." end
        NRP.LogAction("admin", caller, target, "niveau -> " .. level)
        return true, target:Nick() .. " est maintenant niveau " .. target.NRPChar.level
    end,
})

NRP.Commands.Add("statpoints", {
    perm = "admin.stats", usage = "statpoints <joueur> <points>", description = "Donner des points de statistiques",
    args = { "player", "number" },
    run = function(caller, target, amount)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        Prog.AddStatPoints(target, math.floor(amount))
        NRP.LogAction("admin", caller, target, "points de stats " .. amount)
        return true, amount .. " point(s) donné(s) à " .. target:Nick()
    end,
})

NRP.Commands.Add("resetstats", {
    perm = "admin.stats", usage = "resetstats <joueur>", description = "Réinitialiser les statistiques",
    args = { "player" },
    run = function(caller, target)
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        Prog.ResetStats(target)
        NRP.LogAction("admin", caller, target, "reset des stats")
        return true, "Statistiques de " .. target:Nick() .. " réinitialisées."
    end,
})
