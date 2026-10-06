--========================================================
-- Suiton : Requin d'eau (SERVEUR)
--
-- Un requin part dans la direction du regard. Dès qu'une cible (joueur, PNJ ou faux joueur) est devant lui, il se met
-- à la suivre. Quand il la touche : dégâts, la cible est projetée en l'air (bump, comme le Wind Ball Futon) puis
-- étourdie quelques instants (STUN), explosion d'eau (shark_explo_pat) et une nuée de requins fonce sur elle.
-- Le serveur décide de tout. Un seul hook Think déplace tous les requins (pas de timer par requin).
--
-- Réseau : "shark_projectile_fire" (client -> serveur), "Shark_HitFX" et "Swarm_EndFX" (serveur -> clients : particules)
--========================================================

local NET_TIR = "shark_projectile_fire"
util.AddNetworkString(NET_TIR)
util.AddNetworkString("Shark_HitFX")    -- le requin touche sa cible : shark_explo_pat
util.AddNetworkString("Swarm_EndFX")    -- un requin de la nuée disparaît : éclaboussure

game.AddParticles("particles/water_impact.pcf")
PrecacheParticleSystem("water_splash_01_refract")
resource.AddFile("particles/patlick_atgsuiton.pcf")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local MODELE        = "models/suiton/shark_solve_geams.mdl"

-- requin principal
local DEGATS        = 25    -- dégâts du requin principal quand il touche sa cible (la nuée en fait en plus : 1 par requin)
local RECUL         = 150  -- bump : vitesse horizontale donnée à la cible, dans le sens du requin (comme le Wind Ball)
local SOULEVE       = 120  -- bump : vitesse verticale
local STUN          = 1     -- secondes d'étourdissement, en l'air
local DELAI_STUN    = 0.3   -- le stun commence après ce délai : le temps que le bump la lance en l'air (le stun annule la vitesse)
local MAIN_SPEED    = 15    -- unités par tick serveur
local MAIN_VIE      = 4     -- secondes avant qu'il disparaisse sans rien toucher
local MAIN_HITBOX   = 20    -- demi-taille de sa zone de collision
local DEPART        = 40    -- distance de départ devant le lanceur
local DETECT_RADIUS = 450   -- distance à laquelle il repère une cible devant lui
local DETECT_DOT    = 0.2   -- la cible doit être devant lui (1 = pile devant, 0 = sur le côté)
local TURN_RATE     = 6     -- vitesse de braquage vers la cible (plus grand = vire plus sec)
local CONTACT       = 60    -- distance à laquelle il compte comme ayant touché sa cible

-- nuée
local SWARM_COUNT   = 10
local SWARM_RADIUS  = 250   -- distance de départ autour de la cible
local SWARM_SPEED   = 15
local SWARM_HITBOX  = 18
local SWARM_LIFE    = 1
local MID_RADIUS    = 40    -- distance au centre pour déclencher l'envol
local ENVOL         = 0.9   -- durée de l'envol final

local COOLDOWN      = 5
--========================================================

local ID = "suiton_requin"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local principaux = {}   -- requins lancés : { ent, ply, dir, mort, cible, recherche }
local essaim     = {}   -- requins de la nuée : { ent, ply, cible, hitbox, mort, fin, deja }
local prochain   = {}   -- joueur -> moment où il peut relancer

-- Cible valable : joueur vivant, PNJ vivant ou NextBot vivant (le faux joueur d'entraînement en est un), jamais le lanceur
local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- La cible valable la plus proche dans le rayon, et devant le requin (produit scalaire avec sa direction)
local function TrouverCible(lanceur, pos, dir, rayon)
    local meilleure, dMin = nil, math.huge
    for _, ent in ipairs(ents.FindInSphere(pos, rayon)) do
        if EstCible(ent, lanceur) then
            local vers = ent:WorldSpaceCenter() - pos
            local d = vers:LengthSqr()
            if d < dMin and vers:GetNormalized():Dot(dir) > DETECT_DOT then
                meilleure, dMin = ent, d
            end
        end
    end
    return meilleure
end

local function CreerRequin(pos, ang, lanceur)
    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end
    ent:SetModel(MODELE)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetOwner(lanceur)
    ent:Spawn()
    return ent
end

local function EnvoyerPos(nom, pos)
    net.Start(nom)
        net.WriteVector(pos)
    net.Broadcast()
end

-- Les requins ne se bloquent pas entre eux et ne touchent pas leur lanceur
local function FiltreRequin(ent, lanceur)
    return ent ~= lanceur and ent:GetOwner() ~= lanceur
end

--========================================================
-- Nuée
--========================================================
local function LancerEssaim(lanceur, cible)
    if not EstCible(cible, lanceur) then return end

    local centre = cible:WorldSpaceCenter()
    local nombre = Niv(lanceur, "swarm_count", SWARM_COUNT)
    local rayon  = Niv(lanceur, "swarm_radius", SWARM_RADIUS)
    local vie    = Niv(lanceur, "swarm_life", SWARM_LIFE)
    local hitbox = Niv(lanceur, "hitbox", SWARM_HITBOX)
    local now    = CurTime()

    for i = 1, nombre do
        local a = (i / nombre) * math.pi * 2
        local decalage = Vector(math.cos(a) * rayon, math.sin(a) * rayon, math.random(-40, 60))

        local ent = CreerRequin(centre + decalage, (-decalage):Angle(), lanceur)
        if ent then
            essaim[#essaim + 1] = {
                ent = ent, ply = lanceur, cible = cible, hitbox = hitbox,
                mort = now + vie, fin = 0, deja = {},
            }
        end
    end
end

-- Point du sol sous une position (jusqu'à 500 unités plus bas), sinon la position elle-même
local function Sol(pos)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 20), endpos = pos - Vector(0, 0, 500),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos or pos
end

-- Bump, comme le Wind Ball Futon : la cible est projetée dans le sens du requin et vers le haut.
local function Projeter(ent, dir, recul, souleve)
    local v = Vector(dir.x, dir.y, 0)
    v:Normalize()
    v = v * recul + Vector(0, 0, souleve)
    if ent.loco then
        ent.loco:SetVelocity(ent.loco:GetVelocity() + v)   -- NextBot (faux joueur)
    else
        if ent:IsPlayer() then ent:SetGroundEntity(NULL) end
        ent:SetVelocity(v)
    end
end

-- impact sur une cible : dégâts, explosion d'eau AU SOL sous la cible (chez tous les clients) + la nuée
local function ToucherCible(lanceur, cible, pos, dir)
    local dmg = DamageInfo()
    dmg:SetDamage(Niv(lanceur, "degats", DEGATS))
    dmg:SetAttacker(lanceur)
    dmg:SetInflictor(lanceur)
    dmg:SetDamageType(DMG_SLASH)
    dmg:SetDamagePosition(pos)
    cible:TakeDamageInfo(dmg)

    -- bump (projetée en l'air), puis étourdie EN L'AIR : l'étourdissement annule la vitesse, il commence donc un
    -- instant après le bump et la cible reste suspendue le temps du stun
    if cible:Health() > 0 then
        Projeter(cible, dir, Niv(lanceur, "recul", RECUL), Niv(lanceur, "souleve", SOULEVE))
        local stun = Niv(lanceur, "stun", STUN)
        if stun > 0 and NA_Etourdir then
            timer.Simple(DELAI_STUN, function()
                if EstCible(cible, lanceur) then NA_Etourdir(cible, stun) end   -- sv_etourdissement.lua
            end)
        end
    end

    LancerEssaim(lanceur, cible)
    EnvoyerPos("Shark_HitFX", Sol(cible:GetPos()))
end

-- Un requin de la nuée, un tick. Retourne false quand il doit disparaître.
local function MajEssaim(s, now, k)
    local ent = s.ent
    if not IsValid(ent) then return false end

    -- fin de vie (même pendant l'envol) : éclaboussure + disparition
    if now >= s.mort then
        EnvoyerPos("Swarm_EndFX", ent:GetPos())
        return false
    end

    -- envol final : il monte, puis disparaît
    if s.fin > 0 then
        if now >= s.fin then return false end
        ent:SetAngles(vector_up:Angle())
        ent:SetPos(ent:GetPos() + vector_up * (Niv(s.ply, "swarm_speed", SWARM_SPEED) * 0.5 * k))
        return true
    end

    if not IsValid(s.cible) then return false end

    local pos = ent:GetPos()
    local dir = s.cible:WorldSpaceCenter() - pos

    -- arrivé au milieu : envol
    if dir:Length() <= Niv(s.ply, "mid_radius", MID_RADIUS) then
        s.fin = now + ENVOL
        return true
    end

    dir:Normalize()
    ent:SetAngles(dir:Angle())

    local suivant = pos + dir * (Niv(s.ply, "swarm_speed", SWARM_SPEED) * k)
    local h = s.hitbox
    local tr = util.TraceHull({
        start = pos, endpos = suivant,
        mins = Vector(-h, -h, -h), maxs = Vector(h, h, h),
        mask = MASK_SHOT_HULL,
        filter = function(e) return e ~= ent and FiltreRequin(e, s.ply) end,
    })

    if not tr.Hit then
        ent:SetPos(suivant)
        return true
    end

    -- touche une cible : dégâts, UNE seule fois par cible (le lanceur n'est jamais touché)
    local touche = tr.Entity
    if EstCible(touche, s.ply) and not s.deja[touche] then
        s.deja[touche] = true
        local dmg = DamageInfo()
        dmg:SetDamage(1)
        dmg:SetAttacker(s.ply)
        dmg:SetInflictor(ent)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(tr.HitPos)
        touche:TakeDamageInfo(dmg)
    end

    -- il traverse tout
    ent:SetPos(tr.HitPos + dir * (h + 2))
    return true
end

--========================================================
-- Requin principal
--========================================================
-- Un tick. Retourne false quand il doit disparaître.
local function MajPrincipal(s, now, k)
    local ent, ply = s.ent, s.ply
    if not IsValid(ent) or not IsValid(ply) or now >= s.mort then return false end

    local pos = ent:GetPos()

    -- sans cible (ou si elle est morte), il en cherche une devant lui toutes les 0.1 s
    if not EstCible(s.cible, ply) and now >= s.recherche then
        s.recherche = now + 0.1
        s.cible = TrouverCible(ply, pos, s.dir, Niv(ply, "detect", DETECT_RADIUS))
    end

    -- avec une cible : il braque doucement vers elle, et il l'a touchée s'il arrive assez près
    local cible = s.cible
    if EstCible(cible, ply) then
        local centre = cible:WorldSpaceCenter()
        if pos:Distance(centre) <= CONTACT then
            ToucherCible(ply, cible, centre, s.dir)
            return false
        end
        local vers = centre - pos
        vers:Normalize()
        s.dir = LerpVector(math.min(TURN_RATE * FrameTime(), 1), s.dir, vers)
        s.dir:Normalize()
        ent:SetAngles(s.dir:Angle())
    end

    local suivant = pos + s.dir * (Niv(ply, "main_speed", MAIN_SPEED) * k)
    local h = MAIN_HITBOX
    local tr = util.TraceHull({
        start = pos, endpos = suivant,
        mins = Vector(-h, -h, -h), maxs = Vector(h, h, h),
        mask = MASK_SHOT_HULL,
        filter = function(e) return e ~= ent and FiltreRequin(e, ply) end,
    })

    if tr.Hit then
        if EstCible(tr.Entity, ply) then ToucherCible(ply, tr.Entity, tr.HitPos, s.dir) end
        return false
    end

    ent:SetPos(suivant)
    return true
end

--========================================================
-- Boucle unique : tous les requins, un tick
--========================================================
local function MajListe(liste, maj, now, k)
    for i = #liste, 1, -1 do
        local s = liste[i]
        if not maj(s, now, k) then
            SafeRemoveEntity(s.ent)
            table.remove(liste, i)
        end
    end
end

hook.Add("Think", "SuitonRequin_Maj", function()
    if #principaux == 0 and #essaim == 0 then return end
    -- les vitesses sont en unités PAR TICK : on les normalise pour que ça aille pareil quelle que soit la fluidité
    local k = math.Clamp(FrameTime() / engine.TickInterval(), 0, 4)
    local now = CurTime()
    MajListe(principaux, MajPrincipal, now, k)
    MajListe(essaim, MajEssaim, now, k)
end)

--========================================================
-- Lancement
--========================================================
net.Receive(NET_TIR, function(_, ply)
    NA_SonJutsu(ply)
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if (prochain[ply] or 0) > CurTime() then return end

    local recharge = Niv(ply, "recharge", COOLDOWN)
    prochain[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end   -- recharge visible dans la barre

    local dir = ply:GetAimVector():GetNormalized()
    local ent = CreerRequin(ply:GetShootPos() + dir * DEPART, ply:EyeAngles(), ply)
    if not ent then return end

    principaux[#principaux + 1] = {
        ent = ent, ply = ply, dir = dir,
        mort = CurTime() + MAIN_VIE, cible = nil, recherche = 0,
    }
end)

hook.Add("PlayerDisconnected", "SuitonRequin_Nettoyage", function(ply) prochain[ply] = nil end)
