--[[
    Module : Dojutsu (serveur)

        NRP.Dojutsu.UnlockStage(ply, "sharingan", 2)
        NRP.Dojutsu.SetStage(ply, "sharingan", 0)     -- admin (0 = retiré)
        NRP.Dojutsu.Activate(ply) / Deactivate(ply)

    Activation : coût fixe + consommation continue (NRP.Chakra.SetDrain) ; le module chakra
    signale l'épuisement au moment exact, ce qui désactive le dojutsu (aucun Think).
]]

local Dojutsu = NRP.Dojutsu
local Char = NRP.Char
local CD = NRP.Cooldown

local function Settings()
    return NRP.Config.DojutsuSettings
end

function Dojutsu.Deactivate(ply, reason)
    if not ply.NRPDojutsu then return end
    local active = ply.NRPDojutsu
    ply.NRPDojutsu = nil

    ply:SetNW2String("NRP_Dojutsu", "")
    NRP.Stats.RemoveModifier(ply, "dojutsu")
    NRP.Chakra.SetDrain(ply, "dojutsu", nil)

    local def = Dojutsu.Registry:Get(active.id)
    CD.Set(ply, "dojutsu", def and def.cooldown or 3)
    if def and def.sounds and def.sounds.off then
        ply:EmitSound(def.sounds.off)
    end
    if reason then
        NRP.Notify(ply, (def and def.name or "Dojutsu") .. " désactivé : " .. reason, NRP.NOTIFY_WARNING, 2)
    end
    hook.Run("NRP.DojutsuDeactivated", ply, active.id)
end

function Dojutsu.Activate(ply)
    local data = ply.NRPChar
    if not data or not ply:Alive() then return false end

    local id, stageIndex = Dojutsu.GetPreferred(data)
    if not id then
        NRP.Notify(ply, "Vous ne possédez aucun dojutsu.", NRP.NOTIFY_ERROR, 1.5)
        return false
    end

    local def = Dojutsu.Registry:Get(id)
    local stage = def.stages[stageIndex]
    if not stage then return false end

    if not NRP.Status.CanAct(ply) then return false end
    if CD.IsActive(ply, "dojutsu") then
        NRP.Notify(ply, string.format("%s disponible dans %.0f s", def.name, CD.Remaining(ply, "dojutsu")), NRP.NOTIFY_ERROR, 1.5)
        return false
    end
    if not NRP.Chakra.Take(ply, def.activationCost) then
        NRP.Notify(ply, "Pas assez de chakra.", NRP.NOTIFY_ERROR, 1.5)
        return false
    end

    ply.NRPDojutsu = { id = id, stage = stageIndex }
    ply:SetNW2String("NRP_Dojutsu", id .. ":" .. stageIndex)
    NRP.Stats.SetModifier(ply, "dojutsu", stage.modifiers)
    NRP.Chakra.SetDrain(ply, "dojutsu", stage.drain)

    if def.sounds and def.sounds.on then
        ply:EmitSound(def.sounds.on, 70, 120)
    end
    hook.Run("NRP.DojutsuActivated", ply, id, stageIndex)
    return true
end

NRP.Keys.OnPress("dojutsu", function(ply)
    if ply.NRPDojutsu then
        Dojutsu.Deactivate(ply)
    else
        Dojutsu.Activate(ply)
    end
end)

function Dojutsu.UnlockStage(ply, id, stageIndex, silent)
    local data = ply.NRPChar
    local def = Dojutsu.Registry:Get(id)
    if not data or not def then return false end

    stageIndex = math.Clamp(math.floor(stageIndex), 1, #def.stages)
    if Dojutsu.GetUnlocked(data, id) >= stageIndex then return false end

    data.dojutsu[id] = stageIndex
    Char.Touch(ply, "dojutsu")

    for i = 1, stageIndex do
        for _, jutsuId in ipairs(def.stages[i].jutsus) do
            NRP.Jutsu.Learn(ply, jutsuId, { force = true, silent = true, source = "dojutsu" })
        end
    end

    if not silent then
        NRP.Announce("Éveil !", def.stages[stageIndex].name, def.eye.color or Color(255, 60, 60), 5, ply)
    end
    hook.Run("NRP.DojutsuStageChanged", ply, id, stageIndex)
    return true
end

function Dojutsu.SetStage(ply, id, stageIndex)
    local data = ply.NRPChar
    local def = Dojutsu.Registry:Get(id)
    if not data or not def then return false end

    stageIndex = math.Clamp(math.floor(stageIndex), 0, #def.stages)
    if stageIndex == 0 then
        data.dojutsu[id] = nil
        Char.Touch(ply, "dojutsu")
    elseif stageIndex > Dojutsu.GetUnlocked(data, id) then
        Dojutsu.UnlockStage(ply, id, stageIndex)
    else
        data.dojutsu[id] = stageIndex
        Char.Touch(ply, "dojutsu")
    end

    local active = ply.NRPDojutsu
    if active and active.id == id and active.stage > stageIndex then
        Dojutsu.Deactivate(ply, "stade modifié")
    end
    return true
end

-- Déblocages automatiques au niveau (stages "level")
function Dojutsu.CheckLevelUnlocks(ply)
    local data = ply.NRPChar
    if not data then return end

    for id, def in Dojutsu.Registry:Iterate() do
        if not def.clan or def.clan == data.clan then
            local unlocked = Dojutsu.GetUnlocked(data, id)
            local nextStage = def.stages[unlocked + 1]
            while nextStage and nextStage.unlock == "level" and data.level >= nextStage.level do
                unlocked = unlocked + 1
                Dojutsu.UnlockStage(ply, id, unlocked)
                nextStage = def.stages[unlocked + 1]
            end
        end
    end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

hook.Add("NRP.PreCharacterLoaded", "NRP.Dojutsu.Sanitize", function(ply, data)
    for id, stage in pairs(data.dojutsu) do
        local def = Dojutsu.Registry:Get(id)
        if not def then
            data.dojutsu[id] = nil
        else
            data.dojutsu[id] = math.Clamp(tonumber(stage) or 0, 0, #def.stages)
        end
    end
end)

hook.Add("NRP.CharacterLoaded", "NRP.Dojutsu.Load", Dojutsu.CheckLevelUnlocks)
hook.Add("NRP.LevelUp", "NRP.Dojutsu.Level", Dojutsu.CheckLevelUnlocks)

hook.Add("NRP.ClanChanged", "NRP.Dojutsu.Clan", function(ply, newClan)
    Dojutsu.Deactivate(ply)
    local data = ply.NRPChar
    for id in pairs(table.Copy(data.dojutsu)) do
        local def = Dojutsu.Registry:Get(id)
        if def and def.clan and def.clan ~= newClan then
            data.dojutsu[id] = nil
        end
    end
    Char.Touch(ply, "dojutsu")
    Dojutsu.CheckLevelUnlocks(ply)
end)

hook.Add("NRP.ResourceDepleted", "NRP.Dojutsu.Chakra", function(ply, kind)
    if kind == "chakra" then
        Dojutsu.Deactivate(ply, "chakra épuisé")
    end
end)

hook.Add("NRP.PlayerStunned", "NRP.Dojutsu.Stun", function(ply)
    if Settings().DeactivateOnStun then
        Dojutsu.Deactivate(ply, "concentration brisée")
    end
end)

hook.Add("PlayerDeath", "NRP.Dojutsu.Death", function(ply) Dojutsu.Deactivate(ply) end)
hook.Add("NRP.CharacterUnloaded", "NRP.Dojutsu.Unload", function(ply) Dojutsu.Deactivate(ply) end)

NRP.Net.Receive("SetDojutsuStage", function(ply)
    local id = NRP.Net.ReadId()
    local stage = net.ReadUInt(4)
    local data = ply.NRPChar
    if not id or stage < 1 or stage > Dojutsu.GetUnlocked(data, id) then return end

    Char.SetFlag(ply, "dojutsuPref", { id = id, stage = stage })
    NRP.Notify(ply, "Stade préféré : " .. Dojutsu.GetStage(id, stage).name, NRP.NOTIFY_INFO, 2)
end, { rate = 2, burst = 3, maxBytes = 96 })

NRP.Commands.Add("setdojutsu", {
    perm = "admin.dojutsu", usage = "setdojutsu <joueur> <dojutsu> <stade>", description = "Définir le stade d'un dojutsu (0 = retirer)",
    args = { "player", "string", "number" },
    run = function(caller, target, id, stage)
        if not Dojutsu.Registry:Exists(id) then return false, "Dojutsu inconnu." end
        if not Dojutsu.SetStage(target, id, stage) then return false, "Impossible." end
        NRP.LogAction("admin", caller, target, "dojutsu " .. id .. " -> " .. stage)
        return true, target:Nick() .. " : " .. id .. " stade " .. stage
    end,
})
