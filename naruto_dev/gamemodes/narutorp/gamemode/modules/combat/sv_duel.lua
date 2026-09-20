--[[
    Module : combat - duels (serveur)
    Autorise temporairement les dégâts entre deux joueurs (entraînement, même village).
        !duel <joueur>   /   !duel accept   /   !duel cancel
]]

local Combat = NRP.Combat

Combat.Duels = Combat.Duels or {}      -- [ply] = { opponent, ends }
Combat.DuelRequests = Combat.DuelRequests or {}  -- [target] = { from, expires }

local function Cfg()
    return Combat.Cfg().Duel
end

function Combat.InDuel(a, b)
    local d = Combat.Duels[a]
    return d ~= nil and d.opponent == b and d.ends > CurTime()
end

function Combat.EndDuel(ply, reason)
    local d = Combat.Duels[ply]
    if not d then return end

    Combat.Duels[ply] = nil
    local other = d.opponent
    if IsValid(other) and Combat.Duels[other] and Combat.Duels[other].opponent == ply then
        Combat.Duels[other] = nil
        NRP.Notify(other, "Duel terminé : " .. reason, NRP.NOTIFY_INFO)
    end
    if IsValid(ply) then
        NRP.Notify(ply, "Duel terminé : " .. reason, NRP.NOTIFY_INFO)
    end

    if next(Combat.Duels) == nil then
        timer.Remove("NRP.Duels.Check")
    end
end

local function CheckDuels()
    local maxDist = Cfg().MaxDistance ^ 2
    for ply, d in pairs(Combat.Duels) do
        if not IsValid(ply) or not IsValid(d.opponent) then
            Combat.Duels[ply] = nil
        elseif d.ends <= CurTime() then
            Combat.EndDuel(ply, "temps écoulé")
        elseif ply:GetPos():DistToSqr(d.opponent:GetPos()) > maxDist then
            Combat.EndDuel(ply, "adversaire trop éloigné")
        end
    end
    if next(Combat.Duels) == nil then
        timer.Remove("NRP.Duels.Check")
    end
end

local function StartDuel(a, b)
    local ends = CurTime() + Cfg().Duration
    Combat.Duels[a] = { opponent = b, ends = ends }
    Combat.Duels[b] = { opponent = a, ends = ends }
    timer.Create("NRP.Duels.Check", 2, 0, CheckDuels)

    NRP.Announce("Duel !", "Contre " .. b:Nick(), Color(255, 120, 40), 3, a)
    NRP.Announce("Duel !", "Contre " .. a:Nick(), Color(255, 120, 40), 3, b)
end

NRP.Commands.Add("duel", {
    needChar = true, usage = "duel <joueur|accept|cancel>", description = "Proposer un duel",
    args = { "string" },
    run = function(caller, arg)
        local lower = string.lower(arg)

        if lower == "accept" then
            local req = Combat.DuelRequests[caller]
            Combat.DuelRequests[caller] = nil
            if not req or req.expires < CurTime() or not IsValid(req.from) then
                return false, "Aucune demande de duel en attente."
            end
            if Combat.Duels[req.from] or Combat.Duels[caller] then
                return false, "Un des joueurs est déjà en duel."
            end
            StartDuel(req.from, caller)
            return true
        end

        if lower == "cancel" then
            Combat.EndDuel(caller, "abandon")
            return true
        end

        local target, err = NRP.Util.FindPlayer(arg)
        if not target then return false, err end
        if target == caller or not target.NRPChar then return false, "Cible invalide." end
        if Combat.Duels[caller] then return false, "Vous êtes déjà en duel." end
        if caller:GetPos():DistToSqr(target:GetPos()) > Cfg().MaxDistance ^ 2 then
            return false, "Ce joueur est trop loin."
        end

        Combat.DuelRequests[target] = { from = caller, expires = CurTime() + Cfg().RequestTimeout }
        NRP.ChatPrint(target, Color(255, 120, 40), "[Duel] ", color_white,
            caller:Nick() .. " vous propose un duel. Tapez « !duel accept » pour accepter.")
        return true, "Demande de duel envoyée à " .. target:Nick()
    end,
})

hook.Add("PlayerDeath", "NRP.Duels.Death", function(ply)
    if Combat.Duels[ply] then
        Combat.EndDuel(ply, "K.O.")
    end
end)

hook.Add("PlayerDisconnected", "NRP.Duels.Cleanup", function(ply)
    Combat.EndDuel(ply, "déconnexion")
    Combat.DuelRequests[ply] = nil
end)
