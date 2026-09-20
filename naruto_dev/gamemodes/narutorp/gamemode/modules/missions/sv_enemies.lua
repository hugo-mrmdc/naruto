--[[
    Module : missions - PNJ (ennemis et personnages à protéger)

    Les ennemis sont neutres envers tout le monde sauf les membres de la mission,
    ce qui évite qu'ils attaquent les passants. Leurs dégâts sont réduits par
    NRPDamageScale (voir le filtre EntityTakeDamage du module combat).
]]

local Missions = NRP.Missions

local function HateMembers(npc, inst)
    for ply in pairs(inst.members) do
        if IsValid(ply) then
            npc:AddEntityRelationship(ply, D_HT, 99)
        end
    end
end

function Missions.SpawnEnemy(inst, enemyId, pos, role)
    local def = NRP.Config.MissionEnemies[enemyId]
    if not def then
        NRP.Error("Ennemi de mission inconnu : " .. tostring(enemyId))
        return
    end

    local npc = ents.Create(def.class)
    if not IsValid(npc) then return end

    npc:SetPos(pos)
    npc:SetAngles(Angle(0, math.random(0, 360), 0))
    if def.model then npc:SetModel(def.model) end
    if def.weapon then npc:SetKeyValue("additionalequipment", def.weapon) end
    npc:Spawn()
    npc:Activate()
    if def.model then npc:SetModel(def.model) end

    local members = table.Count(inst.members)
    local health = math.floor((def.health or 100) * (1 + (def.scalePerMember or 0) * (members - 1)))
    npc:SetMaxHealth(health)
    npc:SetHealth(health)

    npc.NRPMissionEnemy = true
    npc.NRPDamageScale = def.damageScale or 1
    npc.NRPRole = role or "target"
    npc.NRPXPReward = def.xp

    npc:AddRelationship("player D_NU 99")
    HateMembers(npc, inst)

    local leader = inst.leader
    if IsValid(leader) and npc.UpdateEnemyMemory then
        npc:UpdateEnemyMemory(leader, leader:GetPos())
    end

    return Missions.Track(inst, npc)
end

-- Vagues d'ennemis autour d'un point
function Missions.SpawnWave(inst, enemyId, center, count, radius)
    local spawned = {}
    for _ = 1, count do
        local npc = Missions.SpawnEnemy(inst, enemyId, Missions.FindGroundPos(center, radius or 600), "wave")
        if npc then spawned[#spawned + 1] = npc end
    end
    return spawned
end

-- PNJ allié (marchand escorté, dignitaire...)
function Missions.SpawnVIP(inst, pos, model, health)
    local npc = ents.Create("npc_citizen")
    if not IsValid(npc) then return end

    npc:SetKeyValue("citizentype", "4")
    npc:SetKeyValue("spawnflags", tostring(bit.bor(SF_NPC_NO_WEAPON_DROP, SF_CITIZEN_NOT_COMMANDABLE or 0)))
    npc:SetPos(pos)
    if model then npc:SetModel(model) end
    npc:Spawn()
    npc:Activate()
    if model then npc:SetModel(model) end

    npc:SetMaxHealth(health or 100)
    npc:SetHealth(health or 100)
    npc.NRPRole = "vip"
    npc:AddRelationship("player D_LI 99")

    return Missions.Track(inst, npc)
end

-- Les nouveaux membres deviennent aussi des cibles
hook.Add("NRP.MissionMemberJoined", "NRP.Missions.EnemyRelations", function(inst)
    for _, ent in ipairs(inst.entities) do
        if IsValid(ent) and ent.NRPMissionEnemy then
            HateMembers(ent, inst)
        end
    end
end)

-- Les dégâts entre PNJ de mission et joueurs extérieurs sont ignorés
hook.Add("EntityTakeDamage", "NRP.Missions.OutsiderDamage", function(target, dmg)
    local inst = target.NRPMission
    if not inst or not target.NRPMissionEnemy then return end
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() and not inst.members[attacker] then
        return true
    end
end)
