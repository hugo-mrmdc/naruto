--========================================================
-- Inkuton Dragon d'encre (SV) : copie indépendante du dragon de bois (mokuton_dragon_sv.lua), seuls le modèle, l'animation, la taille et l'impact changent
-- - prop_dynamic + joueur sur le dos
-- - Animation "fly" jouée UNE FOIS
-- - Dragon NON solide / Joueur SOLIDE (ne traverse pas les murs)
-- - Pas de dégâts de chute pendant le ride
--========================================================

if not SERVER then return end

util.AddNetworkString("inkuton_dragon_spawn")
util.AddNetworkString("inkuton_dragon_impact_fx")

-- Particule jouée quand le dragon projectile touche le sol / un mur (particles/solve_doton.pcf).
-- Elle est créée par les clients (inkuton_dragon_cl.lua), qui la coupent au bout de 2 secondes.
local FX_IMPACT = "golem_encre_impact_pat"
resource.AddFile("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_IMPACT)

util.AddNetworkString("inkuton_dragon_kill")
util.AddNetworkString("inkuton_dragon_charge")
util.AddNetworkString("inkuton_dragon_grab") --
local MODEL                = "models/inkuton/dragoninkuton.mdl"
for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/inkuton/dragoninkuton." .. ext)
end
for _, f in ipairs(file.Find("materials/models/solve/billy/dragoninkuton/*", "GAME")) do
    resource.AddFile("materials/models/solve/billy/dragoninkuton/" .. f)
end

local SEQ                  = "CustomMan_Attack_SSp_Brushscroll_Dash_Loop_Dragon"

local SCALE                = 1.5   -- le modèle fait ~525 unités de long à 1
local ANIM_SPEED           = 1

-- Mouvement
local FLY_SPEED            = 1200
local FLY_UP_SPEED         = 700    -- montée (Espace) et descente (Ctrl) (avant : 900, trop brusque)
local TAKEOFF_BOOST        = 900    -- poussée du décollage depuis le sol (avant : 1200)

-- Rotation smoothing
local TURN_RATE            = 500
local PITCH_RATE           = 350    -- degrés/seconde : le nez monte / descend aussi vite qu'il tourne (avant : 150)
local PITCH_MIN, PITCH_MAX = -60, 60   -- inclinaison max : plus de marge pour monter et plonger (avant : -35, 35)

-- Charge (clic droit) : le dragon se détache de toi et FONCE comme un projectile dans la direction où tu regardes
local DASH_SPEED            = 2800   -- vitesse du dragon projectile (vol normal : FLY_SPEED)
local DASH_DUREE            = 1.2    -- secondes avant qu'il disparaisse (s'il ne touche aucun mur)
local DASH_RECHARGE         = 3      -- secondes avant de pouvoir le réinvoquer (depuis le lancement)
local DASH_PITCH_MAX        = 80     -- il peut être lancé presque tout droit vers le haut / le bas
local DASH_TAILLE_CHOC        = 45     -- demi-taille de la boîte qui détecte le sol / les murs (plus grand = il disparaît plus tôt)
local DASH_RAYON            = 130    -- rayon autour du dragon où il blesse (il est énorme)
local DASH_DEGATS           = 40     -- dégâts par personne touchée (une seule fois chacune)
local DASH_RECUL            = 700    -- projection de la personne touchée, dans le sens du dragon
local DASH_SOULEVE          = 250    -- projection vers le haut
-- Mudras avant l'apparition du dragon
local DUREE_MUDRA           = 1   -- durée des mudras : l'animation est COUPÉE à ce moment et le dragon arrive juste après
local ANIM_MUDRA            = "nrp_ninjutsu_defend_dragonflamebombs_start"
local DASH_DELAI            = 0.3    -- secondes entre le début de l'animation et le départ du dragon
local ANIM_DASH             = "nrp_ninjutsu_attack_aerial_woodendragon"   -- animation du joueur au lancement (nom réel dans anim_extension_mod6.mdl)

-- Position joueur
local PLAYER_OFFSET_FWD    = -5
local PLAYER_OFFSET_UP     = 15

-- Grab (E)
local GRAB_RANGE           = 260  -- distance "zone moyen" devant le joueur
local GRAB_CONE_DOT        = 0.75 -- ~41° de cône (1 = pile devant)
local GRAB_HULL            = 22   -- vérif anti-mur (évite grab à travers murs)

-- Position de la cible (dans la bouche du dragon)
local MOUTH_OFFSET_FWD     = 0
local MOUTH_OFFSET_UP      = 10
-- Os de la mâchoire : la cible est tenue là plutôt qu'au centre du dragon
local MOUTH_BONE           = "Jaw 01"   -- absent du dragon d'encre : la cible est alors tenue au centre (repli)

-- Précalculés une fois (avant : recréés à chaque grab / chaque déblocage)
local GRAB_RANGE_SQR       = GRAB_RANGE * GRAB_RANGE
local GRAB_MINS            = Vector(-GRAB_HULL, -GRAB_HULL, -GRAB_HULL)
local GRAB_MAXS            = Vector( GRAB_HULL,  GRAB_HULL,  GRAB_HULL)
local FREEPOS_OFFSETS      = {
    vector_origin,
    Vector(0, 0, 16),
    Vector(40, 0, 16), Vector(-40, 0, 16),
    Vector(0, 40, 16), Vector(0, -40, 16),
    Vector(0, 0, 72),
}

-- Protection contre les dégâts de chute après être descendu (le dragon vole haut)
local FALL_GRACE           = 6

local state                = {}
local nextRide             = {}

----------------------------------------------------------
-- Descente en sécurité : pas de mur, pas de dégâts de chute
----------------------------------------------------------
local function ProtectFall(ent)
    if IsValid(ent) then
        ent.InkutonNoFall = CurTime() + FALL_GRACE
    end
end

-- Cherche une position libre autour de pos (sinon renvoie pos tel quel)
local function FreePos(ent, pos)
    if not IsValid(ent) then return pos end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    for _, off in ipairs(FREEPOS_OFFSETS) do
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
        -- l'index de l'os est mis en cache sur le dragon (false = le modèle n'a pas cet os)
        local bone = dragon.InkutonMouthBone
        if bone == nil then
            bone = dragon:LookupBone(MOUTH_BONE) or false
            dragon.InkutonMouthBone = bone
        end
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

    -- 1) candidats : filtres BON MARCHÉ d'abord (type, état, portée, cône), sans aucun trace
    -- (avant : un trace d'anti-mur pour chaque candidat, et une cible invalide choisie en premier
    -- annulait tout, même s'il y en avait une valable derrière)
    local candidats = {}
    for _, ent in ipairs(ents.FindInSphere(eyePos, GRAB_RANGE)) do   -- portée limitée : pas toutes les entités de la map
        if ent == owner or ent == st.dragon then continue end
        if ent:IsPlayer() then
            if not ent:Alive() or ent:GetNWBool("InkutonRide", false) or ent:GetNWBool("InkutonGrabbed", false) then continue end
        elseif not ent:IsNPC() then
            continue
        end

        local targetPos = ent:WorldSpaceCenter()
        local to = targetPos - eyePos
        local distSqr = to:LengthSqr()
        if distSqr > GRAB_RANGE_SQR or distSqr < 1 then continue end
        if to:Dot(fwd) < GRAB_CONE_DOT * math.sqrt(distSqr) then continue end   -- même test que normaliser puis Dot

        candidats[#candidats + 1] = { ent = ent, pos = targetPos, distSqr = distSqr }
    end
    if #candidats == 0 then return end

    -- 2) le plus proche d'abord ; on s'arrête au premier qui n'est pas derrière un mur
    table.sort(candidats, function(a, b) return a.distSqr < b.distSqr end)

    local ent
    for _, c in ipairs(candidats) do
        local tr = util.TraceHull({
            start  = eyePos,
            endpos = c.pos,
            mins   = GRAB_MINS,
            maxs   = GRAB_MAXS,
            filter = { owner, st.dragon, c.ent },
            mask   = MASK_SHOT
        })
        if not tr.Hit then ent = c.ent break end
    end
    if not IsValid(ent) then return end

    -- Save old state + lock
    st.grabbed = ent
    st.grabbedOld = {
        move  = ent:GetMoveType(),
        solid = ent:GetSolid(),
        col   = ent:GetCollisionGroup(),
        grav  = ent:IsPlayer() and ent:GetGravity() or nil,
    }

    if ent:IsPlayer() then
        ent:SetNWBool("InkutonGrabbed", true)
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
        ent:SetNWBool("InkutonGrabbed", false)

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

        -- le dash en l'air est de nouveau disponible en descendant du dragon (sh_dash.lua : un seul dash par temps passé
        -- en l'air, remis à zéro en retouchant le sol ; le vol sur le dragon ne touche jamais le sol, donc un dash fait
        -- avant de monter le bloquait encore après)
        ply.NA_DashsEnLair = 0

        ply:SetNWBool("InkutonRide", false)
    end

    state[ply] = nil
end

----------------------------------------------------------
-- Start Ride
----------------------------------------------------------
-- Apparition du dragon et montée (après les mudras)
local function SpawnRide(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:GetNWBool("InkutonGrabbed", false) then return end
    StopRide(ply)

    if not util.IsValidModel(MODEL) then
        print("[INKUTON] modèle introuvable:", MODEL)
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
        toucheClic = ply:KeyDown(IN_ATTACK2),   -- touches déjà maintenues à l'invocation : pas d'action tout de suite
        toucheUse  = ply:KeyDown(IN_USE),
        veutCharge = false,
        veutGrab   = false,
    }

    -- Filtre du test anti-mur en vol : le dragon et le cavalier ne se bloquent pas eux-mêmes, et les
    -- joueurs / PNJ ne bloquent JAMAIS le vol (une personne lâchée restait dans le passage et arrêtait le dragon).
    -- Les murs et les objets bloquent toujours. Fonction : renvoie true pour ce qui doit bloquer.
    state[ply].filtre = function(e)
        return e ~= ply and e ~= dragon and not (e:IsPlayer() or e:IsNPC() or e:IsNextBot())
    end

    -- ✅ Joueur SOLIDE (il reste touchable par les balles) mais en groupe DEBRIS : il ne heurte NI les props NI les
    -- autres joueurs. Le cavalier est déplacé par SetPos à grande vitesse : avec le groupe PLAYER, son corps physique
    -- projetait les props et poussait les gens (propkill). Les murs le bloquent toujours (trace du vol).
    ply:SetSolid(SOLID_BBOX)
    ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS)

    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetNWBool("InkutonRide", true)
end

-- Invocation : mudras, puis le dragon apparaît et le joueur monte dessus
local function StartRide(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    -- une cible tenue dans la gueule ne peut pas invoquer son propre dragon
    if ply:GetNWBool("InkutonGrabbed", false) then return end
    if (nextRide[ply] or 0) > CurTime() then return end

    -- l'animation de mudras est coupée à la fin de la durée : le dragon arrive quand elle s'arrête
    local mudra = NA_Stat(ply, "inkuton_dragon", "duree_mudra", DUREE_MUDRA)
    nextRide[ply] = CurTime() + 1 + mudra   -- bloque aussi une deuxième invocation pendant les mudras
    if NA_CD then NA_CD.Set(ply, "inkuton_dragon", 1 + mudra) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_MUDRA, mudra)   -- animation coupée après "mudra" secondes + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    timer.Simple(mudra, function()
        if IsValid(ply) then SpawnRide(ply) end
    end)
end

----------------------------------------------------------
-- Touches en vol : lues dans le Think du vol (même source que Espace / Ctrl, qui marchent),
-- avec détection du front (une action par appui)
----------------------------------------------------------
-- Dragons projectiles en vol : dragon -> { owner, dir, fin, touches }
local projectiles = {}

-- Clic droit : le dragon se détache du cavalier et fonce comme un projectile dans la direction du regard.
-- Le joueur joue l'animation de lancement puis retombe (protégé contre la chute) ; le dragon blesse
-- une fois chaque personne qu'il traverse et s'arrête au premier mur.
-- Départ du dragon (appelé DASH_DELAI secondes après le début de l'animation)
local function Lancer(ply, st)
    local dragon = st.dragon
    if not IsValid(dragon) or state[ply] ~= st then return end   -- plus sur le dragon entre-temps

    ReleaseGrab(ply)   -- une personne tenue dans la gueule est lâchée (avant de détacher le dragon)

    local eye = ply:EyeAngles()
    local ang = Angle(math.Clamp(eye.p, -DASH_PITCH_MAX, DASH_PITCH_MAX), eye.y, 0)
    dragon:SetAngles(ang)

    local function stat(k, def) return NA_Stat(ply, "inkuton_dragon", k, def) end   -- valeurs de _na_niveaux_techniques.lua
    local duree = stat("duree", DASH_DUREE)
    local recharge = stat("recharge", DASH_RECHARGE)
    projectiles[dragon] = {
        owner = ply, dir = ang:Forward(), debut = CurTime(), fin = CurTime() + duree, touches = {},
        vitesse = stat("vitesse", DASH_SPEED), rayon = stat("rayon", DASH_RAYON), degats = stat("degats", DASH_DEGATS),
        recul = stat("recul", DASH_RECUL), souleve = stat("souleve", DASH_SOULEVE),
    }
    st.dragon = nil   -- il n'appartient plus au cavalier : StopRide ne le supprime pas

    StopRide(ply)     -- le joueur descend (position libre, pas de dégâts de chute)
    nextRide[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "inkuton_dragon", recharge) end   -- recharge visible dans la barre

    dragon:EmitSound("naruto_sound/jutsu/senju/senju3.wav", 95, 90)
end

-- Clic droit : l'animation démarre tout de suite, le dragon part un instant plus tard (DASH_DELAI).
-- Entre-temps le dragon reste sur place (voir la boucle du vol).
local function Charge(ply, st)
    if st.chargePrevue or not IsValid(st.dragon) then return end
    st.chargePrevue = true

    NA_AnimJutsu(ply, ANIM_DASH)   -- animation + pas de coups pendant (_na_mudra.lua)
    timer.Simple(DASH_DELAI, function()
        if IsValid(ply) then Lancer(ply, st) end
    end)
end

-- Touche E : attrape la personne devant toi, ou la lâche si tu en tiens une
local function BasculerGrab(ply, st)
    if IsValid(st.grabbed) then
        ReleaseGrab(ply)
    else
        TryGrab(ply)
    end
end

-- Lu à CHAQUE commande du joueur (pas seulement à chaque tick du serveur) : un clic très court est vu aussi,
-- il n'y a pas besoin de maintenir le bouton. Une action par appui (détection du front).
hook.Add("StartCommand", "InkutonDragon_Touches", function(ply, cmd)
    local st = state[ply]
    if not st then return end

    local clic = cmd:KeyDown(IN_ATTACK2)
    if clic and not st.toucheClic then st.veutCharge = true end
    st.toucheClic = clic

    local use = cmd:KeyDown(IN_USE)
    if use and not st.toucheUse then st.veutGrab = true end
    st.toucheUse = use
end)

----------------------------------------------------------
-- Mouvement dragon + joueur (anti-travers-murs)
----------------------------------------------------------
hook.Add("Think", "InkutonDragon_Move", function()
    if next(state) == nil then return end   -- personne ne vole : rien à faire

    -- même pas de temps pour tous les joueurs (avant : recalculé dans la boucle)
    local dt = FrameTime()
    if dt <= 0 then return end
    if dt > 0.05 then dt = 0.05 end

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

        -- clic droit = charge, E = attraper / lâcher : demandés par le hook StartCommand (un simple clic suffit)
        if st.veutCharge then
            st.veutCharge = false
            Charge(ply, st)
            continue   -- le dragon est parti, le cavalier est descendu : plus rien à faire pour lui ce tour-ci
        end
        if st.veutGrab then
            st.veutGrab = false
            BasculerGrab(ply, st)
        end

        if st.chargePrevue then continue end   -- animation de lancement en cours : le dragon attend sur place

        local eye = ply:EyeAngles()

        -- Rotation
        local targetYaw   = eye.y
        local targetPitch = math.Clamp(eye.p, PITCH_MIN, PITCH_MAX)

        st.yaw   = math.ApproachAngle(st.yaw, targetYaw, TURN_RATE * dt)
        st.pitch = math.ApproachAngle(st.pitch, targetPitch, PITCH_RATE * dt)

        -- Velocity
        local ang = Angle(st.pitch, st.yaw, 0)
        local fwd, up = ang:Forward(), ang:Up()   -- calculés une fois (avant : 3 fois Forward et 2 fois Up)
        local vel = fwd * NA_Stat(ply, "inkuton_dragon", "vitesse_vol", FLY_SPEED)

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
            + fwd * PLAYER_OFFSET_FWD
            + up  * PLAYER_OFFSET_UP

        -- ✅ Anti-travers-murs : trace hull (hitbox joueur)
        local tr = util.TraceHull({
            start  = ply:GetPos(),
            endpos = desiredPos,
            mins   = ply:OBBMins(),
            maxs   = ply:OBBMaxs(),
            filter = st.filtre,
            mask   = MASK_PLAYERSOLID
        })

        local finalPos = desiredPos
        if tr.Hit then
            finalPos = tr.HitPos + tr.HitNormal * 2
        end

        -- ✅ Dragon suit la position RÉELLE du joueur (weld behavior)
        local dragonPos =
            finalPos
            - fwd * PLAYER_OFFSET_FWD
            - up  * PLAYER_OFFSET_UP

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

----------------------------------------------------------
-- Dragons projectiles
----------------------------------------------------------
local function EstVivant(ent)
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

hook.Add("Think", "InkutonDragon_Projectiles", function()
    if next(projectiles) == nil then return end

    local dt = FrameTime()
    if dt <= 0 then return end
    if dt > 0.05 then dt = 0.05 end
    local now = CurTime()

    for dragon, p in pairs(projectiles) do
        if not IsValid(dragon) then
            projectiles[dragon] = nil
            continue
        end

        local from = dragon:GetPos()
        local to   = from + p.dir * p.vitesse * dt

        -- Le sol ou un mur détruit le dragon DÈS QU'IL LES TOUCHE (les personnes, elles, sont traversées et blessées).
        -- Le trace est une BOÎTE à la taille du corps du dragon (avant : un simple rayon au centre, qui laissait le
        -- dragon s'enfoncer dans le sol avant de le détecter). Elle part d'à hauteur du corps : l'origine du dragon est
        -- au niveau des pieds du cavalier. Un départ déjà dans le sol est ignoré.
        local haut = Vector(0, 0, DASH_TAILLE_CHOC + 10)
        local mur = util.TraceHull({
            start = from + haut, endpos = to + haut,
            mins = Vector(-DASH_TAILLE_CHOC, -DASH_TAILLE_CHOC, -DASH_TAILLE_CHOC),
            maxs = Vector(DASH_TAILLE_CHOC, DASH_TAILLE_CHOC, DASH_TAILLE_CHOC),
            mask = MASK_SOLID_BRUSHONLY,
        })
        local choc = mur.Hit and not mur.StartSolid
        if choc or now >= p.fin then
            if choc then
                dragon:EmitSound("naruto_sound/jutsu/senju/senju1.wav", 95, 80)

                -- la particule se joue AU SOL, sous le point d'impact (300 unités au plus ; sinon à l'impact)
                local sol = util.TraceLine({ start = mur.HitPos + Vector(0, 0, 10), endpos = mur.HitPos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
                net.Start("inkuton_dragon_impact_fx")
                    net.WriteVector(sol.Hit and sol.HitPos or mur.HitPos)
                net.Broadcast()
            end
            dragon:Remove()
            projectiles[dragon] = nil
            continue
        end
        dragon:SetPos(to)

        -- blesse chaque personne touchée, une seule fois
        for _, ent in ipairs(ents.FindInSphere(to, p.rayon)) do
            if ent == p.owner or ent == dragon or p.touches[ent] then continue end
            if not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) or not EstVivant(ent) then continue end
            p.touches[ent] = true

            local dmg = DamageInfo()
            dmg:SetDamage(p.degats)
            dmg:SetDamageType(DMG_CLUB)
            dmg:SetAttacker(IsValid(p.owner) and p.owner or dragon)
            dmg:SetInflictor(dragon)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            local vel = p.dir * p.recul + Vector(0, 0, p.souleve)
            if ent.loco then
                ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
            else
                ent:SetVelocity(vel)
            end
            ent:EmitSound("naruto_sound/jutsu/senju/senju2.wav", 85, math.random(85, 100))
        end
    end
end)

----------------------------------------------------------
-- Force idle joueur pendant le ride
----------------------------------------------------------
hook.Add("CalcMainActivity", "Inkuton_ForceIdle", function(ply)
    if ply:GetNWBool("InkutonRide", false) then
        return ACT_HL2MP_IDLE, -1
    end
end)

hook.Add("UpdateAnimation", "Inkuton_ForceIdle_Update", function(ply)
    if ply:GetNWBool("InkutonRide", false) then
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
    if ent:IsPlayer() and ent:GetNWBool("InkutonRide", false) then return true end
    return (ent.InkutonNoFall or 0) > CurTime()
end

hook.Add("GetFallDamage", "Inkuton_NoFallDamage", function(ply)
    if FallImmune(ply) then
        return 0
    end
end)

-- (optionnel mais safe)
hook.Add("EntityTakeDamage", "Inkuton_BlockFallDMG", function(ent, dmg)
    -- ce hook passe à CHAQUE dégât du serveur : on écarte d'abord ce qui n'est pas une chute (test le moins cher)
    if not (dmg:IsFallDamage() or dmg:GetDamageType() == DMG_FALL) then return end
    if FallImmune(ent) then
        dmg:SetDamage(0)
        dmg:ScaleDamage(0)
        return true
    end
end)

----------------------------------------------------------
-- Net
----------------------------------------------------------
net.Receive("inkuton_dragon_spawn", function(_, ply)
    if not NA_Debloquee(ply, "inkuton_dragon") then return end   -- technique pas encore débloquée (F6)
    StartRide(ply)
end)

-- Charge demandée par la barre de techniques : quand l'emplacement du dragon est sélectionné, le clic droit lance
-- la technique (cl_skillbar.lua) et ne devient JAMAIS un vrai IN_ATTACK2 : le serveur ne le voit pas au StartCommand.
net.Receive("inkuton_dragon_charge", function(_, ply)
    local st = state[ply]
    if st then Charge(ply, st) end
end)

net.Receive("inkuton_dragon_kill", function(_, ply)
    StopRide(ply)
end)

hook.Add("PlayerDisconnected", "InkutonDragon_Cleanup", function(ply)
    StopRide(ply)
    nextRide[ply] = nil
end)

hook.Add("PlayerDeath", "InkutonDragon_StopOnDeath", StopRide)

-- Réapparition d'une cible qui était dans la gueule : on oublie la prise sans la
-- téléporter (le joueur vient d'être placé à son point d'apparition).
hook.Add("PlayerSpawn", "InkutonDragon_FixSpawn", function(ply)
    for _, st in pairs(state) do
        if st.grabbed == ply then
            st.grabbed = nil
            st.grabbedOld = nil
        end
    end
    ply:SetNWBool("InkutonGrabbed", false)
end)
