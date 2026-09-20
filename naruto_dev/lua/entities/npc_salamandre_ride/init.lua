-- npc_salamandre_ride.lua
-- Place dans garrysmod/lua/entities/npc_salamandre_ride/init.lua

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- Charger les particules
game.AddParticles("particles/julio.pcf")
PrecacheParticleSystem("poison_jet")

-- Configuration
local MOVE_SPEED = 1200
local JUMP_FORCE = 500
local GRAVITY = 600
local TURN_SPEED = 0.03      -- Vitesse de rotation (était 0.1, maintenant plus lent)
local ATTACK_YAW_OFFSET = 90 -- essaye 90, sinon -90 si c'est de l'autre côté
local ATTACK_WINDUP    = 0.3   
local ATTACK_DURATION  = 1.0   
local ATTACK_RECOVERY  = 0.9  
local DEBUG_DRAW_TIME  = 0.08
local HIT_TICK = 0.25 -- touche la même cible toutes les 0.25s (à régler)


function ENT:Initialize()
    self:SetModel("models/salamandre/salamandre.mdl")
    self:SetModelScale(1.5, 0)

    self:SetSolid(SOLID_BBOX)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionBounds(Vector(-40, -40, 0), Vector(40, 40, 60))

    -- PAS de physics automatique - on gère tout manuellement
    self:SetMoveType(MOVETYPE_NONE)

    -- Variables
    self.Rider = nil
    self.IsMoving = false
    self.IsAttacking = false
    self.Velocity = Vector(0, 0, 0)
    self.OnGround = true
    self.LastJump = 0
    self.LastDebug = 0
    self.IsSpawning = true

    -- Animations
    print("[Salamandre] === ANIMATIONS DISPONIBLES ===")
    local seqs = self:GetSequenceList()
    for i, name in ipairs(seqs) do
        print("[Salamandre] " .. (i - 1) .. ": " .. name)
    end
    print("[Salamandre] ==============================")

    self.Anims = {
        idle = self:FindAnim({ "idle", "Idle", "IDLE", "stand", "Stand" }),
        walk = self:FindAnim({ "walk", "Walk", "WALK", "run", "Run", "move", "Move" }),
        attack = self:FindAnim({ "attack", "Attack", "ATTACK", "bite", "Bite", "attack1", "Attack1" }),
        spawn = self:LookupSequence("beaten_down")
    }

    -- Jouer l'animation de spawn
    if self.Anims.spawn and self.Anims.spawn >= 0 then
        self:ResetSequence(self.Anims.spawn)
        self:SetPlaybackRate(1)

        -- Durée de l'animation
        local spawnDuration = self:SequenceDuration(self.Anims.spawn)
        timer.Simple(spawnDuration, function()
            if not IsValid(self) then return end
            self.IsSpawning = false
            self:PlayAnimation("idle")
        end)
    else
        self.IsSpawning = false
        if self.Anims.idle >= 0 then
            self:ResetSequence(self.Anims.idle)
        else
            self:ResetSequence(0)
        end
    end

    self:SetPlaybackRate(1)
    print("[Salamandre] Initialisé! idle:" ..
    self.Anims.idle .. " walk:" .. self.Anims.walk .. " attack:" .. self.Anims.attack)
end

function ENT:FindAnim(names)
    for _, name in ipairs(names) do
        local seq = self:LookupSequence(name)
        if seq and seq >= 0 then
            return seq
        end
    end
    return -1
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() or not activator:Alive() then return end
    -- évite monter + descendre sur le même appui de E
    if (self.NextRideToggle or 0) > CurTime() then return end

    -- Bloquer si en train de spawn
    if self.IsSpawning then
        activator:ChatPrint("La salamandre se réveille...")
        return
    end

    local currentRider = self:GetNWEntity("Rider")

    if IsValid(currentRider) then
        if currentRider == activator then
            self:Dismount(activator)
        else
            activator:ChatPrint("Cette salamandre est déjà montée!")
        end
    else
        self:Mount(activator)
    end
end

function ENT:Mount(ply)
    if not IsValid(ply) then return end

    self.Rider = ply
    self:SetNWEntity("Rider", ply)
    self.NextRideToggle = CurTime() + 0.5
    self.OriginalScale = ply:GetModelScale()

    -- Aligner le joueur avec la salamandre (le joueur regarde dans la même direction)
    local salamandreYaw = self:GetAngles().y
    ply:SetEyeAngles(Angle(0, salamandreYaw, 0))

    -- Attacher le joueur au bone Spine
    local spineBone = self:LookupBone("Spine1")
    print("[Salamandre] Bone Spine: " .. tostring(spineBone))

    ply:SetParent(self)

    if spineBone then
        ply:SetParentPhysNum(spineBone)
    end

    ply:SetLocalPos(Vector(-30, 0, 60)) -- Ajuste si besoin
    ply:SetLocalAngles(Angle(0, 0, 0))
    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetNoDraw(false)
    ply:SetCollisionGroup(COLLISION_GROUP_PASSABLE_DOOR)

    ply:ChatPrint("Monté! ZQSD pour bouger, ESPACE pour sauter, CLIC pour attaquer, E pour descendre")
end

function ENT:Dismount(ply)
    if not IsValid(ply) then return end

    -- sortie sur le côté, sinon derrière / devant / au-dessus (jamais dans un mur)
    local exitPos = self:GetPos() + Vector(0, 0, 80)
    for _, offset in ipairs({ self:GetRight() * 60, -self:GetRight() * 60, -self:GetForward() * 80, self:GetForward() * 80 }) do
        local test = self:GetPos() + offset + Vector(0, 0, 10)
        local tr = util.TraceHull({ start = test, endpos = test, mins = Vector(-16, -16, 0), maxs = Vector(16, 16, 72),
            mask = MASK_PLAYERSOLID, filter = { self, ply } })
        if not tr.Hit then
            exitPos = test
            break
        end
    end

    ply:SetParent(nil)
    ply:SetPos(exitPos)
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    ply:SetModelScale(self.OriginalScale or 1, 0)
    ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
    ply:SetSequence(0)

    self.Rider = nil
    self:SetNWEntity("Rider", NULL)
    self.NextRideToggle = CurTime() + 0.5
    self:PlayAnimation("idle")

    ply:ChatPrint("Descendu de la salamandre!")
end

function ENT:PlayAnimation(name)
    local seq = self.Anims[name] or self:LookupSequence(name) or -1

    if seq >= 0 then
        self:ResetSequence(seq)
        self:SetPlaybackRate(1)
        self:SetCycle(0)
        return true
    end
    return false
end

function ENT:Think()
    local rider = self:GetNWEntity("Rider")
    local dt = FrameTime()
    if self.AttackHitStart and CurTime() >= self.AttackHitStart and CurTime() <= self.AttackHitEnd then
        self:UpdateAttackHitbox(rider)
    end

    -- Pendant le spawn, juste jouer l'animation + gravité
    if self.IsSpawning then
        self.Velocity.z = self.Velocity.z - GRAVITY * dt
        self:ApplyMovement(dt)
        self:FrameAdvance(dt)
        self:NextThink(CurTime())
        return true
    end

    if IsValid(rider) and rider:IsPlayer() then
        -- cavalier mort : on le fait descendre
        if not rider:Alive() then
            self:Dismount(rider)
            self:NextThink(CurTime())
            return true
        end

        -- Vérifier si le rider veut descendre (touche E)
        if rider:KeyPressed(IN_USE) and (self.NextRideToggle or 0) <= CurTime() then
            self:Dismount(rider)
            return true
        end

        self:HandleMovement(rider, dt)
        self:HandleAttack(rider)
    else
        -- Gravité quand pas de rider
        self.Velocity.z = self.Velocity.z - GRAVITY * dt
        self:ApplyMovement(dt)

        if not self.IsAttacking then
            self:PlayAnimation("idle")
        end
    end

    self:FrameAdvance(dt)
    self:NextThink(CurTime())
    return true
end

function ENT:HandleMovement(rider, dt)
    local moving = false

    -- DEBUG: Afficher la zone d'attaque attachée au bone Spine
    local spineBone = self:LookupBone("Spine1")
    local attackPos

    if spineBone then
        local bonePos, boneAng = self:GetBonePosition(spineBone)
        -- Position du bone mais direction de la salamandre
        local forward = self:GetForward()
        attackPos = bonePos + forward * 80
    else
        -- Fallback si pas de bone
        attackPos = self:GetPos() + self:GetForward() * 120
    end

    local attackRadius = 60
    local attackAng = self:GetAngles()
    --debugoverlay.BoxAngles(attackPos, Vector(-attackRadius, -attackRadius, -attackRadius), Vector(attackRadius, attackRadius, attackRadius), attackAng, 0.05, Color(255, 0, 0, 50))
    --debugoverlay.Cross(attackPos, 10, 0.05, Color(255, 255, 0), true)

    -- Rotation vers où regarde le joueur (PLUS LENTE)
    local eyeAng = rider:EyeAngles()
    local currentAng = self:GetAngles()
    local diff = math.AngleDifference(eyeAng.y, currentAng.y)

    if math.abs(diff) > 5 then
        local newYaw = currentAng.y + diff * TURN_SPEED -- Utilise la constante TURN_SPEED
        self:SetAngles(Angle(0, newYaw, 0))
    end

    -- Mouvement horizontal
    local moveDir = Vector(0, 0, 0)

    if rider:KeyDown(IN_FORWARD) then
        moveDir = moveDir + self:GetForward()
        moving = true
    end
    if rider:KeyDown(IN_BACK) then
        moveDir = moveDir - self:GetForward() * 0.5
        moving = true
    end
    if rider:KeyDown(IN_MOVELEFT) then
        moveDir = moveDir - self:GetRight() * 0.7
        moving = true
    end
    if rider:KeyDown(IN_MOVERIGHT) then
        moveDir = moveDir + self:GetRight() * 0.7
        moving = true
    end

    -- Calculer la nouvelle vélocité horizontale
    if moving then
        moveDir:Normalize()
        self.Velocity.x = moveDir.x * MOVE_SPEED
        self.Velocity.y = moveDir.y * MOVE_SPEED
    else
        -- Friction
        self.Velocity.x = self.Velocity.x * 0.8
        self.Velocity.y = self.Velocity.y * 0.8
    end

    -- TOUJOURS appliquer la gravité
    self.Velocity.z = self.Velocity.z - GRAVITY * dt

    -- Saut (avec cooldown) - seulement si au sol
    if self.OnGround and rider:KeyDown(IN_JUMP) and CurTime() > self.LastJump + 0.5 then
        self.Velocity.z = JUMP_FORCE
        self.LastJump = CurTime()
      
    end

    -- Debug
    if math.floor(CurTime() * 2) ~= self.LastDebug then
        self.LastDebug = math.floor(CurTime() * 2)
       
    end

    -- Appliquer le mouvement ET détecter le sol
    self:ApplyMovement(dt)

    -- Animations
    if not self.IsAttacking then
        if moving then
            if not self.IsMoving then
                self:PlayAnimation("walk")
                self.IsMoving = true
            end
        else
            if self.IsMoving then
                self:PlayAnimation("idle")
                self.IsMoving = false
            end
        end
    end
end

function ENT:ApplyMovement(dt)
    local pos = self:GetPos()
    local vel = self.Velocity
    local rider = self:GetNWEntity("Rider")

    -- Filtre: ignorer la salamandre ET le rider
    local filter = { self }
    if IsValid(rider) then
        table.insert(filter, rider)
    end

    

    -- Trace pour le mouvement horizontal
    local moveTrace = util.TraceHull({
        start = pos,
        endpos = pos + Vector(vel.x, vel.y, 0) * dt,
        mins = Vector(-35, -35, 0),
        maxs = Vector(35, 35, 55),
        filter = filter
    })

    if not moveTrace.Hit then
        pos = moveTrace.HitPos
    else
        
        self.Velocity.x = 0
        self.Velocity.y = 0
    end

    -- Trace pour le mouvement vertical
    local vertMove = vel.z * dt
    local vertTrace = util.TraceHull({
        start = pos,
        endpos = pos + Vector(0, 0, vertMove),
        mins = Vector(-35, -35, 0),
        maxs = Vector(35, 35, 55),
        filter = filter
    })

    if not vertTrace.Hit then
        pos = vertTrace.HitPos
        self.OnGround = false
    else
        pos = vertTrace.HitPos
        if vel.z <= 0 then
            self.OnGround = true
            self.Velocity.z = 0
        else
            self.Velocity.z = 0
        end
    end

   
    self:SetPos(pos)
end

function ENT:UpdateAttackHitbox(attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    if self:GetNWEntity("Rider") ~= attacker then return end

    local dir = attacker:EyeAngles():Forward()
    dir.z = 0
    dir:Normalize()

    local startPos     = attacker:GetPos() + Vector(0, 0, 40)

    local forwardDist  = 250
    local attackRadius = 100
    local attackPos    = startPos + dir * forwardDist

    local boxHalf      = Vector(attackRadius, attackRadius, attackRadius)

    -- ✅ HITBOX VISIBLE (redessinée en continu)
    --debugoverlay.Box(attackPos, -boxHalf, boxHalf, DEBUG_DRAW_TIME, Color(255, 0, 0, 60))

    -- ✅ Re-hit: cooldown par entité
    self._NextHitTime = self._NextHitTime or {}

    local now = CurTime()
    local nearby = ents.FindInSphere(attackPos, attackRadius)
    for _, ent in ipairs(nearby) do
        if not IsValid(ent) then continue end
        if ent == self or ent == attacker then continue end
        if not (ent:IsPlayer() or ent:IsNPC() or ent:GetClass() == "prop_physics") then continue end

        local nextT = self._NextHitTime[ent] or 0
        if now < nextT then continue end
        self._NextHitTime[ent] = now + HIT_TICK

        local dmg = DamageInfo()
        dmg:SetDamage(25)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetAttacker(attacker)
        dmg:SetInflictor(self)
        dmg:SetDamageForce(dir * 6000)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
    end
end

function ENT:HandleAttack(rider)
    if not IsValid(rider) or not rider:IsPlayer() then return end
    if self:GetNWEntity("Rider") ~= rider then return end
    if self.IsSpawning or self.IsAttacking then return end
    if not rider:KeyPressed(IN_ATTACK) then return end

    self.IsAttacking = true
    self:PlayAnimation("attack")

    -- Particules
    local particleEnt = ents.Create("info_particle_system")
    if IsValid(particleEnt) then
        particleEnt:SetPos(self:GetPos() + Vector(0, 0, 10))
        particleEnt:SetAngles(self:GetAngles())
        particleEnt:SetParent(self)
        particleEnt:Spawn()
        ParticleEffectAttach("poison_jet", PATTACH_ABSORIGIN_FOLLOW, particleEnt, 0)
        self.ParticleEnt = particleEnt
    end

    -- ✅ Fenêtre d'attaque plus longue
    self.AttackHitStart = CurTime() + ATTACK_WINDUP
    self.AttackHitEnd   = self.AttackHitStart + ATTACK_DURATION
    self._NextHitTime = {}


    -- ✅ Durée totale lock = windup + duration + recovery
    timer.Simple(ATTACK_WINDUP + ATTACK_DURATION + ATTACK_RECOVERY, function()
        if not IsValid(self) then return end
        self.IsAttacking    = false
        self.AttackHitStart = nil
        self.AttackHitEnd   = nil

        self:StopParticles()
        if IsValid(self.ParticleEnt) then
            self.ParticleEnt:Remove()
            self.ParticleEnt = nil
        end

        if self.IsMoving then self:PlayAnimation("walk") else self:PlayAnimation("idle") end
    end)
end

function ENT:OnRemove()
    local rider = self:GetNWEntity("Rider")
    if IsValid(rider) then
        rider:SetParent(nil)
        rider:SetMoveType(MOVETYPE_WALK)
        rider:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    end
end
