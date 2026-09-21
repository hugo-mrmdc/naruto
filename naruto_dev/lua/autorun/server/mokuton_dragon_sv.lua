--========================================================
-- Mokuton Dragon Ride (SV)
-- - prop_dynamic + joueur sur le dos
-- - Animation "fly" jouée UNE FOIS
-- - Dragon NON solide / Joueur SOLIDE (ne traverse pas les murs)
-- - Pas de dégâts de chute pendant le ride
--========================================================

if not SERVER then return end

util.AddNetworkString("mokuton_dragon_spawn")
util.AddNetworkString("mokuton_dragon_kill")
util.AddNetworkString("mokuton_dragon_grab") --
local MODEL                = "models/mokuton/mokutonDragon1.mdl"

local SEQ                  = "fly"

local SCALE                = 55
local ANIM_SPEED           = 1

-- Mouvement
local FLY_SPEED            = 1500
local FLY_UP_SPEED         = 900
local TAKEOFF_BOOST        = 1200

-- Rotation smoothing
local TURN_RATE            = 150
local PITCH_RATE           = 150
local PITCH_MIN, PITCH_MAX = -35, 35

-- Position joueur
local PLAYER_OFFSET_FWD    = -40
local PLAYER_OFFSET_UP     = 10

-- Grab (E)
local GRAB_RANGE           = 260  -- distance "zone moyen" devant le joueur
local GRAB_CONE_DOT        = 0.75 -- ~41° de cône (1 = pile devant)
local GRAB_HULL            = 22   -- vérif anti-mur (évite grab à travers murs)

-- Position de la cible (dans la bouche du dragon)
local MOUTH_OFFSET_FWD     = 0
local MOUTH_OFFSET_UP      = 10
-- Os de la mâchoire : la cible est tenue là plutôt qu'au centre du dragon
local MOUTH_BONE           = "Jaw 01"

-- Protection contre les dégâts de chute après être descendu (le dragon vole haut)
local FALL_GRACE           = 6

local state                = {}
local nextRide             = {}

----------------------------------------------------------
-- Descente en sécurité : pas de mur, pas de dégâts de chute
----------------------------------------------------------
local function ProtectFall(ent)
    if IsValid(ent) then
        ent.MokutonNoFall = CurTime() + FALL_GRACE
    end
end

-- Cherche une position libre autour de pos (sinon renvoie pos tel quel)
local function FreePos(ent, pos)
    if not IsValid(ent) then return pos end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local offsets = {
        vector_origin,
        Vector(0, 0, 16),
        Vector(40, 0, 16), Vector(-40, 0, 16),
        Vector(0, 40, 16), Vector(0, -40, 16),
        Vector(0, 0, 72),
    }
    for _, off in ipairs(offsets) do
        local test = pos + off
        local tr = util.TraceHull({
            start = test, endpos = test, mins = mins, maxs = maxs,
            mask = MASK_PLAYERSOLID, filter = ent,
        })
        if not tr.Hit then return test end
    end
    return pos
end

-- Position de la gueule : os de la mâchoire si le modèle l'expose, sinon repli
local function MouthPos(dragon, ang)
    if IsValid(dragon) then
        local bone = dragon:LookupBone(MOUTH_BONE)
        if bone then
            local bpos = dragon:GetBonePosition(bone)
            -- GetBonePosition renvoie parfois la position de l'entité si les os ne
            -- sont pas encore calculés : dans ce cas on utilise le repli.
            if bpos and bpos ~= dragon:GetPos() then return bpos end
        end
    end
    return dragon:GetPos() + ang:Forward() * MOUTH_OFFSET_FWD + ang:Up() * MOUTH_OFFSET_UP
end
local function TryGrab(owner)
    local st = state[owner]
    if not st or not IsValid(st.dragon) then return end
    if IsValid(st.grabbed) then return end -- déjà une cible

    local eyePos = owner:EyePos()
    local fwd    = owner:EyeAngles():Forward()

    local best, bestDistSqr
    -- recherche limitée à la portée (avant : parcours de TOUTES les entités de la map)
    for _, ent in ipairs(ents.FindInSphere(eyePos, GRAB_RANGE)) do
        if not IsValid(ent) then continue end
        if ent == owner or ent == st.dragon then continue end
        if not (ent:IsPlayer() or ent:IsNPC()) then continue end

        local targetPos = ent:WorldSpaceCenter()
        local to = (targetPos - eyePos)
        local distSqr = to:LengthSqr()
        if distSqr > (GRAB_RANGE * GRAB_RANGE) then continue end

        local dir = to:GetNormalized()
        if dir:Dot(fwd) < GRAB_CONE_DOT then continue end

        -- Anti-grab à travers murs
        local tr = util.TraceHull({
            start  = eyePos,
            endpos = targetPos,
            mins   = Vector(-GRAB_HULL, -GRAB_HULL, -GRAB_HULL),
            maxs   = Vector( GRAB_HULL,  GRAB_HULL,  GRAB_HULL),
            filter = { owner, st.dragon, ent },
            mask   = MASK_SHOT
        })
        if tr.Hit then continue end

        if (not best) or distSqr < bestDistSqr then
            best = ent
            bestDistSqr = distSqr
        end
    end

    local ent = best
    if not IsValid(ent) then return end

    -- checks player
    if ent:IsPlayer() then
        if not ent:Alive() then return end
        if ent:GetNWBool("MokutonRide", false) then return end
        if ent:GetNWBool("MokutonGrabbed", false) then return end
    end

    -- Save old state + lock
    st.grabbed = ent
    st.grabbedOld = {
        move  = ent:GetMoveType(),
        solid = ent:GetSolid(),
        col   = ent:GetCollisionGroup(),
        grav  = ent:IsPlayer() and ent:GetGravity() or nil,
    }

    if ent:IsPlayer() then
        ent:SetNWBool("MokutonGrabbed", true)
        ent:SetGravity(0)
    end

    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetSolid(SOLID_NONE)
    ent:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
end
local function ReleaseGrab(owner)
    local st = state[owner]
    if not st then return end
    if not IsValid(st.grabbed) then
        st.grabbed = nil
        st.grabbedOld = nil
        return
    end

    local ent = st.grabbed
    local old = st.grabbedOld or {}

    -- Restore
    if ent:IsPlayer() then
        ent:SetNWBool("MokutonGrabbed", false)

        if old.grav ~= nil then
            ent:SetGravity(old.grav)
        else
            ent:SetGravity(1)
        end
    end

    if old.move ~= nil then ent:SetMoveType(old.move) else ent:SetMoveType(MOVETYPE_WALK) end
    if old.solid ~= nil then ent:SetSolid(old.solid) else ent:SetSolid(SOLID_BBOX) end
    if old.col ~= nil then ent:SetCollisionGroup(old.col) else ent:SetCollisionGroup(COLLISION_GROUP_PLAYER) end

    -- Petit "drop" devant pour éviter qu'il reste coincé dans toi
    -- state[owner] est une table : IsValid() renvoyait toujours false et la cible restait coincée
    if IsValid(owner) and state[owner] and IsValid(state[owner].dragon) then
        local ang = state[owner].dragon:GetAngles()
        local dropPos = state[owner].dragon:GetPos() + ang:Forward() * 90 + ang:Up() * 10
        -- ne pas relâcher la cible dans un mur
        ent:SetPos(FreePos(ent, dropPos))
    end

    -- lâchée en plein vol : pas de dégâts de chute pendant quelques secondes
    ProtectFall(ent)

    st.grabbed = nil
    st.grabbedOld = nil
end

----------------------------------------------------------
-- Stop Ride
----------------------------------------------------------
local function StopRide(ply)
    local st = state[ply]
    if not st then return end

    -- relâcher AVANT de supprimer le dragon (sinon aucune position de dépôt)
    ReleaseGrab(ply)
    if IsValid(st.dragon) then
        st.dragon:Remove()
    end

    if IsValid(ply) then
        ply:SetMoveType(st.oldMove or MOVETYPE_WALK)
        ply:SetGravity(st.oldGrav or 1)

        -- ✅ Restore collisions/solidité
        ply:SetSolid(st.oldSolid or SOLID_BBOX)
        ply:SetCollisionGroup(st.oldCol or COLLISION_GROUP_PLAYER)

        -- descendre dans un mur bloquait le joueur sur place
        ply:SetPos(FreePos(ply, ply:GetPos()))

        -- on descend souvent en altitude : la chute ne doit pas tuer
        ProtectFall(ply)

        ply:SetNWBool("MokutonRide", false)
    end

    state[ply] = nil
end

----------------------------------------------------------
-- Start Ride
----------------------------------------------------------
local function StartRide(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    -- une cible tenue dans la gueule ne peut pas invoquer son propre dragon
    if ply:GetNWBool("MokutonGrabbed", false) then return end
    if (nextRide[ply] or 0) > CurTime() then return end
    nextRide[ply] = CurTime() + 1
    if NA_CD then NA_CD.Set(ply, "mokuton_dragon", 1) end -- recharge visible dans la barre
    StopRide(ply)

    if not util.IsValidModel(MODEL) then
        print("[MOKUTON] modèle introuvable:", MODEL)
        return
    end

    local dragon = ents.Create("prop_dynamic")
    if not IsValid(dragon) then return end

    dragon:SetModel(MODEL)
    dragon:SetPos(ply:GetPos())
    dragon:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    dragon:Spawn()
    dragon:Activate()

    dragon:SetModelScale(SCALE, 0)

    -- ❌ Dragon NON solide
    dragon:SetSolid(SOLID_NONE)
    dragon:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    dragon:SetMoveType(MOVETYPE_NONE)

    -- ✅ Animation jouée UNE FOIS
    dragon:ResetSequence(SEQ)
    dragon:SetPlaybackRate(ANIM_SPEED)
    dragon:SetCycle(0)

    state[ply] = {
        dragon   = dragon,
        oldMove  = ply:GetMoveType(),
        oldGrav  = ply:GetGravity(),
        oldSolid = ply:GetSolid(),
        oldCol   = ply:GetCollisionGroup(),
        yaw      = ply:EyeAngles().y,
        pitch    = 0,
    }

    -- ✅ Joueur SOLIDE (mais attention : SetPos traverse si pas de trace)
    ply:SetSolid(SOLID_BBOX)
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)

    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetNWBool("MokutonRide", true)
end

----------------------------------------------------------
-- Mouvement dragon + joueur (anti-travers-murs)
----------------------------------------------------------
hook.Add("Think", "MokutonDragon_Move", function()
    for ply, st in pairs(state) do
        if not IsValid(ply) or not IsValid(st.dragon) then
            if IsValid(ply) then
                ReleaseGrab(ply) -- ✅ relâche si plus de dragon / joueur invalide
                StopRide(ply)
            else
                -- joueur parti : l'entrée restait dans la table pour toujours
                if IsValid(st.dragon) then st.dragon:Remove() end
                state[ply] = nil
            end
            continue
        end

        -- mort en vol : on arrête proprement (le corps ne doit pas rester accroché)
        if not ply:Alive() then
            StopRide(ply)
            continue
        end

        local dt = FrameTime()
        if dt <= 0 then continue end
        if dt > 0.05 then dt = 0.05 end

        local eye = ply:EyeAngles()

        -- Rotation
        local targetYaw   = eye.y
        local targetPitch = math.Clamp(eye.p, PITCH_MIN, PITCH_MAX)

        st.yaw   = math.ApproachAngle(st.yaw, targetYaw, TURN_RATE * dt)
        st.pitch = math.ApproachAngle(st.pitch, targetPitch, PITCH_RATE * dt)

        -- Velocity
        local ang = Angle(st.pitch, st.yaw, 0)
        local dir = ang
        local vel = dir:Forward() * FLY_SPEED

        if ply:KeyDown(IN_JUMP) then
            vel.z = vel.z + (ply:OnGround() and TAKEOFF_BOOST or FLY_UP_SPEED)
        end

        if ply:KeyDown(IN_DUCK) then
            vel.z = vel.z - FLY_UP_SPEED
        end

        -- Position voulue du joueur sur le dos
        local desiredPos =
            st.dragon:GetPos()
            + vel * dt
            + ang:Forward() * PLAYER_OFFSET_FWD
            + ang:Up()      * PLAYER_OFFSET_UP

        -- ✅ Anti-travers-murs : trace hull (hitbox joueur)
        local tr = util.TraceHull({
            start  = ply:GetPos(),
            endpos = desiredPos,
            mins   = ply:OBBMins(),
            maxs   = ply:OBBMaxs(),
            filter = { ply, st.dragon },
            mask   = MASK_PLAYERSOLID
        })

        local finalPos = desiredPos
        if tr.Hit then
            finalPos = tr.HitPos + tr.HitNormal * 2
        end

        -- ✅ Dragon suit la position RÉELLE du joueur (weld behavior)
        local dragonPos =
            finalPos
            - ang:Forward() * PLAYER_OFFSET_FWD
            - ang:Up()      * PLAYER_OFFSET_UP

        st.dragon:SetPos(dragonPos)
        st.dragon:SetAngles(ang)
        ply:SetPos(finalPos)

        -- ✅ Maintien de la cible dans la bouche (si grab)
        if IsValid(st.grabbed) then
            -- si la cible devient invalide / morte => release
            if st.grabbed:IsPlayer() and (not st.grabbed:Alive()) then
                ReleaseGrab(ply)
                continue
            end

            -- la cible est tenue à la mâchoire, plus au centre du dragon
            st.grabbed:SetPos(MouthPos(st.dragon, ang))
            st.grabbed:SetAngles(Angle(0, ang.y + 90, 0))
        end
    end
end)

net.Receive("mokuton_dragon_grab", function(_, ply)
    local st = state[ply]
    if not st then return end

    if IsValid(st.grabbed) then
        ReleaseGrab(ply)
    else
        TryGrab(ply)
    end
end)

----------------------------------------------------------
-- Force idle joueur pendant le ride
----------------------------------------------------------
hook.Add("CalcMainActivity", "Mokuton_ForceIdle", function(ply)
    if ply:GetNWBool("MokutonRide", false) then
        return ACT_HL2MP_IDLE, -1
    end
end)

hook.Add("UpdateAnimation", "Mokuton_ForceIdle_Update", function(ply)
    if ply:GetNWBool("MokutonRide", false) then
        ply:SetPlaybackRate(1)
        return true
    end
end)

----------------------------------------------------------
-- Pas de dégâts de chute pendant le ride
----------------------------------------------------------
-- Protégé pendant le vol, et quelques secondes après être descendu
local function FallImmune(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() and ent:GetNWBool("MokutonRide", false) then return true end
    return (ent.MokutonNoFall or 0) > CurTime()
end

hook.Add("GetFallDamage", "Mokuton_NoFallDamage", function(ply)
    if FallImmune(ply) then
        return 0
    end
end)

-- (optionnel mais safe)
hook.Add("EntityTakeDamage", "Mokuton_BlockFallDMG", function(ent, dmg)
    if FallImmune(ent) then
        if dmg:IsFallDamage() or dmg:GetDamageType() == DMG_FALL then
            dmg:SetDamage(0)
            dmg:ScaleDamage(0)
            return true
        end
    end
end)

----------------------------------------------------------
-- Net
----------------------------------------------------------
net.Receive("mokuton_dragon_spawn", function(_, ply)
    if not NA_Debloquee(ply, "mokuton_dragon") then return end   -- technique pas encore débloquée (F6)
    StartRide(ply)
end)

net.Receive("mokuton_dragon_kill", function(_, ply)
    StopRide(ply)
end)

hook.Add("PlayerDisconnected", "MokutonDragon_Cleanup", function(ply)
    StopRide(ply)
    nextRide[ply] = nil
end)

hook.Add("PlayerDeath", "MokutonDragon_StopOnDeath", StopRide)

-- Réapparition d'une cible qui était dans la gueule : on oublie la prise sans la
-- téléporter (le joueur vient d'être placé à son point d'apparition).
hook.Add("PlayerSpawn", "MokutonDragon_FixSpawn", function(ply)
    for _, st in pairs(state) do
        if st.grabbed == ply then
            st.grabbed = nil
            st.grabbedOld = nil
        end
    end
    ply:SetNWBool("MokutonGrabbed", false)
end)
