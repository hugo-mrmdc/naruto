--[[
    Types de mission sans combat obligatoire : delivery, retrieve, recon

    Chaque type implémente tout ou partie de :
        Start(inst) -> true | false, raison
        Check(inst)                         -- toutes les CheckInterval secondes
        OnNPCKilled(inst, npc, attacker)
        OnItemUsed(inst, ply, ent)          -- objet de mission utilisé (nrp_mission_item)
        OnTurnIn(inst, ply, npc) -> bool    -- joueur qui parle à un PNJ de mission
        OnJoin(inst, ply)
        Cleanup(inst)
]]

local Missions = NRP.Missions
local Inv = NRP.Inventory

---------------------------------------------------------------------------
-- Livraison : apporter l'objet donné au départ jusqu'au point
---------------------------------------------------------------------------
Missions.RegisterType("delivery", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        local itemId = inst.params.item
        if Inv.Give(inst.leader, itemId, 1, true) <= 0 then
            return false, "Votre inventaire est plein."
        end

        inst.data.point = point
        local item = Inv.Items:Get(itemId)
        Missions.SetWaypoints(inst, { { pos = point.pos, label = point.name } })
        Missions.SetObjective(inst, "Livrez « " .. item.name .. " » : " .. point.name, 0, 1)
        return true
    end,

    Check = function(inst)
        local point = inst.data.point
        local ply = Missions.MemberNear(inst, point.pos, inst.params.radius or 150)
        if ply and Inv.Has(ply, inst.params.item) then
            Inv.Take(ply, inst.params.item, 1)
            Missions.Complete(inst)
        end
    end,
})

---------------------------------------------------------------------------
-- Récupération : trouver l'objet puis le rapporter à un donneur du village
---------------------------------------------------------------------------
Missions.RegisterType("retrieve", {
    Start = function(inst)
        local point = Missions.PickPoints(inst.params.point, 1)[1]
        local ent = ents.Create("nrp_mission_item")
        if not IsValid(ent) then return false end

        ent:SetModel(inst.params.model or "models/props_junk/cardboard_box003a.mdl")
        ent:SetPos(Missions.FindGroundPos(point.pos, 80) + Vector(0, 0, 10))
        ent:Spawn()
        Missions.Track(inst, ent)

        inst.data.point = point
        Missions.SetWaypoints(inst, { { pos = point.pos, label = "Objet perdu" } })
        Missions.SetObjective(inst, "Retrouvez l'objet perdu près de : " .. point.name, 0, 2)
        return true
    end,

    OnItemUsed = function(inst, ply, ent)
        if inst.data.picked then return end
        if Inv.Give(ply, inst.params.item, 1, true) <= 0 then
            NRP.Notify(ply, "Inventaire plein.", NRP.NOTIFY_ERROR)
            return
        end

        inst.data.picked = true
        ent:Remove()

        local waypoints = {}
        if IsValid(inst.giver) then
            waypoints[1] = { pos = inst.giver:GetPos() + Vector(0, 0, 70), label = "Donneur de mission" }
        end
        Missions.SetWaypoints(inst, waypoints)
        Missions.SetObjective(inst, "Rapportez l'objet à un donneur de mission du village", 1, 2)
    end,

    OnTurnIn = function(inst, ply, npc)
        if not inst.data.picked then return false end
        if npc:GetVillage() ~= "" and npc:GetVillage() ~= inst.village then return false end
        if not Inv.Take(ply, inst.params.item, 1) then return false end
        Missions.Complete(inst)
        return true
    end,
})

---------------------------------------------------------------------------
-- Reconnaissance : visiter plusieurs points dans l'ordre
---------------------------------------------------------------------------
local function ReconWaypoint(inst)
    local point = inst.data.points[inst.data.index]
    Missions.SetWaypoints(inst, { { pos = point.pos, label = point.name } })
    Missions.SetObjective(inst, "Inspectez : " .. point.name, inst.data.index - 1, #inst.data.points)
end

Missions.RegisterType("recon", {
    Start = function(inst)
        inst.data.points = Missions.PickPoints(inst.params.point, inst.params.count or 3)
        inst.data.index = 1
        ReconWaypoint(inst)
        return true
    end,

    Check = function(inst)
        local point = inst.data.points[inst.data.index]
        if not Missions.MemberNear(inst, point.pos, inst.params.radius or 200) then return end

        inst.data.index = inst.data.index + 1
        if inst.data.index > #inst.data.points then
            Missions.Complete(inst)
        else
            for _, ply in ipairs(Missions.Members(inst)) do
                NRP.Notify(ply, "Zone inspectée : " .. point.name, NRP.NOTIFY_SUCCESS, 2)
            end
            ReconWaypoint(inst)
        end
    end,
})
