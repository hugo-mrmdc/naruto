--========================================================
-- Jinton : Cubes lancés (SERVEUR)
--
-- Un cube apparaît là où le lanceur regarde (ou à la portée max) et grandit sur place : tout joueur / PNJ dans son
-- volume prend de gros dégâts. Le cube lui-même est l'entité jinton_cubes_proj
-- (lua/entities/jinton_cubes_proj.lua).
--========================================================

if not SERVER then return end

util.AddNetworkString("jinton_cubes_cast")
util.AddNetworkString("jinton_cubes_sol")   -- impact au sol quand le cube a fini de grandir (cl_jinton_cubes.lua)

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 900    -- distance maximale à laquelle le cube peut apparaître (comme le cristal Shoton)
local TAILLE        = 0.5    -- échelle du cube à son apparition (1 = 72 unités de côté)
local TAILLE_MAX    = 3.2    -- échelle du cube une fois grand (c'est son volume qui frappe)
local DEGATS        = 120    -- dégâts à chaque joueur / PNJ dans le cube quand il a fini de grandir

local RECHARGE      = 14     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.5    -- incantation avant le lancer
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jinton_cubes", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Point où le cube apparaît : là où le lanceur regarde, jusqu'à la portée max.
--   * un ennemi sur la ligne de visée (avant le premier mur) : le cube apparaît sur lui ;
--   * sinon le premier mur / sol touché (un peu décollé du mur) ;
--   * sinon la portée max, en l'air.
local function PointVise(ply)
    local oeil = ply:GetShootPos()
    local dir  = ply:GetAimVector()
    local portee = Niv(ply, "portee", PORTEE)
    local mur = util.TraceLine({ start = oeil, endpos = oeil + dir * portee, mask = MASK_SOLID_BRUSHONLY })

    local cible, dMin = nil, math.huge
    for _, e in ipairs(ents.FindAlongRay(oeil, mur.HitPos, Vector(-20, -20, -20), Vector(20, 20, 20))) do
        if EstCible(e, ply) then
            local d = oeil:DistToSqr(e:WorldSpaceCenter())
            if d < dMin then cible, dMin = e, d end
        end
    end
    if cible then return cible:GetPos() end                   -- sous les pieds de l'ennemi visé
    if mur.Hit then return mur.HitPos + mur.HitNormal * 8 end -- décollé du mur / du sol
    return mur.HitPos                                          -- portée max
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local cube = ents.Create("jinton_cubes_proj")
    if not IsValid(cube) then return end
    cube.Degats    = NA_Stat(ply, "jinton_cubes", "degats", DEGATS)
    cube.Taille    = Niv(ply, "taille", TAILLE)
    cube.TailleMax = Niv(ply, "taille_max", TAILLE_MAX)
    cube:SetOwner(ply)
    cube:SetPos(PointVise(ply))
    cube:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    cube:Spawn()
end

local function Refus(ply, message)
    ply:PrintMessage(HUD_PRINTCENTER, message)
end

net.Receive("jinton_cubes_cast", function(_, ply)
    if not NA_Debloquee(ply, "jinton_cubes") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = NA_Stat(ply, "jinton_cubes", "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then return end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local recharge = NA_Stat(ply, "jinton_cubes", "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "jinton_cubes", recharge) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDeath", "JintonCubes_Mort", function(ply)
    enCours[ply] = nil
end)

hook.Add("PlayerDisconnected", "JintonCubes_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
