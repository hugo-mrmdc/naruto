--[[
    Module : grades ninja (serveur)

    Les promotions ne dépendent pas du niveau seul :
        - admin (admin.rank)          : peut tout faire, y compris forcer
        - responsable RP (rp.promote) : promeut si le niveau minimum est atteint
        - grade avec promoteUpTo      : promeut dans son village, jusqu'à ce grade,
                                        des ninjas de grade inférieur au sien
    Les examens (sv_exams.lua) utilisent la même vérification.
]]

local Ranks = NRP.Ranks
local Char = NRP.Char

function Ranks.SetRank(ply, rankId, actor)
    local rank = Ranks.Get(rankId)
    if not rank or not ply.NRPChar then return false end

    local old = ply.NRPChar.rank
    if old == rankId then return true end

    Char.Set(ply, "rank", rankId)
    hook.Run("NRP.RankChanged", ply, rankId, old, actor)

    local promoted = Ranks.GetOrder(rankId) > Ranks.GetOrder(old)
    NRP.Announce(promoted and "Promotion !" or "Changement de grade",
        "Vous êtes désormais " .. rank.name, rank.color, 5, ply)

    if promoted then
        NRP.ChatPrint(nil, rank.color or color_white, "[Grade] ", color_white,
            ply:Nick() .. " a été promu " .. rank.name .. ".")
    end

    NRP.LogAction("rank", actor, ply, (old or "?") .. " -> " .. rankId)
    return true
end

-- Retourne true ou false, raison
function Ranks.CanPromote(actor, target, rankId)
    local rank = Ranks.Get(rankId)
    if not rank then return false, "Grade inconnu." end
    if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
    if actor == target then return false, "Vous ne pouvez pas vous promouvoir vous-même." end

    if NRP.Perm.Has(actor, "admin.rank") then
        return true
    end

    if (target.NRPChar.level or 1) < (rank.minLevel or 1) then
        return false, "Niveau " .. rank.minLevel .. " requis pour " .. rank.name .. "."
    end

    if NRP.Perm.Has(actor, "rp.promote") then
        return true
    end

    if actor == NULL or not actor.NRPChar then
        return false, "Permission insuffisante."
    end

    local actorRank = Ranks.Get(actor.NRPChar.rank)
    if not actorRank or not actorRank.promoteUpTo then
        return false, "Votre grade ne permet pas de promouvoir."
    end
    if rank.special then
        return false, "Ce grade spécial est attribué par l'administration."
    end
    if Char.GetVillage(actor) ~= Char.GetVillage(target) or Char.IsDeserter(target) then
        return false, "Ce ninja n'appartient pas à votre village."
    end
    if Ranks.GetOrder(rankId) > Ranks.GetOrder(actorRank.promoteUpTo) then
        return false, "Vous pouvez promouvoir au maximum au grade " .. Ranks.GetName(actorRank.promoteUpTo) .. "."
    end
    if Ranks.GetOrder(target.NRPChar.rank) >= Ranks.GetOrder(actor.NRPChar.rank) then
        return false, "Ce ninja a un grade égal ou supérieur au vôtre."
    end

    return true
end

NRP.Commands.Add("setrank", {
    perm = "admin.rank", usage = "setrank <joueur> <grade>", description = "Définir le grade (forcé)",
    args = { "player", "string" },
    run = function(caller, target, rankId)
        if not Ranks.Get(rankId) then return false, "Grade inconnu. Voir !ranks" end
        if not target.NRPChar then return false, "Ce joueur n'a pas de personnage." end
        Ranks.SetRank(target, rankId, caller)
        return true, target:Nick() .. " -> " .. Ranks.GetName(rankId)
    end,
})

NRP.Commands.Add("promote", {
    needChar = false, usage = "promote <joueur> <grade>", description = "Promouvoir un ninja (responsables RP / hauts gradés)",
    args = { "player", "string" },
    run = function(caller, target, rankId)
        local ok, reason = Ranks.CanPromote(caller, target, rankId)
        if not ok then return false, reason end
        Ranks.SetRank(target, rankId, caller)
        return true, target:Nick() .. " est maintenant " .. Ranks.GetName(rankId)
    end,
})

NRP.Commands.Add("ranks", {
    description = "Liste des grades",
    run = function(caller)
        local parts = {}
        for _, rank in ipairs(Ranks.Sorted()) do
            parts[#parts + 1] = rank.id .. " (" .. rank.name .. (rank.special and ", spécial" or "") .. ")"
        end
        return true, table.concat(parts, ", ")
    end,
})
