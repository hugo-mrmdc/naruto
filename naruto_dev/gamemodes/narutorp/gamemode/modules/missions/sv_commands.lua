--[[
    Module : missions - commandes
        Joueurs : !mission invite <joueur> | leave | start
        Admin   : !mpoint add|list|remove|near, !missionnpc <village>,
                  !startmission <joueur> <mission>, !endmission <joueur> [1|0]
]]

local Missions = NRP.Missions

NRP.Commands.Add("mission", {
    needChar = true, usage = "mission <invite|leave|start> [joueur]", description = "Gestion de votre mission",
    args = { "string", "string?" },
    run = function(caller, action, arg)
        action = string.lower(action)
        local inst = Missions.GetInstance(caller)
        if not inst then return false, "Vous n'êtes pas en mission." end

        if action == "leave" then
            Missions.Leave(caller, "Mission abandonnée")
            return true, "Vous avez quitté la mission."
        end

        if inst.leader ~= caller then return false, "Seul le chef d'équipe peut faire cela." end

        if action == "start" then
            if inst.state ~= "forming" then return false, "La mission a déjà commencé." end
            if table.Count(inst.members) < inst.def.party[1] then
                return false, "Il faut au moins " .. inst.def.party[1] .. " membres."
            end
            Missions.Begin(inst)
            return true
        elseif action == "invite" then
            local target, err = NRP.Util.FindPlayer(arg)
            if not target then return false, err end
            local ok, reason = Missions.AddMember(inst, target)
            if not ok then return false, reason end
            NRP.Notify(target, caller:Nick() .. " vous a ajouté à sa mission.", NRP.NOTIFY_INFO)
            return true, target:Nick() .. " a rejoint l'équipe."
        end
        return false, "Action inconnue."
    end,
})

NRP.Commands.Add("mpoint", {
    perm = "admin.world", usage = "mpoint <add|list|remove|near> [tag|id] [nom]", description = "Points de mission de la carte",
    args = { "string", "string?", "text?" },
    run = function(caller, action, arg, name)
        action = string.lower(action)

        if action == "add" then
            if caller == NULL then return false, "Commande en jeu uniquement." end
            if not arg or not NRP.Util.IsValidId(arg) then return false, "Tag invalide (lettres, chiffres, _)." end
            Missions.AddPoint(arg, name, caller:GetPos(), function(id)
                if IsValid(caller) then
                    NRP.Notify(caller, "Point #" .. tostring(id) .. " ajouté (" .. arg .. ")", NRP.NOTIFY_SUCCESS)
                end
            end)
            NRP.LogAction("world", caller, nil, "point de mission " .. arg)
            return true
        elseif action == "remove" then
            local id = tonumber(arg)
            if not id then return false, "Identifiant attendu." end
            Missions.RemovePoint(id)
            return true, "Point #" .. id .. " supprimé."
        elseif action == "list" or action == "near" then
            local lines = {}
            local origin = caller ~= NULL and caller:GetPos()
            for tag, list in SortedPairs(Missions.Points) do
                if action == "near" or not arg or arg == tag then
                    for _, point in ipairs(list) do
                        local dist = origin and math.floor(origin:Distance(point.pos)) or 0
                        if action == "list" or dist < 1500 then
                            lines[#lines + 1] = string.format("#%d [%s] %s (%d u)", point.id, tag, point.name, dist)
                        end
                    end
                end
            end
            for _, line in ipairs(lines) do
                if caller == NULL then NRP.Print(line) else caller:PrintMessage(HUD_PRINTCONSOLE, line) end
            end
            return true, #lines .. " point(s) (voir console)"
        end
        return false, "Action inconnue."
    end,
})

NRP.Commands.Add("missionnpc", {
    perm = "admin.world", usage = "missionnpc <village|all>", description = "Placer un donneur de mission à l'endroit visé",
    args = { "string" },
    run = function(caller, village)
        if caller == NULL then return false, "Commande en jeu uniquement." end
        if village == "all" then village = "" end
        if village ~= "" and not NRP.Villages:Exists(village) then return false, "Village inconnu." end

        local tr = caller:GetEyeTrace()
        local ent = NRP.World.SpawnPersistent("nrp_mission_npc", tr.HitPos, Angle(0, caller:EyeAngles().y + 180, 0), { village = village })
        if not IsValid(ent) then return false, "Échec de la création." end
        return true, "Donneur de mission placé (" .. (village ~= "" and village or "tous villages") .. ")."
    end,
})

NRP.Commands.Add("startmission", {
    perm = "admin.mission", usage = "startmission <joueur> <mission>", description = "Lancer une mission pour un joueur",
    args = { "player", "string" },
    run = function(caller, target, id)
        local ok, err = Missions.Start(target, id, { force = true })
        if not ok then return false, err or "Échec du lancement." end
        NRP.LogAction("admin", caller, target, "mission lancée " .. id)
        return true, "Mission " .. id .. " lancée pour " .. target:Nick()
    end,
})

NRP.Commands.Add("endmission", {
    perm = "admin.mission", usage = "endmission <joueur> [1=réussite]", description = "Terminer la mission d'un joueur",
    args = { "player", "number?" },
    run = function(caller, target, success)
        local inst = Missions.GetInstance(target)
        if not inst then return false, "Ce joueur n'est pas en mission." end
        if success == 1 then
            Missions.Complete(inst)
        else
            Missions.Fail(inst, "Interrompue par un administrateur")
        end
        NRP.LogAction("admin", caller, target, "fin de mission " .. inst.id)
        return true
    end,
})

NRP.Commands.Add("missionlist", {
    perm = "admin.mission", description = "Identifiants des missions (console)",
    run = function(caller)
        for id, def in Missions.Registry:Iterate() do
            local line = string.format("%s - %s [%s, %s]%s", id, def.name, def.rank, def.type,
                Missions.HasPoints(def) and "" or " (points manquants : " .. tostring(def.params.point) .. ")")
            if caller == NULL then NRP.Print(line) else caller:PrintMessage(HUD_PRINTCONSOLE, line) end
        end
        return true, Missions.Registry:Count() .. " missions (voir console)"
    end,
})
