local NET_SHARK = "shark_projectile_fire"
util.AddNetworkString(NET_SHARK)
-- Charge le PCF
game.AddParticles("particles/water_impact.pcf")
PrecacheParticleSystem("water_splash_01_refract")

local MODEL = "models/suiton/shark_solve_geams.mdl"

-- paramètres
local MAIN_SPEED   = 15
local SWARM_COUNT  = 10
local SWARM_RADIUS = 500
local SWARM_SPEED  = 15
local SWARM_HITBOX = 18
local SWARM_LIFE   = 1

local MID_RADIUS   = 40 -- distance au centre pour déclencher l'envol
local COOLDOWN     = 5  -- anti-spam côté serveur (avant, seul le client avait un cooldown)
local nextShark    = {}
util.AddNetworkString("Swarm_EndFX")

local function BroadcastEndFX(pos)
    net.Start("Swarm_EndFX")
    net.WriteVector(pos)
    net.Broadcast()
end

local function SpawnSwarmOnTarget(attacker, target)
    if not IsValid(attacker) or not IsValid(target) then return end
    if not (target:IsPlayer() or target:IsNPC()) then return end

    local center = target:WorldSpaceCenter()

    for i = 1, SWARM_COUNT do
        local ent = ents.Create("prop_dynamic")
        if not IsValid(ent) then continue end

        local a = (i / SWARM_COUNT) * math.pi * 2
        local offset = Vector(math.cos(a), math.sin(a), 0) * SWARM_RADIUS
        offset.z = math.random(-40, 60)

        ent:SetModel(MODEL)
        ent:SetPos(center + offset)
        ent:SetAngles((-offset):Angle())
        ent:SetOwner(attacker)
        ent:Spawn()

        ent._finishing  = false
        ent._finishEnd  = 0
        ent._alreadyHit = {} -- 👈 UNE FOIS PAR ENTITÉ

        local tname     = "SharkSwarmMove_" .. ent:EntIndex()

        timer.Create(tname, 0, 0, function()
            if not IsValid(ent) then
                timer.Remove(tname)
                return
            end

            -- 🔼 Phase finale : montée + destruction
            if ent._finishing then
                if CurTime() >= ent._finishEnd then
                    SafeRemoveEntity(ent)
                    timer.Remove(tname)
                    return
                end

                local up = Vector(0, 0, 1)
                ent:SetAngles(up:Angle())
                ent:SetPos(ent:GetPos() + up * (SWARM_SPEED * 0.5))
                return
            end

            if not IsValid(target) then
                SafeRemoveEntity(ent)
                timer.Remove(tname)
                return
            end

            local pos  = ent:GetPos()
            local tpos = target:WorldSpaceCenter()

            local dir  = (tpos - pos)
            local dist = dir:Length()

            -- 🎯 Arrivé au milieu → envol
            if dist <= MID_RADIUS then
                ent._finishing = true
                ent._finishEnd = CurTime() + 0.9
                return
            end

            dir:Normalize()
            ent:SetAngles(dir:Angle())

            local nextPos = pos + dir * SWARM_SPEED

            local tr = util.TraceHull({
                start  = pos,
                endpos = nextPos,
                mins   = Vector(-SWARM_HITBOX, -SWARM_HITBOX, -SWARM_HITBOX),
                maxs   = Vector(SWARM_HITBOX, SWARM_HITBOX, SWARM_HITBOX),
                mask   = MASK_SHOT_HULL,
                filter = function(e)
                    -- les requins ne se bloquent plus entre eux
                    return e ~= attacker and e ~= ent and e:GetOwner() ~= attacker
                end
            })

            if tr.Hit then
                local hitEnt = tr.Entity

                -- ❌ jamais toucher le lanceur
                if IsValid(hitEnt) and hitEnt == attacker then
                    ent:SetPos(tr.HitPos + dir * (SWARM_HITBOX + 2))
                    return
                end

                -- ✅ UNE SEULE FOIS par joueur/NPC
                if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
                    if not ent._alreadyHit[hitEnt] then
                        ent._alreadyHit[hitEnt] = true

                        local dmg = DamageInfo()
                        dmg:SetDamage(1)
                        dmg:SetAttacker(attacker)
                        dmg:SetInflictor(ent)
                        dmg:SetDamageType(DMG_SLASH)
                        dmg:SetDamagePosition(tr.HitPos)
                        hitEnt:TakeDamageInfo(dmg)
                    end
                end

                -- traverse tout
                ent:SetPos(tr.HitPos + dir * (SWARM_HITBOX + 2))
                return
            end

            ent:SetPos(nextPos)
        end)

        -- sécurité
        timer.Simple(SWARM_LIFE, function()
            if not IsValid(ent) then
                timer.Remove(tname)
                return
            end

            local pos = ent:GetPos()
            BroadcastEndFX(pos) -- ✅ demande aux clients de jouer l'effet

            SafeRemoveEntity(ent)
            timer.Remove(tname)
        end)
    end
end




net.Receive(NET_SHARK, function(_, ply)
    if not NA_Debloquee(ply, "suiton_requin") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if (nextShark[ply] or 0) > CurTime() then return end
    nextShark[ply] = CurTime() + NA_Stat(ply, "suiton_requin", "recharge", COOLDOWN)
    if NA_CD then NA_CD.Set(ply, "suiton_requin", NA_Stat(ply, "suiton_requin", "recharge", COOLDOWN)) end -- recharge visible dans la barre

    local proj = ents.Create("prop_dynamic")
    if not IsValid(proj) then return end

    proj:SetModel(MODEL)
    proj:SetPos(ply:GetShootPos() + ply:GetAimVector() * 40)
    proj:SetAngles(ply:EyeAngles())
    proj:SetOwner(ply)
    proj:Spawn()

    local dir = ply:GetAimVector():GetNormalized()
    local tname = "SharkMove_" .. proj:EntIndex()

    timer.Create(tname, 0, 0, function()
        if not IsValid(proj) then
            timer.Remove(tname)
            return
        end

        local startPos = proj:GetPos()
        local nextPos  = startPos + dir * MAIN_SPEED

        local tr       = util.TraceHull({
            start  = startPos,
            endpos = nextPos,
            mins   = Vector(-20, -20, -20),
            maxs   = Vector(20, 20, 20),
            mask   = MASK_SHOT_HULL,
            filter = function(ent)
                if ent == ply then return false end
                if ent == proj then return false end
                if ent:GetOwner() == ply then return false end
                return true
            end
        })

        if tr.Hit then
            local hitEnt = tr.Entity

            -- ✅ si ça touche player/npc => spawn 10 requins autour et ils foncent dessus
            if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) and hitEnt ~= ply then
                SpawnSwarmOnTarget(ply, hitEnt)
            end

            SafeRemoveEntity(proj)
            timer.Remove(tname)
            return
        end

        proj:SetPos(nextPos)
    end)

    timer.Simple(4, function()
        if IsValid(proj) then SafeRemoveEntity(proj) end
        timer.Remove(tname)
    end)
end)
