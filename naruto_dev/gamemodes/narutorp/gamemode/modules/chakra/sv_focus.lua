--[[
    Module : concentration du chakra (serveur)

    Maintenir la touche "focus" : régénération multipliée, joueur immobilisé,
    petit gain d'XP d'entraînement. Interrompu par un coup reçu, la mort ou le relâchement.
]]

local Res = NRP.Resource

local function Cfg()
    return NRP.Config.Chakra.Focus
end

local function XPTimer(ply)
    return "NRP.FocusXP." .. ply:EntIndex()
end

function NRP.Chakra.StopFocus(ply)
    if not ply:GetNW2Bool("NRP_Focus", false) then return end
    ply:SetNW2Bool("NRP_Focus", false)
    Res.SetRegenMultiplier(ply, "chakra", "focus", nil)
    timer.Remove(XPTimer(ply))
end

function NRP.Chakra.StartFocus(ply)
    local cfg = Cfg()
    if not ply.NRPChar or not ply:Alive() or ply:GetNW2Bool("NRP_Focus", false) then return end
    if not ply:IsOnGround() then return end
    if NRP.Status and not NRP.Status.CanAct(ply) then return end
    if NRP.Combat and NRP.Combat.IsBlocking(ply) then return end

    if NRP.Combat and NRP.Combat.InCombatFor(ply, cfg.CombatLock) then
        NRP.Notify(ply, "Impossible de se concentrer en plein combat.", NRP.NOTIFY_ERROR, 2)
        return
    end

    if NRP.Chakra.GetMax(ply) - NRP.Chakra.Get(ply) < (cfg.MinChakraMissing or 1) then
        return
    end

    ply:SetNW2Bool("NRP_Focus", true)
    Res.SetRegenMultiplier(ply, "chakra", "focus", cfg.RegenMultiplier)

    local xpCfg = NRP.Config.Progression.XP
    if (xpCfg.FocusTick or 0) > 0 then
        timer.Create(XPTimer(ply), xpCfg.FocusInterval or 15, 0, function()
            if not IsValid(ply) or not ply:GetNW2Bool("NRP_Focus", false) then return end
            if NRP.Chakra.Get(ply) < NRP.Chakra.GetMax(ply) then
                NRP.Progression.AddTrainingXP(ply, xpCfg.FocusTick)
            end
        end)
    end
end

NRP.Keys.OnPress("focus", NRP.Chakra.StartFocus)
NRP.Keys.OnRelease("focus", NRP.Chakra.StopFocus)

hook.Add("NRP.PostDamage", "NRP.Chakra.FocusBreak", function(victim)
    if victim:IsPlayer() and Cfg().BreakOnDamage then
        NRP.Chakra.StopFocus(victim)
    end
end)

hook.Add("PlayerDeath", "NRP.Chakra.FocusDeath", NRP.Chakra.StopFocus)
hook.Add("PlayerDisconnected", "NRP.Chakra.FocusCleanup", function(ply)
    timer.Remove(XPTimer(ply))
end)
