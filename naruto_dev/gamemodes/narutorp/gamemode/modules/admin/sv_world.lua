--[[
    Module : entités persistantes par carte (PNJ de mission, marchands, mannequins...)

        NRP.World.SpawnPersistent(class, pos, ang, data)
        !persist        -> rend persistante l'entité visée
        !unpersist      -> supprime l'entité visée de la sauvegarde (et du monde)
        !shopnpc <id>   -> place un marchand      !dummy -> place un mannequin

    Une entité peut définir ENT:GetPersistData() / ENT:SetPersistData(data).
]]

NRP.World = NRP.World or {}
local World = NRP.World
local DB = NRP.DB

World.Classes = {
    nrp_mission_npc = true,
    nrp_shop_npc = true,
    nrp_training_dummy = true,
}

DB.RegisterTable("world_entities", {
    columns = {
        { "id", "id" }, { "map", "string", "" }, { "class", "string", "" },
        { "x", "float", 0 }, { "y", "float", 0 }, { "z", "float", 0 },
        { "pitch", "float", 0 }, { "yaw", "float", 0 }, { "roll", "float", 0 },
        { "data", "json" },
    },
    primary = { "id" },
    indexes = { { "map" } },
})

local function Create(class, pos, ang, data)
    local ent = ents.Create(class)
    if not IsValid(ent) then return end
    ent:SetPos(pos)
    ent:SetAngles(ang)
    if ent.SetPersistData then
        ent:SetPersistData(data or {})
    end
    ent:Spawn()
    ent:Activate()

    if ent:GetClass() == "nrp_training_dummy" then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
    end
    return ent
end

function World.Load()
    for _, ent in ipairs(ents.GetAll()) do
        if ent.NRPWorldId then ent:Remove() end
    end

    DB.Select("world_entities", { map = game.GetMap() }, function(rows)
        for _, row in ipairs(rows) do
            local ent = Create(row.class,
                Vector(tonumber(row.x), tonumber(row.y), tonumber(row.z)),
                Angle(tonumber(row.pitch), tonumber(row.yaw), tonumber(row.roll)),
                util.JSONToTable(row.data or "") or {})
            if IsValid(ent) then
                ent.NRPWorldId = tonumber(row.id)
            end
        end
        NRP.Print("Monde : " .. #rows .. " entité(s) persistante(s) chargée(s)")
    end)
end

function World.Save(ent, callback)
    if not World.Classes[ent:GetClass()] then return false, "Cette entité ne peut pas être sauvegardée." end
    local pos, ang = ent:GetPos(), ent:GetAngles()
    local data = ent.GetPersistData and ent:GetPersistData() or {}
    local row = {
        map = game.GetMap(), class = ent:GetClass(),
        x = pos.x, y = pos.y, z = pos.z, pitch = ang.p, yaw = ang.y, roll = ang.r,
        data = data,
    }

    if ent.NRPWorldId then
        DB.Update("world_entities", row, { id = ent.NRPWorldId }, callback)
    else
        DB.Insert("world_entities", row, function(_, id)
            if IsValid(ent) then ent.NRPWorldId = tonumber(id) end
            if callback then callback() end
        end)
    end
    return true
end

function World.Remove(ent)
    if ent.NRPWorldId then
        DB.Delete("world_entities", { id = ent.NRPWorldId })
    end
    ent:Remove()
end

function World.SpawnPersistent(class, pos, ang, data)
    local ent = Create(class, pos, ang, data)
    if IsValid(ent) then
        World.Save(ent)
    end
    return ent
end

-- Chargement quand la carte ET la base sont prêtes
local mapReady, dbReady = false, false
local function TryLoad()
    if mapReady and dbReady then World.Load() end
end
hook.Add("InitPostEntity", "NRP.World.Map", function() mapReady = true TryLoad() end)
hook.Add("NRP.DatabaseReady", "NRP.World.DB", function() dbReady = true TryLoad() end)
hook.Add("PostCleanupMap", "NRP.World.Cleanup", World.Load)

local function AimedEntity(ply)
    local ent = ply:GetEyeTrace().Entity
    if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) < 800 * 800 then
        return ent
    end
end

NRP.Commands.Add("persist", {
    perm = "admin.world", description = "Sauvegarder l'entité visée pour cette carte",
    run = function(caller)
        local ent = caller ~= NULL and AimedEntity(caller)
        if not ent then return false, "Visez une entité." end
        local ok, err = World.Save(ent)
        if not ok then return false, err end
        NRP.LogAction("world", caller, nil, "persist " .. ent:GetClass())
        return true, "Entité sauvegardée."
    end,
})

NRP.Commands.Add("unpersist", {
    perm = "admin.world", description = "Supprimer l'entité visée (et sa sauvegarde)",
    run = function(caller)
        local ent = caller ~= NULL and AimedEntity(caller)
        if not ent or not World.Classes[ent:GetClass()] then return false, "Visez une entité du gamemode." end
        World.Remove(ent)
        return true, "Entité supprimée."
    end,
})

NRP.Commands.Add("shopnpc", {
    perm = "admin.world", usage = "shopnpc <boutique>", description = "Placer un marchand",
    args = { "string" },
    run = function(caller, shopId)
        if caller == NULL then return false, "Commande en jeu uniquement." end
        if not NRP.Inventory.Shops:Exists(shopId) then return false, "Boutique inconnue." end
        local ent = World.SpawnPersistent("nrp_shop_npc", caller:GetEyeTrace().HitPos, Angle(0, caller:EyeAngles().y + 180, 0), { shop = shopId })
        return IsValid(ent), "Marchand placé."
    end,
})

NRP.Commands.Add("dummy", {
    perm = "admin.world", description = "Placer un mannequin d'entraînement",
    run = function(caller)
        if caller == NULL then return false, "Commande en jeu uniquement." end
        local ent = World.SpawnPersistent("nrp_training_dummy", caller:GetEyeTrace().HitPos + Vector(0, 0, 64), Angle(0, caller:EyeAngles().y, 0), {})
        return IsValid(ent), "Mannequin placé."
    end,
})
