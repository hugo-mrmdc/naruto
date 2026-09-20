-- Fake Players Spawner (SERVER)
-- Commandes:
--   fakeplayers_spawn <nb>   (ex: fakeplayers_spawn 3)
--   fakeplayers_clear

if not SERVER then return end

FAKE_PLAYERS = FAKE_PLAYERS or {}

local function SpawnFakePlayer(ply, modelPath, pos, ang)
    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    ent:SetModel(modelPath)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:Spawn()
    ent:Activate()

    -- ✅ REND LE PROP TOUCHABLE
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetSolid(SOLID_BBOX)
    ent:SetCollisionGroup(COLLISION_GROUP_NONE)

    -- Hitbox type joueur (approximative)
    ent:PhysicsInitBox(Vector(-16, -16, 0), Vector(16, 16, 72))
    ent:SetTrigger(false)

    -- Animation idle
    local seq = ent:LookupSequence("idle_all_01")
    if seq < 0 then seq = ent:LookupSequence("Idle") end
    if seq < 0 then seq = 0 end

    ent:SetSequence(seq)
    ent:SetPlaybackRate(1)
    ent:SetCycle(0)

    table.insert(FAKE_PLAYERS, ent)
    return ent
end


concommand.Add("fakeplayers_clear", function(ply)
    for _, ent in ipairs(FAKE_PLAYERS) do
        if IsValid(ent) then ent:Remove() end
    end
    FAKE_PLAYERS = {}
    if IsValid(ply) then ply:ChatPrint("Fake players supprimés.") end
end)

concommand.Add("fakeplayers_spawn", function(ply, _, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local count = tonumber(args[1] or "1") or 1
    count = math.Clamp(count, 1, 20)

    -- modèle de player (tu peux changer)
    local modelPath = "models/player/kleiner.mdl"

    local basePos = ply:GetPos()
    local forward = ply:GetForward()
    local right = ply:GetRight()

    -- petit cercle autour du joueur
    local radius = 120

    for i = 1, count do
        local a = (i / count) * math.pi * 2
        local offset = (math.cos(a) * right + math.sin(a) * forward) * radius
        local pos = basePos + offset
        pos.z = basePos.z

        local ang = Angle(0, (ply:EyeAngles().y + 180 + (i * (360 / count))) % 360, 0)

        SpawnFakePlayer(ply, modelPath, pos, ang)
    end

    ply:ChatPrint("Fake players spawn: " .. count)
end)
