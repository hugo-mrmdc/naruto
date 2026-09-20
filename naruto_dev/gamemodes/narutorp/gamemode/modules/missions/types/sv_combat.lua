--[[
    Types de mission de combat : eliminate, boss, escort, protect, defend
]]

local Missions = NRP.Missions

local function EnemyName(id)
    local def = NRP.Config.MissionEnemies[id]
    return def and def.name or id
end

---------------------------------------------------------------------------
-- Élimination : tuer tous les ennemis apparus au point
---------------------------------------------------------------------------
Missions.RegisterType("eliminate", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        local count = inst.params.count or 4

        for _ = 1, count do
            Missions.SpawnEnemy(inst, inst.params.enemy, Missions.FindGroundPos(point.pos, 400), "target")
        end

        inst.data.remaining = count
        inst.data.total = count
        Missions.SetWaypoints(inst, { { pos = point.pos, label = point.name } })
        Missions.SetObjective(inst, "Éliminez les ennemis : " .. EnemyName(inst.params.enemy), 0, count)
        return true
    end,

    OnNPCKilled = function(inst, npc)
        if npc.NRPRole ~= "target" then return end
        inst.data.remaining = inst.data.remaining - 1
        local done = inst.data.total - inst.data.remaining
        if inst.data.remaining <= 0 then
            Missions.Complete(inst)
        else
            Missions.SetObjective(inst, inst.objective, done, inst.data.total)
        end
    end,
})

---------------------------------------------------------------------------
-- Boss : tuer le chef (les gardes sont optionnels)
---------------------------------------------------------------------------
Missions.RegisterType("boss", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        local boss = Missions.SpawnEnemy(inst, inst.params.boss, Missions.FindGroundPos(point.pos, 100), "boss")
        if not IsValid(boss) then return false, "Impossible de créer le boss." end

        for _ = 1, inst.params.addCount or 0 do
            Missions.SpawnEnemy(inst, inst.params.adds, Missions.FindGroundPos(point.pos, 400), "add")
        end

        inst.data.boss = boss
        Missions.SetWaypoints(inst, { { pos = point.pos, label = EnemyName(inst.params.boss) } })
        Missions.SetObjective(inst, "Éliminez " .. EnemyName(inst.params.boss), 0, 1)
        return true
    end,

    OnNPCKilled = function(inst, npc)
        if npc.NRPRole == "boss" then
            Missions.Complete(inst)
        end
    end,
})

---------------------------------------------------------------------------
-- Escorte : le PNJ suit l'équipe jusqu'à destination
---------------------------------------------------------------------------
Missions.RegisterType("escort", {
    Start = function(inst)
        local dest = Missions.PickPoints(inst.params.point, 1)[1]
        local leader = inst.leader
        local vip = Missions.SpawnVIP(inst, Missions.FindGroundPos(leader:GetPos(), 120),
            inst.params.model, inst.params.health)
        if not IsValid(vip) then return false, "Impossible de créer le PNJ." end

        inst.data.vip = vip
        inst.data.dest = dest
        Missions.SetWaypoints(inst, { { pos = dest.pos, label = dest.name } })
        Missions.SetObjective(inst, "Escortez le marchand jusqu'à : " .. dest.name, 0, 1)
        return true
    end,

    Check = function(inst)
        local vip = inst.data.vip
        if not IsValid(vip) then
            return Missions.Fail(inst, "Le PNJ escorté a disparu")
        end

        local dest = inst.data.dest
        local radius = inst.params.radius or 200
        if vip:GetPos():DistToSqr(dest.pos) <= radius * radius then
            return Missions.Complete(inst)
        end

        -- Suit le membre le plus proche
        local best, bestDist
        for _, ply in ipairs(Missions.Members(inst)) do
            if ply:Alive() then
                local d = ply:GetPos():DistToSqr(vip:GetPos())
                if not bestDist or d < bestDist then best, bestDist = ply, d end
            end
        end
        if best and bestDist > 150 * 150 then
            vip:SetLastPosition(best:GetPos())
            vip:SetSchedule(bestDist > 600 * 600 and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO)
        end

        local ambush = inst.params.ambush
        if ambush and not inst.data.ambushed and CurTime() - inst.startTime >= (ambush.delay or 30) then
            inst.data.ambushed = true
            Missions.SpawnWave(inst, ambush.enemy, vip:GetPos(), ambush.count or 3, 700)
            for _, ply in ipairs(Missions.Members(inst)) do
                NRP.Notify(ply, "Embuscade ! Protégez le marchand !", NRP.NOTIFY_WARNING, 4)
            end
        end
    end,

    OnNPCKilled = function(inst, npc)
        if npc == inst.data.vip then
            Missions.Fail(inst, "Le marchand a été tué")
        end
    end,
})

---------------------------------------------------------------------------
-- Vagues communes à protect / defend
---------------------------------------------------------------------------
local function WaveTick(inst, center)
    local p = inst.params
    if CurTime() >= (inst.data.nextWave or 0) then
        inst.data.nextWave = CurTime() + (p.waveInterval or 30)
        Missions.SpawnWave(inst, p.enemy, center, p.waveSize or 3, 700)
    end
end

local function Survived(inst)
    return math.floor(CurTime() - inst.startTime)
end

---------------------------------------------------------------------------
-- Protection : garder un PNJ en vie pendant une durée
---------------------------------------------------------------------------
Missions.RegisterType("protect", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        local vip = Missions.SpawnVIP(inst, Missions.FindGroundPos(point.pos, 60), inst.params.model, inst.params.health)
        if not IsValid(vip) then return false, "Impossible de créer le PNJ." end

        inst.data.vip = vip
        inst.data.point = point
        inst.data.nextWave = CurTime() + 10
        Missions.SetWaypoints(inst, { { pos = point.pos, label = "Dignitaire" } })
        Missions.SetObjective(inst, "Protégez le dignitaire", 0, inst.params.duration or 120)
        return true
    end,

    Check = function(inst)
        if not IsValid(inst.data.vip) then
            return Missions.Fail(inst, "Le dignitaire a disparu")
        end
        if Survived(inst) >= (inst.params.duration or 120) then
            return Missions.Complete(inst)
        end
        WaveTick(inst, inst.data.vip:GetPos())
        if Survived(inst) % 5 == 0 then
            Missions.SetObjective(inst, inst.objective, Survived(inst), inst.params.duration or 120)
        end
    end,

    OnNPCKilled = function(inst, npc)
        if npc == inst.data.vip then
            Missions.Fail(inst, "Le dignitaire a été tué")
        end
    end,
})

---------------------------------------------------------------------------
-- Défense : tenir une zone pendant une durée
---------------------------------------------------------------------------
Missions.RegisterType("defend", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        inst.data.point = point
        inst.data.nextWave = CurTime() + 10
        inst.data.lastPresence = CurTime()
        Missions.SetWaypoints(inst, { { pos = point.pos, label = point.name } })
        Missions.SetObjective(inst, "Tenez la position : " .. point.name, 0, inst.params.duration or 180)
        return true
    end,

    Check = function(inst)
        local p = inst.params
        local point = inst.data.point

        if Missions.MemberNear(inst, point.pos, p.radius or 500) then
            inst.data.lastPresence = CurTime()
            inst.data.warned = false
        elseif CurTime() - inst.data.lastPresence > (p.grace or 15) then
            return Missions.Fail(inst, "La position a été abandonnée")
        elseif not inst.data.warned then
            inst.data.warned = true
            for _, ply in ipairs(Missions.Members(inst)) do
                NRP.Notify(ply, "Revenez défendre la zone !", NRP.NOTIFY_WARNING, 4)
            end
        end

        if Survived(inst) >= (p.duration or 180) then
            return Missions.Complete(inst)
        end
        WaveTick(inst, point.pos)
        if Survived(inst) % 5 == 0 then
            Missions.SetObjective(inst, inst.objective, Survived(inst), p.duration or 180)
        end
    end,
})
