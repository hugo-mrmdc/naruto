--[[
    Module : examens de promotion (serveur)

        !exam open <grade> [places]   (examinateur : rp.exam)
        !exam join <examinateur>      (candidat)
        !exam list
        !exam pass <joueur> / !exam fail <joueur>
        !exam close

    Un examen réussi appelle NRP.Ranks.SetRank ; l'examinateur doit pouvoir accorder ce grade
    (voir NRP.Ranks.CanPromote).
]]

NRP.Exams = NRP.Exams or {}
local Exams = NRP.Exams
local Ranks = NRP.Ranks

Exams.Sessions = Exams.Sessions or {}

local function Cfg()
    return NRP.Config.Exams
end

local function SessionOf(examiner)
    local s = Exams.Sessions[examiner]
    if s and s.expires < CurTime() then
        Exams.Sessions[examiner] = nil
        return nil
    end
    return s
end

function Exams.Open(examiner, rankId, places)
    local rank = Ranks.Get(rankId)
    if not rank then return false, "Grade inconnu." end
    if SessionOf(examiner) then return false, "Vous avez déjà un examen ouvert (!exam close)." end

    -- L'examinateur doit pouvoir accorder ce grade à un candidat standard
    if not NRP.Perm.Has(examiner, "rp.promote") and not NRP.Perm.Has(examiner, "admin.rank") then
        local own = examiner.NRPChar and Ranks.Get(examiner.NRPChar.rank)
        if not own or not own.promoteUpTo or Ranks.GetOrder(rankId) > Ranks.GetOrder(own.promoteUpTo) then
            return false, "Vous ne pouvez pas organiser un examen pour ce grade."
        end
    end

    Exams.Sessions[examiner] = {
        examiner = examiner,
        rank = rankId,
        village = NRP.Char.GetVillage(examiner),
        places = math.Clamp(places or Cfg().MaxCandidates, 1, Cfg().MaxCandidates),
        candidates = {},
        expires = CurTime() + Cfg().Timeout,
    }

    local village = NRP.Villages:Get(NRP.Char.GetVillage(examiner))
    NRP.ChatPrint(nil, rank.color or color_white, "[Examen] ", color_white,
        string.format("%s organise l'examen de %s%s. Tapez « !exam join %s » pour participer.",
            examiner:Nick(), rank.name, village and (" (" .. village.name .. ")") or "", examiner:Nick()))
    return true, "Examen ouvert."
end

function Exams.Join(candidate, examiner)
    local s = SessionOf(examiner)
    if not s then return false, "Aucun examen ouvert par ce joueur." end
    if s.candidates[candidate] then return false, "Vous êtes déjà inscrit." end
    if table.Count(s.candidates) >= s.places then return false, "L'examen est complet." end
    if not candidate.NRPChar then return false, "Vous n'avez pas de personnage." end

    local rank = Ranks.Get(s.rank)
    if s.village ~= "" and NRP.Char.GetVillage(candidate) ~= s.village then
        return false, "Cet examen est réservé à un autre village."
    end
    if Ranks.GetOrder(candidate.NRPChar.rank) >= Ranks.GetOrder(s.rank) then
        return false, "Vous avez déjà ce grade ou un grade supérieur."
    end
    if candidate.NRPChar.level < (rank.minLevel or 1) then
        return false, "Niveau " .. rank.minLevel .. " requis."
    end

    s.candidates[candidate] = true
    NRP.Notify(examiner, candidate:Nick() .. " s'est inscrit à l'examen.", NRP.NOTIFY_INFO)
    return true, "Inscription à l'examen de " .. rank.name .. " confirmée."
end

function Exams.Resolve(examiner, candidate, passed)
    local s = SessionOf(examiner)
    if not s then return false, "Aucun examen ouvert." end
    if not s.candidates[candidate] then return false, "Ce joueur n'est pas candidat." end

    s.candidates[candidate] = nil
    if passed then
        Ranks.SetRank(candidate, s.rank, examiner)
        NRP.Progression.AddXP(candidate, Cfg().XPReward or 0, "exam")
        return true, candidate:Nick() .. " a réussi l'examen."
    end

    NRP.Notify(candidate, "Vous avez échoué à l'examen. Entraînez-vous et retentez votre chance !", NRP.NOTIFY_WARNING, 6)
    return true, candidate:Nick() .. " a échoué."
end

NRP.Commands.Add("exam", {
    needChar = true, usage = "exam <open|join|list|pass|fail|close> [...]", description = "Examens de promotion",
    args = { "string", "string?", "string?" },
    run = function(caller, action, arg1, arg2)
        action = string.lower(action)

        if action == "join" then
            local examiner, err = NRP.Util.FindPlayer(arg1)
            if not examiner then return false, err end
            return Exams.Join(caller, examiner)
        end

        if not NRP.Perm.Has(caller, "rp.exam") then
            return false, "Vous ne pouvez pas organiser d'examen."
        end

        if action == "open" then
            return Exams.Open(caller, arg1 or "", tonumber(arg2))
        elseif action == "close" then
            if not SessionOf(caller) then return false, "Aucun examen ouvert." end
            Exams.Sessions[caller] = nil
            return true, "Examen clôturé."
        elseif action == "list" then
            local s = SessionOf(caller)
            if not s then return false, "Aucun examen ouvert." end
            local names = {}
            for ply in pairs(s.candidates) do
                if IsValid(ply) then names[#names + 1] = ply:Nick() end
            end
            return true, #names .. " candidat(s) : " .. table.concat(names, ", ")
        elseif action == "pass" or action == "fail" then
            local target, err = NRP.Util.FindPlayer(arg1)
            if not target then return false, err end
            return Exams.Resolve(caller, target, action == "pass")
        end

        return false, "Action inconnue."
    end,
})

hook.Add("PlayerDisconnected", "NRP.Exams.Cleanup", function(ply)
    Exams.Sessions[ply] = nil
    for _, s in pairs(Exams.Sessions) do
        s.candidates[ply] = nil
    end
end)
