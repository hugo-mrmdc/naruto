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

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "katon_boule", stat, base) end

local Projectiles = {}
local projId = 0

-- Brûlure maison (partagée avec sv_uchiha_boule_saut.lua) : 1 tick de dégâts par seconde,
-- indépendante du statut "burn" du gamemode. Les brûlures se cumulent.
local burnId = 0
local NET_BURN = "naruto_dev_katon_burn"
util.AddNetworkString(NET_BURN)

function NA_Bruler(ent, owner, duree, dps)
    if not IsValid(ent) or not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then return end
    duree = math.floor(tonumber(duree) or 0)
    if duree < 1 then return end

    burnId = burnId + 1
    local id = "na_burn_" .. burnId   -- une brûlure = un timer : elles se cumulent (chaque touche en ajoute une)
    print("[KATON] brulure sur", ent, duree .. " s", dps .. " dps")   -- debug : à retirer une fois validé
    timer.Create(id, 1, duree, function()
        if not IsValid(ent) or ent:Health() <= 0 or (ent:IsPlayer() and not ent:Alive()) then
            timer.Remove(id)
            return
        end
        local dmg = DamageInfo()
        dmg:SetDamage(dps)
        dmg:SetDamageType(DMG_BURN)
        dmg:SetAttacker(IsValid(owner) and owner or game.GetWorld())
        dmg:SetInflictor(game.GetWorld())
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
    end)

    net.Start(NET_BURN)
        net.WriteEntity(ent)
        net.WriteFloat(duree)
    net.Broadcast()
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
        dieAt = CurTime() + Niv(ply, "life", LIFE),
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
                net.WriteBool(p.hit == true)   -- touché (et non simple fin de vie) : explosion côté client
            net.Broadcast()

            Projectiles[id] = nil
        else
            local from = p.pos
            local to   = from + (p.dir * Niv(p.owner, "speed", SPEED) * ft)

            local hb = NA_Stat(p.owner, "katon_boule", "hitbox", HIT_RADIUS)   -- hitbox par niveau
            local tr = util.TraceHull({
                start  = from,
                endpos = to,
                mins   = Vector(-hb, -hb, -hb),
                maxs   = Vector(hb, hb, hb),
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
                    dmg:SetDamage(NA_Stat(p.owner, "katon_boule", "degats", 35))
                    dmg:SetDamageType(DMG_BURN)
                    dmg:SetAttacker(IsValid(p.owner) and p.owner or game.GetWorld())
                    dmg:SetInflictor(game.GetWorld())
                    dmg:SetDamagePosition(tr.HitPos)
                    hit:TakeDamageInfo(dmg)

                    NA_Bruler(hit, p.owner, NA_Stat(p.owner, "katon_boule", "brulure_duree", 4),
                        NA_Stat(p.owner, "katon_boule", "brulure_dps", 4))
                end
                p.alive = false
                p.hit   = true
            end
        end
    end
end)

net.Receive(NET_FIRE, function(_, ply)
    NA_SonJutsu(ply)
    if not NA_Debloquee(ply, "katon_boule") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return end

    local t = CurTime()
    nextUse[ply] = nextUse[ply] or 0
    if t < nextUse[ply] then return end
    nextUse[ply] = t + NA_Stat(ply, "katon_boule", "recharge", COOLDOWN)
    if NA_CD then NA_CD.Set(ply, "katon_boule", NA_Stat(ply, "katon_boule", "recharge", COOLDOWN)) end -- recharge visible dans la barre

    SpawnProjectile(ply)
    if NA_Mudra then NA_Mudra(ply, 0.6) end   -- pas de coup entre deux boules de feu / juste après la dernière
end)
