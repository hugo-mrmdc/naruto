local NET_FIRE = "naruto_dev_uchih1"
local NET_POS  = "naruto_dev_uchih1_pos"

util.AddNetworkString(NET_FIRE)
util.AddNetworkString(NET_POS)

print("[KATON PATCH] Loaded (pos sync)")

-- (ne pas retirer ici le hook de sv_bouledefeut.lua : la boule de feu N ne bougeait plus)
hook.Remove("Think", "naruto_dev_uchih1_projectiles_move")

local COOLDOWN    = 1.0
local nextUse     = {}
local SPEED       = 1600
local LIFE        = 2.5
local HIT_RADIUS  = 18

local Projectiles = {}
local projId      = 0
hook.Add("EntityTakeDamage", "Katon_NoFallDamage", function(ent, dmg)
    if not ent:IsPlayer() then return end
    if not ent._katonNoFallDamage then return end

    if dmg:IsFallDamage() then
        dmg:SetDamage(0)
        dmg:ScaleDamage(0)

        -- enlève le flag juste après
        timer.Simple(0, function()
            if IsValid(ent) then
                ent._katonNoFallDamage = nil
            end
        end)

        return true
    end
end)
hook.Add("OnPlayerHitGround", "Katon_NoFallSound", function(ply, inWater, onFloater, speed)
    if not IsValid(ply) then return end
    if not ply._katonNoFallDamage then return end

    -- Supprime le son de chute
    return true
end)


local function DoJumpBoost(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply._katonFrozen then return end

    -- Jump
    ply:SetVelocity(Vector(0, 0, 600))

    local oldMove = ply:GetMoveType()
    local oldGrav = ply:GetGravity()

    -- Flag anti dégâts de chute (retiré au plus tard après 5 s)
    ply._katonNoFallDamage = true
    timer.Create("KatonNoFall_" .. ply:EntIndex(), 5, 1, function()
        if IsValid(ply) then ply._katonNoFallDamage = nil end
    end)

    timer.Simple(1, function()
        if not IsValid(ply) or not ply:Alive() then return end

        ply._katonFrozen = true

        -- Fige en l'air
        ply:SetGravity(0)
        ply:SetMoveType(MOVETYPE_NONE)

        timer.Simple(0.7, function()
            if not IsValid(ply) then return end

            -- Restore (MOVETYPE_WALK si l'ancien état était déjà figé)
            if oldMove == MOVETYPE_NONE then oldMove = MOVETYPE_WALK end
            ply:SetMoveType(oldMove)
            ply:SetGravity(oldGrav)

            -- On enlèvera le no-fall APRES l'atterrissage
            ply._katonFrozen = false
        end)
    end)
end



local function SpawnProjectile(ply)
    projId = projId % 65535 + 1
    local id = projId

    local ang = ply:EyeAngles()
    local dir = ang:Forward()
    local pos = ply:EyePos() + dir * 40

    Projectiles[id] = {
        owner = ply,
        dir   = dir,
        pos   = pos,
        dieAt = CurTime() + LIFE,
        alive = true
    }

    -- message "start" au client (id + position)
    net.Start(NET_POS)
    net.WriteUInt(id, 16)
    net.WriteBool(true)     -- start
    net.WriteVector(pos)
    net.WriteAngle(ang)
    net.Broadcast()
end

hook.Add("Think", "naruto_dev_uchih1_projectiles_move", function()
    local ft = FrameTime()
    if ft <= 0 then return end

    for id, p in pairs(Projectiles) do
        if CurTime() >= (p.dieAt or 0) or not p.alive or not IsValid(p.owner) then
            -- stop
            net.Start(NET_POS)
            net.WriteUInt(id, 16)
            net.WriteBool(false)     -- stop
            net.WriteVector(p.pos or vector_origin)
            net.WriteAngle(angle_zero)
            net.Broadcast()

            Projectiles[id] = nil
        else
            local from = p.pos
            local to   = from + (p.dir * SPEED * ft)

            local hb = NA_Stat(p.owner, "katon_saut", "hitbox", HIT_RADIUS)   -- hitbox par niveau
            local tr   = util.TraceHull({
                start  = from,
                endpos = to,
                mins   = Vector(-hb, -hb, -hb),
                maxs   = Vector(hb, hb, hb),
                filter = p.owner,
                mask   = MASK_SHOT
            })

            p.pos      = tr.HitPos

            -- update position (10x/sec environ)
            if (p._nextSend or 0) <= CurTime() then
                p._nextSend = CurTime() + 0.1
                net.Start(NET_POS)
                net.WriteUInt(id, 16)
                net.WriteBool(true)     -- update
                net.WriteVector(p.pos)
                net.WriteAngle(tr.HitNormal:Angle())
                net.Broadcast()
            end

            if tr.Hit then
                local hit = tr.Entity
                if IsValid(hit) then
                    local dmg = DamageInfo()
                    dmg:SetDamage(NA_Stat(p.owner, "katon_saut", "degats", 35))
                    dmg:SetDamageType(DMG_BURN)
                    dmg:SetAttacker(IsValid(p.owner) and p.owner or game.GetWorld())
                    dmg:SetInflictor(game.GetWorld())
                    dmg:SetDamagePosition(tr.HitPos)
                    hit:TakeDamageInfo(dmg)
                end
                p.alive = false
            end
        end
    end
end)

net.Receive(NET_FIRE, function(_, ply)
    if not NA_Debloquee(ply, "katon_saut") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

    local t = CurTime()
    nextUse[ply] = nextUse[ply] or 0
    if t < nextUse[ply] then return end
    nextUse[ply] = t + NA_Stat(ply, "katon_saut", "recharge", COOLDOWN)
    if NA_CD then NA_CD.Set(ply, "katon_saut", NA_Stat(ply, "katon_saut", "recharge", COOLDOWN)) end -- recharge visible dans la barre
    DoJumpBoost(ply)
    timer.Simple(1, function()
        if IsValid(ply) and ply:Alive() then
            SpawnProjectile(ply)
        end
    end)
end)
