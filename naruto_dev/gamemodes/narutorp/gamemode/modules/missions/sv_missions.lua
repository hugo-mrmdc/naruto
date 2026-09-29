--[[
    Module : missions (serveur) - cycle de vie des instances, points, groupes, tableaux

    Instance :
        { uid, id, def, params, state = "forming" | "active", leader, members = { [ply] = true },
          village, giver, startTime, endTime, data = {}, entities = {},
          objective, progress = { cur, max }, waypoints = { { pos = Vector, label = "" } } }

    Aides pour les types :
        Missions.SetObjective(inst, texte, cur, max)
        Missions.SetWaypoints(inst, { { pos = , label = } })
        Missions.Complete(inst) / Missions.Fail(inst, raison)
        Missions.PickPoints(tag, n) / Missions.FindGroundPos(centre, rayon)
        Missions.Track(inst, ent)         -- supprimé à la fin de la mission
        Missions.MemberNear(inst, pos, rayon)
        Missions.SpawnEnemy(inst, enemyId, pos, role)   (sv_enemies.lua)

    Un seul timer global vérifie les missions actives, et seulement s'il y en a.
]]

local Missions = NRP.Missions
local Char = NRP.Char
local DB = NRP.DB

Missions.Active = Missions.Active or {}
Missions.Points = Missions.Points or {}
local nextUid = 0
local invites = {}

NRP.Net.Pool("MissionBoard")
NRP.Net.Pool("MissionState")
NRP.Net.Pool("MissionInvitePrompt")

local function Settings()
    return NRP.Config.MissionSettings
end

---------------------------------------------------------------------------
-- Points de mission (par carte)
---------------------------------------------------------------------------

DB.RegisterTable("mission_points", {
    columns = {
        { "id", "id" },
        { "map", "string", "" },
        { "tag", "string", "" },
        { "name", "string", "" },
        { "x", "float", 0 }, { "y", "float", 0 }, { "z", "float", 0 },
    },
    primary = { "id" },
    indexes = { { "map" } },
})

function Missions.LoadPoints()
    DB.Select("mission_points", { map = game.GetMap() }, function(rows)
        Missions.Points = {}
        for _, row in ipairs(rows) do
            local list = Missions.Points[row.tag] or {}
            list[#list + 1] = {
                id = tonumber(row.id),
                name = row.name ~= "" and row.name or row.tag,
                pos = Vector(tonumber(row.x), tonumber(row.y), tonumber(row.z)),
            }
            Missions.Points[row.tag] = list
        end
        NRP.Print("Missions : " .. #rows .. " point(s) chargé(s) pour " .. game.GetMap())
    end)
end

hook.Add("NRP.DatabaseReady", "NRP.Missions.Points", Missions.LoadPoints)

function Missions.AddPoint(tag, name, pos, callback)
    DB.Insert("mission_points", { map = game.GetMap(), tag = tag, name = name or "", x = pos.x, y = pos.y, z = pos.z },
        function(_, id)
            Missions.LoadPoints()
            if callback then callback(id) end
        end)
end

function Missions.RemovePoint(id, callback)
    DB.Delete("mission_points", { id = id, map = game.GetMap() }, function()
        Missions.LoadPoints()
        if callback then callback() end
    end)
end

function Missions.PickPoints(tag, count)
    local list = Missions.Points[tag]
    if not list or #list == 0 then return nil end

    local pool = table.Copy(list)
    local out = {}
    for _ = 1, math.min(count or 1, #pool) do
        out[#out + 1] = table.remove(pool, math.random(#pool))
    end
    return out
end

function Missions.FindGroundPos(center, radius)
    for _ = 1, 10 do
        local ang = math.Rand(0, math.pi * 2)
        local dist = math.Rand(radius * 0.3, radius)
        local pos = center + Vector(math.cos(ang) * dist, math.sin(ang) * dist, 0)
        local tr = util.TraceLine({ start = pos + Vector(0, 0, 80), endpos = pos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit and not tr.StartSolid then
            local hull = util.TraceHull({
                start = tr.HitPos + Vector(0, 0, 4), endpos = tr.HitPos + Vector(0, 0, 4),
                mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72), mask = MASK_NPCSOLID,
            })
            if not hull.Hit then
                return tr.HitPos + Vector(0, 0, 4)
            end
        end
    end
    return center + Vector(0, 0, 8)
end

-- Tous les points requis par la mission existent-ils sur la carte ?
function Missions.HasPoints(def)
    local tag = def.params.point
    if not tag then return true end
    local needed = def.type == "recon" and (def.params.count or 1) or 1
    local list = Missions.Points[tag]
    return list ~= nil and #list >= needed
end

---------------------------------------------------------------------------
-- Aides d'instance
---------------------------------------------------------------------------

function Missions.GetInstance(ply)
    local inst = ply.NRPMission
    if inst and Missions.Active[inst.uid] == inst then
        return inst
    end
    ply.NRPMission = nil
end

function Missions.Members(inst)
    local out = {}
    for ply in pairs(inst.members) do
        if IsValid(ply) then out[#out + 1] = ply end
    end
    return out
end

function Missions.MemberNear(inst, pos, radius)
    local r2 = radius * radius
    for ply in pairs(inst.members) do
        if IsValid(ply) and ply:Alive() and ply:GetPos():DistToSqr(pos) <= r2 then
            return ply
        end
    end
end

function Missions.Track(inst, ent)
    ent.NRPMission = inst
    inst.entities[#inst.entities + 1] = ent
    return ent
end

function Missions.Sync(inst)
    if inst.syncPending then return end
    inst.syncPending = true
    timer.Simple(0, function()
        inst.syncPending = false
        if Missions.Active[inst.uid] ~= inst then return end

        local names = {}
        for _, ply in ipairs(Missions.Members(inst)) do
            names[#names + 1] = ply:Nick()
        end

        local payload = {
            uid = inst.uid,
            id = inst.id,
            state = inst.state,
            objective = inst.objective,
            cur = inst.progress[1],
            max = inst.progress[2],
            endTime = inst.endTime,
            waypoints = inst.waypoints,
            members = names,
            leader = IsValid(inst.leader) and inst.leader:Nick() or "",
        }

        for _, ply in ipairs(Missions.Members(inst)) do
            NRP.Net.Start("MissionState")
                net.WriteBool(true)
                NRP.Net.WriteTable(payload)
                net.WriteBool(ply == inst.leader)
            net.Send(ply)
        end
    end)
end

local function SendEnded(ply)
    NRP.Net.Start("MissionState")
        net.WriteBool(false)
    net.Send(ply)
end

function Missions.SetObjective(inst, text, cur, max)
    inst.objective = text
    inst.progress = { cur or 0, max or 0 }
    Missions.Sync(inst)
end

function Missions.SetWaypoints(inst, list)
    inst.waypoints = list or {}
    Missions.Sync(inst)
end

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------

local TICK_TIMER = "NRP.Missions.Tick"

local function Cleanup(inst)
    Missions.Active[inst.uid] = nil

    local mtype = Missions.Types[inst.def.type]
    if mtype.Cleanup then
        pcall(mtype.Cleanup, inst)
    end

    for _, ent in ipairs(inst.entities) do
        if IsValid(ent) then ent:Remove() end
    end

    for ply in pairs(inst.members) do
        if IsValid(ply) then
            if ply.NRPMission == inst then ply.NRPMission = nil end
            NRP.Inventory.RemoveMissionItems(ply, inst.params.item)
            SendEnded(ply)
        end
    end

    if next(Missions.Active) == nil then
        timer.Remove(TICK_TIMER)
    end
end

local function SetCooldown(ply, def, seconds)
    local data = ply.NRPChar
    if not data then return end
    data.missionData.cooldowns[def.id] = os.time() + seconds
    Char.Touch(ply, "missionData")
end

function Missions.GiveRewards(ply, inst)
    local r = inst.def.rewards
    local ryoMult = NRP.Events and NRP.Events.GetMultiplier("ryo") or 1

    if r.xp then NRP.Progression.AddXP(ply, r.xp, "mission") end
    if r.ryo then Char.AddRyo(ply, math.floor(r.ryo * ryoMult), "mission") end
    if r.reputation and NRP.Villages.AddReputation then
        NRP.Villages.AddReputation(ply, inst.village, r.reputation)
    end
    for id, qty in pairs(r.items or {}) do
        NRP.Inventory.Give(ply, id, qty)
    end
    if r.statPoints then NRP.Progression.AddStatPoints(ply, r.statPoints) end
    if r.custom then pcall(r.custom, ply, inst) end
end

function Missions.Complete(inst)
    if Missions.Active[inst.uid] ~= inst then return end
    local def = inst.def
    local rank = Missions.GetRank(def.rank)

    for _, ply in ipairs(Missions.Members(inst)) do
        if ply.NRPChar then
            Missions.GiveRewards(ply, inst)
            SetCooldown(ply, def, def.cooldown)

            local data = ply.NRPChar.missionData
            data.completed[def.rank] = (tonumber(data.completed[def.rank]) or 0) + 1
            Char.Touch(ply, "missionData")

            NRP.Announce("Mission accomplie", def.name, rank.color, 5, ply)
        end
    end

    NRP.LogAction("mission", inst.leader, inst.leader, "réussite " .. def.id .. " (" .. table.Count(inst.members) .. " membre(s))")
    hook.Run("NRP.MissionCompleted", inst)
    Cleanup(inst)
end

function Missions.Fail(inst, reason)
    if Missions.Active[inst.uid] ~= inst then return end

    for _, ply in ipairs(Missions.Members(inst)) do
        if inst.state == "active" then
            SetCooldown(ply, inst.def, math.floor(inst.def.cooldown / 2))
        end
        NRP.Announce("Mission échouée", reason or inst.def.name, Color(230, 70, 70), 5, ply)
    end

    hook.Run("NRP.MissionFailed", inst, reason)
    Cleanup(inst)
end

local function Tick()
    local now = CurTime()
    for _, inst in pairs(Missions.Active) do
        if inst.state == "forming" then
            if now > inst.formingExpires then
                Missions.Fail(inst, "Groupe incomplet")
            end
        elseif now > inst.endTime then
            Missions.Fail(inst, "Temps écoulé")
        else
            local mtype = Missions.Types[inst.def.type]
            if mtype.Check then
                local ok, err = pcall(mtype.Check, inst)
                if not ok then
                    NRP.Error("Mission " .. inst.id .. " :", err)
                    Missions.Fail(inst, "Erreur interne")
                end
            end
        end
    end
end

function Missions.Begin(inst)
    local mtype = Missions.Types[inst.def.type]
    inst.state = "active"
    inst.startTime = CurTime()
    inst.endTime = CurTime() + inst.def.timeLimit

    local ok, success, err = pcall(mtype.Start, inst)
    if not ok or success == false then
        if not ok then NRP.Error("Mission " .. inst.id .. " :", success) end
        Missions.Fail(inst, err or "Impossible de démarrer la mission")
        return false
    end

    for _, ply in ipairs(Missions.Members(inst)) do
        NRP.Announce(Missions.GetRank(inst.def.rank).name, inst.def.name, Missions.GetRank(inst.def.rank).color, 4, ply)
    end
    Missions.Sync(inst)
    hook.Run("NRP.MissionStarted", inst)
    return true
end

-- Crée une instance. opts : { giver, force }
function Missions.Start(leader, missionId, opts)
    opts = opts or {}
    local def = Missions.Registry:Get(missionId)
    if not def then return false, "Mission inconnue." end
    if not leader.NRPChar then return false, "Aucun personnage." end
    if Missions.GetInstance(leader) then return false, "Vous êtes déjà en mission." end
    if not Missions.HasPoints(def) then return false, "Cette mission n'est pas configurée sur cette carte." end

    if not opts.force then
        local giverVillage = IsValid(opts.giver) and opts.giver:GetVillage() or ""
        local ok, reason = Missions.CheckAvailability(leader.NRPChar, def, giverVillage)
        if not ok then return false, reason end
    end

    local mtype = Missions.Types[def.type]
    if not mtype.Start then return false, "Type de mission non implémenté." end

    nextUid = nextUid + 1
    local inst = {
        uid = nextUid,
        id = missionId,
        def = def,
        params = def.params,
        leader = leader,
        members = { [leader] = true },
        village = NRP.Char.GetVillage(leader),
        giver = opts.giver,
        data = {},
        entities = {},
        objective = "",
        progress = { 0, 0 },
        waypoints = {},
    }

    Missions.Active[inst.uid] = inst
    leader.NRPMission = inst
    if not timer.Exists(TICK_TIMER) then
        timer.Create(TICK_TIMER, Settings().CheckInterval, 0, Tick)
    end

    if def.party[1] > 1 and not opts.force then
        inst.state = "forming"
        inst.formingExpires = CurTime() + 180
        inst.endTime = inst.formingExpires
        Missions.SetObjective(inst, string.format("Formez une équipe (%d membres minimum) puis lancez la mission.", def.party[1]), 1, def.party[1])
        return true
    end

    return Missions.Begin(inst)
end

function Missions.Leave(ply, reason)
    local inst = Missions.GetInstance(ply)
    if not inst then return end

    inst.members[ply] = nil
    ply.NRPMission = nil
    NRP.Inventory.RemoveMissionItems(ply, inst.params.item)
    SendEnded(ply)

    if inst.state == "active" and ply.NRPChar then
        SetCooldown(ply, inst.def, Settings().AbandonCooldown)
    end

    local remaining = Missions.Members(inst)
    if #remaining == 0 then
        Missions.Fail(inst, reason or "Mission abandonnée")
        return
    end

    if inst.leader == ply then
        if Settings().LeaderDisconnectFail and reason == "déconnexion" then
            Missions.Fail(inst, "Le chef d'équipe est parti")
            return
        end
        inst.leader = remaining[1]
        NRP.Notify(inst.leader, "Vous êtes maintenant chef d'équipe.", NRP.NOTIFY_INFO)
    end
    Missions.Sync(inst)
end

function Missions.AddMember(inst, ply)
    if table.Count(inst.members) >= inst.def.party[2] then return false, "L'équipe est complète." end
    if Missions.GetInstance(ply) then return false, "Ce joueur est déjà en mission." end
    local ok, reason = Missions.CheckAvailability(ply.NRPChar, inst.def, "")
    if not ok then return false, reason end
    if NRP.Char.GetVillage(ply) ~= inst.village then return false, "Ce joueur n'est pas de votre village." end

    inst.members[ply] = true
    ply.NRPMission = inst

    local mtype = Missions.Types[inst.def.type]
    if inst.state == "active" and mtype.OnJoin then
        mtype.OnJoin(inst, ply)
    end

    if inst.state == "forming" then
        inst.progress[1] = table.Count(inst.members)
    end
    hook.Run("NRP.MissionMemberJoined", inst, ply)
    Missions.Sync(inst)
    return true
end

---------------------------------------------------------------------------
-- Tableau de missions
---------------------------------------------------------------------------

function Missions.OpenBoard(ply, npc)
    local data = ply.NRPChar
    if not data then return end

    local list = {}
    for id, def in Missions.Registry:Iterate() do
        local ok, reason = Missions.CheckAvailability(data, def, npc:GetVillage())
        local hideForeign = not ok and (reason == "Réservée à un autre village" or reason == "Indisponible pour votre village"
            or reason == "Les déserteurs n'ont pas accès à cette mission")
        if ok and not Missions.HasPoints(def) then
            ok, reason = false, "Non configurée sur cette carte"
        end
        if not hideForeign then
            list[#list + 1] = { id = id, ok = ok, reason = reason or "" }
        end
    end

    NRP.Net.Start("MissionBoard")
        net.WriteEntity(npc)
        NRP.Net.WriteTable(list)
    net.Send(ply)
end

-- Appelé par nrp_mission_npc
function Missions.OnNPCUse(ply, npc)
    local inst = Missions.GetInstance(ply)
    if inst then
        local mtype = Missions.Types[inst.def.type]
        if inst.state == "active" and mtype.OnTurnIn and mtype.OnTurnIn(inst, ply, npc) then
            return
        end
    end
    Missions.OpenBoard(ply, npc)
end

-- Appelé par nrp_mission_item
function Missions.OnItemUsed(ply, ent)
    local inst = ent.NRPMission
    if not inst or Missions.Active[inst.uid] ~= inst then return end
    if not inst.members[ply] then
        NRP.Notify(ply, "Cet objet concerne la mission d'une autre équipe.", NRP.NOTIFY_ERROR, 2)
        return
    end
    local mtype = Missions.Types[inst.def.type]
    if mtype.OnItemUsed then
        mtype.OnItemUsed(inst, ply, ent)
    end
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------

NRP.Net.Receive("MissionAccept", function(ply)
    local npc = net.ReadEntity()
    local id = NRP.Net.ReadId()
    if not id or not IsValid(npc) or npc:GetClass() ~= "nrp_mission_npc" then return end
    if ply:GetPos():DistToSqr(npc:GetPos()) > (Settings().NPCUseDistance * 1.5) ^ 2 then
        return NRP.Notify(ply, "Vous êtes trop loin du donneur de mission.", NRP.NOTIFY_ERROR)
    end

    local ok, err = Missions.Start(ply, id, { giver = npc })
    if not ok and err then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR)
    end
end, { rate = 1, burst = 3, maxBytes = 96, alive = true })

NRP.Net.Receive("MissionAbandon", function(ply)
    Missions.Leave(ply, "Mission abandonnée")
end, { rate = 1, burst = 2, maxBytes = 8 })

NRP.Net.Receive("MissionBegin", function(ply)
    local inst = Missions.GetInstance(ply)
    if not inst or inst.leader ~= ply or inst.state ~= "forming" then return end
    if table.Count(inst.members) < inst.def.party[1] then
        return NRP.Notify(ply, "Il faut au moins " .. inst.def.party[1] .. " membres.", NRP.NOTIFY_ERROR)
    end
    Missions.Begin(inst)
end, { rate = 1, burst = 2, maxBytes = 8 })

NRP.Net.Receive("MissionInvite", function(ply)
    local target = net.ReadEntity()
    local inst = Missions.GetInstance(ply)
    if not inst or inst.leader ~= ply then return end
    if not IsValid(target) or not target:IsPlayer() or target == ply or not target.NRPChar then return end
    if Missions.GetInstance(target) then
        return NRP.Notify(ply, "Ce joueur est déjà en mission.", NRP.NOTIFY_ERROR)
    end

    invites[target] = { inst = inst, from = ply, expires = CurTime() + Settings().InviteTimeout }
    NRP.Net.Start("MissionInvitePrompt")
        net.WriteEntity(ply)
        net.WriteString(inst.id)
    net.Send(target)
    NRP.Notify(ply, "Invitation envoyée à " .. target:Nick(), NRP.NOTIFY_INFO)
end, { rate = 1, burst = 4, maxBytes = 16 })

NRP.Net.Receive("MissionInviteReply", function(ply)
    local accept = net.ReadBool()
    local invite = invites[ply]
    invites[ply] = nil
    if not invite or invite.expires < CurTime() then return end
    if Missions.Active[invite.inst.uid] ~= invite.inst then return end

    if not accept then
        if IsValid(invite.from) then
            NRP.Notify(invite.from, ply:Nick() .. " a décliné l'invitation.", NRP.NOTIFY_WARNING)
        end
        return
    end

    local ok, err = Missions.AddMember(invite.inst, ply)
    if not ok then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR)
    end
end, { rate = 1, burst = 2, maxBytes = 8 })

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

hook.Add("OnNPCKilled", "NRP.Missions.NPCKilled", function(npc, attacker)
    local inst = npc.NRPMission
    if not inst or Missions.Active[inst.uid] ~= inst then return end
    local mtype = Missions.Types[inst.def.type]
    if mtype.OnNPCKilled then
        mtype.OnNPCKilled(inst, npc, attacker)
    end
end)

hook.Add("PlayerDeath", "NRP.Missions.Death", function(ply)
    local inst = Missions.GetInstance(ply)
    if not inst or inst.state ~= "active" or not Settings().FailOnAllDead then return end

    for member in pairs(inst.members) do
        if IsValid(member) and member:Alive() then return end
    end
    Missions.Fail(inst, "Toute l'équipe est tombée")
end)

hook.Add("PlayerDisconnected", "NRP.Missions.Disconnect", function(ply)
    Missions.Leave(ply, "déconnexion")
    invites[ply] = nil
end)

hook.Add("NRP.CharacterUnloaded", "NRP.Missions.Unload", function(ply)
    Missions.Leave(ply, "Personnage supprimé")
end)

hook.Add("NRP.CharacterLoaded", "NRP.Missions.Sanitize", function(ply, data)
    local md = data.missionData
    md.cooldowns = istable(md.cooldowns) and md.cooldowns or {}
    md.completed = istable(md.completed) and md.completed or {}
    local now = os.time()
    for id, t in pairs(md.cooldowns) do
        if (tonumber(t) or 0) < now then md.cooldowns[id] = nil end
    end
end)

hook.Add("NRP.ShutDown", "NRP.Missions.Cleanup", function()
    for _, inst in pairs(Missions.Active) do
        Cleanup(inst)
    end
end)
