-- =========================================
--  MOKUTON (STUN + DESPAWN + DAMAGE)
--  Fix "reste bloqué" :
--   - Player stun movement bloqué côté SERVEUR via SetupMove (fiable)
--   - Caméra figée optionnelle côté CLIENT via StartCommand
--   - NPC/NextBot lock via Think + MOVETYPE_NONE + AI off
-- =========================================

if SERVER then
    util.AddNetworkString("KSpawn_Request")
    util.AddNetworkString("Mokuton_ImpactFX")
    util.AddNetworkString("Mokuton_PlaySound")
end

local MODEL     = "models/mokuton/mokutonArche.mdl"
local COUNT     = 3
local DELAY     = 0.1
local HEIGHT    = 800
local DROP_TIME = 0.6
local COOLDOWN  = 2
local GAP       = 4

-- visée
local TRACE_RANGE = 1000
local HULL_MINS   = Vector(-40, -40, -40)
local HULL_MAXS   = Vector( 40,  40,  40)

-- scale
local baseScale = 8
local stepScale = 4

-- stun
local STUN_TIME = 4.0

-- damage
local DAMAGE_AMOUNT = 20
local DAMAGE_RADIUS = 120

local DEBUG_HITBOX = false

if SERVER then
    resource.AddFile("sound/mokuton/wood3.wav")
    PrecacheParticleSystem("hit_2_arche")
end

-- =========================================
-- Utils sol (évite le floating)
-- =========================================
local function GetGroundedPos(pos)
    local tr = util.TraceLine({
        start  = pos + Vector(0,0,50),
        endpos = pos - Vector(0,0,800),
        mask   = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit then
        return Vector(pos.x, pos.y, tr.HitPos.z)
    end

    return pos
end

local function GroundEntity(ent)
    if not IsValid(ent) then return end
    ent:SetPos(GetGroundedPos(ent:GetPos()))
    if ent.DropToFloor then ent:DropToFloor() end
end

local function GetWorldGroundZ(pos)
    local tr = util.TraceLine({
        start  = pos + Vector(0,0,2000),
        endpos = pos - Vector(0,0,10000),
        mask   = MASK_SOLID_BRUSHONLY
    })
    return tr.HitPos.z
end

-- =========================================
-- Targeting
-- =========================================
local function GetLookTarget(ply)
    if not IsValid(ply) then return end

    local startPos = ply:EyePos()
    local dir      = ply:EyeAngles():Forward()
    local endPos   = startPos + dir * TRACE_RANGE

    local trLine = util.TraceLine({
        start  = startPos,
        endpos = endPos,
        filter = ply,
        mask   = MASK_SHOT
    })

    if DEBUG_HITBOX then
        debugoverlay.Line(startPos, trLine.HitPos, 0.1, Color(0,150,255), true)
        debugoverlay.Cross(trLine.HitPos, 4, 0.1, Color(0,150,255), true)
    end

    local ent = trLine.Entity
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
        if DEBUG_HITBOX then
            local mins, maxs = ent:WorldSpaceAABB()
            debugoverlay.Box(Vector(0,0,0), mins, maxs, 0.1, Color(0,255,0,120))
        end
        return ent
    end

    local trHull = util.TraceHull({
        start  = startPos,
        endpos = endPos,
        mins   = HULL_MINS,
        maxs   = HULL_MAXS,
        filter = ply,
        mask   = MASK_SHOT_HULL
    })

    if DEBUG_HITBOX then
        debugoverlay.SweptBox(startPos, trHull.HitPos, HULL_MINS, HULL_MAXS, angle_zero, 0.1, Color(255,255,0,120))
        debugoverlay.Cross(trHull.HitPos, 4, 0.1, Color(255,255,0,120), true)
    end

    ent = trHull.Entity
    if IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then
        if DEBUG_HITBOX then
            local mins, maxs = ent:WorldSpaceAABB()
            debugoverlay.Box(Vector(0,0,0), mins, maxs, 0.1, Color(0,255,0,120))
        end
        return ent
    end
end

-- =========================================
-- Lock table (NPC/NextBot only)
-- =========================================
local mokutonLocked = mokutonLocked or {}

hook.Add("Think", "mokuton_hardlock_think", function()
    local now = CurTime()

    for ent, data in pairs(mokutonLocked) do
        if (not IsValid(ent)) or (data.untilTime <= now) then
            mokutonLocked[ent] = nil
        else
            if not (ent:IsNPC() or ent:IsNextBot()) then
                mokutonLocked[ent] = nil
                continue
            end

            ent:SetPos(GetGroundedPos(data.pos))
            if data.ang then ent:SetAngles(data.ang) end

            ent:SetVelocity(vector_origin)
            if ent.loco then ent.loco:SetVelocity(vector_origin) end
        end
    end
end)

-- =========================================
-- PLAYER hard stun (SERVEUR) via SetupMove
-- -> évite "reste bloqué"
-- =========================================
if SERVER then
    hook.Add("SetupMove", "mokuton_blockmove_sv", function(ply, mv, cmd)
        if not IsValid(ply) then return end

        local untilTime = ply._mokuton_stun_until
        if not untilTime then return end

        if untilTime <= CurTime() then
            -- nettoyage (au cas où)
            ply._mokuton_stun_until = nil
            ply._mokuton_stun_ang   = nil
            return
        end

        -- bloque mouvement
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)

        -- bloque boutons (tir, saut, etc.)
        mv:SetButtons(0)
    end)
end

-- =========================================
-- PLAYER caméra figée (CLIENT) optionnel
-- =========================================
if CLIENT then
    hook.Add("StartCommand", "mokuton_fixview_cl", function(ply, cmd)
        if not IsValid(ply) then return end

        local untilTime = ply._mokuton_stun_until
        if not untilTime then return end
        if untilTime <= CurTime() then
            -- nettoyage client
            ply._mokuton_stun_until = nil
            ply._mokuton_stun_ang   = nil
            return
        end

        if ply._mokuton_stun_ang then
            cmd:SetViewAngles(ply._mokuton_stun_ang)
        end
    end)
end

-- =========================================
-- Stun Entity (Player / NPC / NextBot)
-- =========================================
local function StunEntity(ent, duration)
    if not IsValid(ent) then return end

    local id = "mokuton_stun_" .. ent:EntIndex()
    timer.Remove(id)

    local untilT = CurTime() + duration

    -- token anti re-stun
    ent._mokuton_stun_token = (ent._mokuton_stun_token or 0) + 1
    local token = ent._mokuton_stun_token

    -- snapshot MoveType
    ent._mokuton_oldMoveType = ent:GetMoveType()

    -- snap sol début
    GroundEntity(ent)

    -- =========================
    -- PLAYER
    -- =========================
    if ent:IsPlayer() then
        ent._mokuton_stun_until = untilT

        -- figer vue (local). côté serveur on stocke, côté client on lira la même variable si le fichier est shared
        ent._mokuton_stun_ang = ent:EyeAngles()

        -- Freeze suffit souvent, mais on garde pour être "hard"
        ent:Freeze(true)
        ent:SetNW2Bool("NA_Etourdi", true)   -- animation d'étourdissement (cl_etourdi_anim.lua)
        ent:SetMoveType(MOVETYPE_WALK) -- IMPORTANT: on évite MOVETYPE_NONE (source de blocages persistants)
        ent:SetVelocity(vector_origin)

        timer.Create(id, duration, 1, function()
            if not IsValid(ent) then return end
            if ent._mokuton_stun_token ~= token then return end

            -- fin : nettoyage complet
            GroundEntity(ent)
            ent:SetVelocity(vector_origin)

            ent._mokuton_stun_until = nil
            ent._mokuton_stun_ang   = nil

            ent:Freeze(false)
            ent:SetNW2Bool("NA_Etourdi", false)
            -- restore (walk en général)
            ent:SetMoveType(ent._mokuton_oldMoveType or MOVETYPE_WALK)
            ent._mokuton_oldMoveType = nil
        end)

        return
    end

    -- =========================
    -- NPC / NextBot
    -- =========================
    ent:SetVelocity(vector_origin)
    ent:SetMoveType(MOVETYPE_NONE)

    if ent.SetAIEnabled then
        ent._mokuton_oldAI = ent:IsAIEnabled()
        ent:SetAIEnabled(false)
    end

    if ent.ClearSchedule then ent:ClearSchedule() end
    if ent.SetSchedule then ent:SetSchedule(SCHED_NONE) end
    if ent.StopMoving then ent:StopMoving() end

    if ent.loco then
        ent._mokuton_oldSpeed = ent.loco:GetDesiredSpeed()
        ent.loco:SetDesiredSpeed(0)
        ent.loco:SetVelocity(vector_origin)
    end

    local lockPos = GetGroundedPos(ent:GetPos())
    mokutonLocked[ent] = {
        untilTime = untilT,
        pos       = lockPos,
        ang       = ent:GetAngles()
    }

    timer.Create(id, duration, 1, function()
        if not IsValid(ent) then return end
        if ent._mokuton_stun_token ~= token then return end

        mokutonLocked[ent] = nil

        GroundEntity(ent)
        ent:SetVelocity(vector_origin)

        ent:SetMoveType(ent._mokuton_oldMoveType or MOVETYPE_STEP)
        ent._mokuton_oldMoveType = nil

        if ent.SetAIEnabled and ent._mokuton_oldAI ~= nil then
            ent:SetAIEnabled(ent._mokuton_oldAI)
            ent._mokuton_oldAI = nil
        end

        if ent.loco and ent._mokuton_oldSpeed ~= nil then
            ent.loco:SetDesiredSpeed(ent._mokuton_oldSpeed)
            ent._mokuton_oldSpeed = nil
        end

        if ent.SetSchedule then
            ent:SetSchedule(SCHED_IDLE_STAND)
        end
    end)
end

-- =========================================
-- Damage at impact
-- =========================================
local function DoImpactDamage(attacker, inflictor, pos)
    if not SERVER then return end

    local dmg = DamageInfo()
    dmg:SetDamage(DAMAGE_AMOUNT)
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetDamagePosition(pos)

    if IsValid(attacker) then dmg:SetAttacker(attacker) end
    if IsValid(inflictor) then dmg:SetInflictor(inflictor) end

    for _, e in ipairs(ents.FindInSphere(pos, DAMAGE_RADIUS)) do
        if IsValid(e) and (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) then
            if e ~= attacker then
                e:TakeDamageInfo(dmg)
            end
        end
    end
end

-- =========================================
-- Spawn arche
-- =========================================
local function SpawnMokutonArcheOnPos(ply, index, groundPos)
    if not SERVER then return end

    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    local startPos = groundPos + Vector(0,0,HEIGHT)

    ent:SetModel(MODEL)
    ent:SetPos(startPos)

    local yawOffset = (index == 2) and 90 or 0
    ent:SetAngles(Angle(0, ply:EyeAngles().y + yawOffset, 0))

    ent:SetModelScale(baseScale + (index - 1) * stepScale, 0)

    ent:Spawn()
    ent:Activate()

    local t0  = CurTime()
    local tid = "mokuton_drop_" .. ent:EntIndex()

    timer.Create(tid, 0.01, 0, function()
        if not IsValid(ent) then timer.Remove(tid) return end

        local frac = (CurTime() - t0) / DROP_TIME
        if frac >= 1 then
            ent:SetPos(groundPos)

            DoImpactDamage(ply, ent, groundPos)

            net.Start("Mokuton_PlaySound")
            net.WriteVector(groundPos)
            net.Broadcast()

            net.Start("Mokuton_ImpactFX")
            net.WriteVector(groundPos)
            net.WriteAngle(angle_zero)
            net.Broadcast()

            timer.Remove(tid)
            return
        end

        ent:SetPos(LerpVector(frac, startPos, groundPos))
    end)

    return ent
end

-- =========================================
-- Network receive (SERVER)
-- =========================================
if SERVER then
    net.Receive("KSpawn_Request", function(_, ply)
        if not IsValid(ply) or not ply:Alive() then return end

        ply._kspawn_next = ply._kspawn_next or 0
        if ply._kspawn_next > CurTime() then return end
        ply._kspawn_next = CurTime() + COOLDOWN
        if NA_CD then NA_CD.Set(ply, "mokuton_arche", COOLDOWN) end -- recharge visible dans la barre

        local target = GetLookTarget(ply)
        if not IsValid(target) then return end

        -- stun la cible
        StunEntity(target, STUN_TIME)

        local center  = target:WorldSpaceCenter()
        local groundZ = GetWorldGroundZ(center)
        local right   = ply:EyeAngles():Right()

        local spawnedArches = {}

        for i = 1, COUNT do
            timer.Simple((i - 1) * DELAY, function()
                if not IsValid(ply) then return end

                local offset = (i - 2) * GAP
                local pos = center + right * offset
                pos = Vector(pos.x, pos.y, groundZ)

                local arch = SpawnMokutonArcheOnPos(ply, i, pos)
                if IsValid(arch) then
                    table.insert(spawnedArches, arch)
                end
            end)
        end

        -- suppression après stun
        timer.Simple(STUN_TIME, function()
            for _, arch in ipairs(spawnedArches) do
                if IsValid(arch) then arch:Remove() end
            end
        end)
    end)
end
