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
local HULL_TAILLE = 40   -- demi-taille de la hitbox de visée (par niveau : "hitbox" dans _na_niveaux_techniques.lua)

-- scale
local baseScale = 8
local stepScale = 4

-- stun
local STUN_TIME = 4.0

-- mudras
local DUREE_MUDRA = 0.6   -- incantation avant que les arches tombent (la cible est revisée à la fin)
local ANIM_MUDRA  = "nrp_ninjutsu_defend_dragonflamebombs_start"

-- damage
local DAMAGE_AMOUNT = 20
local DAMAGE_RADIUS = 120

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "mokuton_arche", stat, base) end

-- mode développeur (developer 1) : hitbox de visée, zone de dégâts et arche affichées
local function Dev() return GetConVar("developer"):GetInt() > 0 end

local FX_CHUTE = "kenjutsu_zone_pat"   -- jouée quand une arche touche le sol (particles/patlick_atgparticules.pcf)

if SERVER then
    resource.AddFile("sound/mokuton/wood3.wav")
    PrecacheParticleSystem("hit_2_arche")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    game.AddParticles("particles/patlick_atgparticules.pcf")
    PrecacheParticleSystem(FX_CHUTE)
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
-- Targeting (comme le Cube Jinton)
-- =========================================
local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Valeurs lues par le client pour afficher la hitbox en mode développeur (cl : mokuton_arche_cl.lua)
SetGlobal2Float("NA_MokutonArchePortee", TRACE_RANGE)
SetGlobal2Float("NA_MokutonArcheVisee", HULL_TAILLE)

-- Ennemi visé : une boîte (hitbox de visée) est lancée depuis les yeux le long du regard,
-- jusqu'au premier mur (ou portée). Parmi TOUT ce qu'elle traverse, on prend la cible valable
-- la plus proche : un objet quelconque devant la cible (prop, entité invisible...) ne la cache plus.
local function GetLookTarget(ply)
    if not IsValid(ply) then return end

    local oeil = ply:EyePos()
    local hb   = NA_Stat(ply, "mokuton_arche", "hitbox", HULL_TAILLE)   -- hitbox par niveau
    local t    = Vector(hb, hb, hb)

    -- la boîte s'arrête au premier mur, mesuré avec un simple RAYON : avec une boîte, le sol la coupait
    -- très tôt dès qu'on visait bas (bassin, jambes) et la cible n'était plus dans la zone de visée
    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * Niv(ply, "trace_range", TRACE_RANGE),
        mask = MASK_SOLID_BRUSHONLY,
    })
    local fin = mur.HitPos

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, fin, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end

    -- mode développeur : la hitbox reste affichée 2 s à chaque lancement
    if Dev() then
        local couleur = cible and Color(0, 255, 0, 40) or Color(255, 60, 60, 40)
        debugoverlay.SweptBox(oeil, fin, -t, t, angle_zero, 2, couleur)
        if cible then debugoverlay.Box(cible:GetPos(), cible:OBBMins(), cible:OBBMaxs(), 2, Color(0, 255, 0, 60)) end
    end

    return cible
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

    -- snapshot MoveType (pas si la cible est déjà étourdie : on garderait MOVETYPE_NONE et elle resterait figée)
    if ent._mokuton_oldMoveType == nil then ent._mokuton_oldMoveType = ent:GetMoveType() end

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
        if ent._mokuton_oldAI == nil then ent._mokuton_oldAI = ent:IsAIEnabled() end
        ent:SetAIEnabled(false)
    end

    if ent.ClearSchedule then ent:ClearSchedule() end
    if ent.SetSchedule then ent:SetSchedule(SCHED_NONE) end
    if ent.StopMoving then ent:StopMoving() end

    if ent.loco then
        if ent._mokuton_oldSpeed == nil then ent._mokuton_oldSpeed = ent.loco:GetDesiredSpeed() end
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
    dmg:SetDamage(NA_Stat(attacker, "mokuton_arche", "degats", DAMAGE_AMOUNT))
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetDamagePosition(pos)

    if IsValid(attacker) then dmg:SetAttacker(attacker) end
    if IsValid(inflictor) then dmg:SetInflictor(inflictor) end

    local rayon = Niv(attacker, "damage_radius", DAMAGE_RADIUS)
    if Dev() then debugoverlay.Sphere(pos, rayon, 3, Color(255, 60, 60, 25), true) end   -- zone de dégâts

    for _, e in ipairs(ents.FindInSphere(pos, rayon)) do
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

    local startPos = groundPos + Vector(0,0,Niv(ply, "height", HEIGHT))

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

        local frac = (CurTime() - t0) / Niv(ply, "drop_time", DROP_TIME)
        if frac >= 1 then
            ent:SetPos(groundPos)

            DoImpactDamage(ply, ent, groundPos)
            if Dev() then
                local mins, maxs = ent:WorldSpaceAABB()
                debugoverlay.Box(vector_origin, mins, maxs, 3, Color(0, 150, 255, 40))   -- l'arche elle-même
            end
            ParticleEffect(FX_CHUTE, groundPos, angle_zero)

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

-- Fait tomber les arches sur la cible (après les mudras)
local function LancerArches(ply, target)
    do
        -- stun la cible
        StunEntity(target, Niv(ply, "stun_time", STUN_TIME))

        local center  = target:WorldSpaceCenter()
        local groundZ = GetWorldGroundZ(center)
        local right   = ply:EyeAngles():Right()

        local spawnedArches = {}

        for i = 1, Niv(ply, "count", COUNT) do
            timer.Simple((i - 1) * Niv(ply, "delay", DELAY), function()
                if not IsValid(ply) then return end

                local offset = (i - 2) * Niv(ply, "gap", GAP)
                local pos = center + right * offset
                pos = Vector(pos.x, pos.y, groundZ)

                local arch = SpawnMokutonArcheOnPos(ply, i, pos)
                if IsValid(arch) then
                    table.insert(spawnedArches, arch)
                end
            end)
        end

        -- suppression après stun
        timer.Simple(Niv(ply, "stun_time", STUN_TIME), function()
            for _, arch in ipairs(spawnedArches) do
                if IsValid(arch) then arch:Remove() end
            end
        end)
    end
end

-- =========================================
-- Network receive (SERVER)
-- =========================================
if SERVER then
    net.Receive("KSpawn_Request", function(_, ply)
        if not NA_Debloquee(ply, "mokuton_arche") then return end   -- technique pas encore débloquée (F6)
        if not IsValid(ply) or not ply:Alive() then return end

        ply._kspawn_next = ply._kspawn_next or 0
        if ply._kspawn_next > CurTime() then return end

        local target = GetLookTarget(ply)
        if not IsValid(target) then return end   -- pas de cible : rien ne se lance, pas de recharge

        ply._kspawn_next = CurTime() + NA_Stat(ply, "mokuton_arche", "recharge", COOLDOWN)
        if NA_CD then NA_CD.Set(ply, "mokuton_arche", NA_Stat(ply, "mokuton_arche", "recharge", COOLDOWN)) end -- recharge visible dans la barre

        -- mudras, puis les arches tombent sur la cible visée à la fin (à défaut, celle du début)
        local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
        NA_AnimJutsu(ply, ANIM_MUDRA)   -- animation + pas de coups pendant (_na_mudra.lua)
        ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
        if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

        timer.Simple(mudra, function()
            if not IsValid(ply) or not ply:Alive() then return end
            local cible = GetLookTarget(ply)
            if not IsValid(cible) then cible = target end
            if not IsValid(cible) then return end
            LancerArches(ply, cible)
        end)
    end)
end

-- Mort ou réapparition pendant l'étourdissement : la victime est libérée (sinon elle pouvait rester gelée)
local function Liberer(ply)
    if not ply._mokuton_stun_until then return end
    timer.Remove("mokuton_stun_" .. ply:EntIndex())
    ply._mokuton_stun_until = nil
    ply._mokuton_stun_ang   = nil
    ply:Freeze(false)
    ply:SetNW2Bool("NA_Etourdi", false)
    ply._mokuton_oldMoveType = nil
end
hook.Add("PlayerDeath", "Mokuton_LibererMort", Liberer)
hook.Add("PlayerSpawn", "Mokuton_LibererSpawn", Liberer)
