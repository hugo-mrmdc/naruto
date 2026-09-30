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

-- durée du saut : 1 = ancien rythme, 0.5 = deux fois plus rapide
-- (garder la même valeur que VITESSE dans client/uchiha/cl_uchiha_boule_saut.lua)
local VITESSE     = 1

-- secondes entre le saut et le départ de la boule (avant, 1 * VITESSE = 0.5 : trop tôt)
local DELAI_TIR   = 0.85

-- distance devant les yeux où la boule apparaît (avant : 40, trop près maintenant qu'elle est grosse)
local DISTANCE_DEPART = 90

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "katon_saut", stat, base) end

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

    -- Jump (le joueur n'est plus figé en l'air : il garde le contrôle pendant tout le saut)
    ply:SetVelocity(Vector(0, 0, 600))

    -- Flag anti dégâts de chute (retiré au plus tard après 5 s)
    ply._katonNoFallDamage = true
    timer.Create("KatonNoFall_" .. ply:EntIndex(), 5, 1, function()
        if IsValid(ply) then ply._katonNoFallDamage = nil end
    end)
end

local function SpawnProjectile(ply)
    projId = projId % 65535 + 1
    local id = projId

    local ang = ply:EyeAngles()
    local dir = ang:Forward()
    local pos = ply:EyePos() + dir * DISTANCE_DEPART

    Projectiles[id] = {
        owner = ply,
        dir   = dir,
        pos   = pos,
        dieAt = CurTime() + Niv(ply, "life", LIFE),
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
            net.WriteBool(p.hit == true)     -- touché (et non simple fin de vie) : explosion côté client
            net.Broadcast()

            Projectiles[id] = nil
        else
            local from = p.pos
            local to   = from + (p.dir * Niv(p.owner, "speed", SPEED) * ft)

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
                net.WriteAngle(p.dir:Angle())   -- orientée dans le sens du tir
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

                    NA_Bruler(hit, p.owner, NA_Stat(p.owner, "katon_saut", "brulure_duree", 4),
                        NA_Stat(p.owner, "katon_saut", "brulure_dps", 4))
                end
                p.alive = false
                p.hit   = true
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
    timer.Simple(DELAI_TIR, function()
        if IsValid(ply) and ply:Alive() then
            SpawnProjectile(ply)
        end
    end)
end)
