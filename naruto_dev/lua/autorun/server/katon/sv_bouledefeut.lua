local NET_FIRE = "naruto_dev_katon"
local NET_POS  = "naruto_dev_katon_pos"

util.AddNetworkString(NET_FIRE)
util.AddNetworkString(NET_POS)

print("[KATON PATCH] Loaded (pos sync)")

hook.Remove("Think", "naruto_dev_katon_projectiles_move")

local COOLDOWN = 1.0
local nextUse = {}

local SPEED = 1600
local LIFE  = 2.5
local HIT_RADIUS = 18

local Projectiles = {}
local projId = 0

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
        net.WriteBool(true)         -- start
        net.WriteVector(pos)
        net.WriteAngle(ang)
    net.Broadcast()

end

hook.Add("Think", "naruto_dev_katon_projectiles_move", function()
    local ft = FrameTime()
    if ft <= 0 then return end

    for id, p in pairs(Projectiles) do
        if CurTime() >= (p.dieAt or 0) or not p.alive or not IsValid(p.owner) then
            -- stop
            net.Start(NET_POS)
                net.WriteUInt(id, 16)
                net.WriteBool(false) -- stop
                net.WriteVector(p.pos or vector_origin)
                net.WriteAngle(angle_zero)
            net.Broadcast()

            Projectiles[id] = nil
        else
            local from = p.pos
            local to   = from + (p.dir * SPEED * ft)

            local tr = util.TraceHull({
                start  = from,
                endpos = to,
                mins   = Vector(-HIT_RADIUS, -HIT_RADIUS, -HIT_RADIUS),
                maxs   = Vector( HIT_RADIUS,  HIT_RADIUS,  HIT_RADIUS),
                filter = p.owner,
                mask   = MASK_SHOT
            })

            p.pos = tr.HitPos

            -- update position (10x/sec environ)
            if (p._nextSend or 0) <= CurTime() then
                p._nextSend = CurTime() + 0.1
                net.Start(NET_POS)
                    net.WriteUInt(id, 16)
                    net.WriteBool(true) -- update
                    net.WriteVector(p.pos)
                    net.WriteAngle(tr.HitNormal:Angle())
                net.Broadcast()
            end

            if tr.Hit then
                local hit = tr.Entity
                if IsValid(hit) then
                    local dmg = DamageInfo()
                    dmg:SetDamage(35)
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
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

    local t = CurTime()
    nextUse[ply] = nextUse[ply] or 0
    if t < nextUse[ply] then return end
    nextUse[ply] = t + COOLDOWN
    if NA_CD then NA_CD.Set(ply, "katon_boule", COOLDOWN) end -- recharge visible dans la barre

    SpawnProjectile(ply)
end)
