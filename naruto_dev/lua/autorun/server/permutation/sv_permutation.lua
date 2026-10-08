--========================================================
-- Permutation (SERVEUR) - Kawarimi no jutsu
--
-- Téléportation : le lanceur disparaît dans la fumée de la téléportation Fuma, un tronc
-- (models/justu/permut_log.mdl) prend sa place, et il réapparaît quelques mètres plus loin
-- dans la direction des touches ZQSD pressées (en avant s'il n'en presse aucune),
-- intouchable un court instant.
--========================================================

if not SERVER then return end

util.AddNetworkString("permutation_cast")
util.AddNetworkString("permutation_fx")   -- fumée au niveau du torse

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local RECHARGE     = 10
local CHAKRA_COUT  = 15
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DISTANCE     = 350    -- distance du saut
local INVULN       = 0.6    -- secondes d'invulnérabilité après la permutation
local LOG_DUREE    = 4      -- secondes avant que le tronc disparaisse
local TAILLE       = 1.6    -- taille du tronc (1 = taille normale du modèle)
local HAUT_TORSE   = 45     -- hauteur de la fumée au-dessus des pieds
local MODELE       = "models/justu/permut_log.mdl"
local SON          = "physics/wood/wood_plank_break1.wav"
--========================================================

local ID = "permutation"
local HAUT_MARCHE = Vector(0, 0, 18)   -- passe les marches et les petits reliefs
local HAUT_SOL     = Vector(0, 0, 120)  -- distance max de recherche du sol
local ESSAIS_HAUT  = { 0, 8, 16, 32, 48 }  -- décalages vers le haut essayés si l'arrivée est dans le décor
local pret = {}

-- Fumée de la téléportation Fuma (smoke_orugi2, cl_permutation.lua) au niveau du torse
local function Fumee(pos)
    net.Start("permutation_fx")
        net.WriteVector(pos)
    net.Broadcast()
end

-- Direction du saut : celle des touches ZQSD pressées (par rapport au regard), sinon vers l'avant
local function Direction(ply)
    local ang = Angle(0, ply:EyeAngles().y, 0)
    local dir = Vector(0, 0, 0)
    if ply:KeyDown(IN_FORWARD)   then dir = dir + ang:Forward() end
    if ply:KeyDown(IN_BACK)      then dir = dir - ang:Forward() end
    if ply:KeyDown(IN_MOVERIGHT) then dir = dir + ang:Right() end
    if ply:KeyDown(IN_MOVELEFT)  then dir = dir - ang:Right() end
    if dir:LengthSqr() < 0.01 then dir = ang:Forward() end
    dir:Normalize()
    return dir
end

local function Permuter(ply)
    local depart = ply:GetPos()
    local dir = Direction(ply)

    -- destination : jusqu'au premier obstacle, puis posée au sol, puis dégagée du décor
    local mins, maxs = ply:GetHull()
    if ply:Crouching() then mins, maxs = ply:GetHullDuck() end
    local trace = { mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID }
    local function Hull(de, vers)
        trace.start, trace.endpos = de, vers
        return util.TraceHull(trace)
    end

    local depart_haut = depart + HAUT_MARCHE
    local tr = Hull(depart_haut, depart_haut + dir * DISTANCE)
    local arrivee = tr.HitPos
    if ply:IsOnGround() then   -- au sol : on se pose sur le sol d'arrivée (en l'air, on garde la hauteur)
        local sol = Hull(arrivee, arrivee - HAUT_SOL)
        if sol.Hit and not sol.StartSolid then arrivee = sol.HitPos end
    end

    local libre
    for _, up in ipairs(ESSAIS_HAUT) do
        local test = arrivee + Vector(0, 0, up)
        local t = Hull(test, test)
        if not t.Hit and not t.StartSolid then libre = test break end
    end
    arrivee = libre or depart   -- aucune place libre : pas de déplacement (évite de rester coincé)

    -- le tronc prend la place du lanceur ; la fumée du départ se fait sur lui
    local fumeeDepart = depart + Vector(0, 0, HAUT_TORSE)
    if util.IsValidModel(MODELE) then
        local tronc = ents.Create("prop_physics")
        if IsValid(tronc) then
            tronc:SetModel(MODELE)
            tronc:SetPos(depart + Vector(0, 0, 10 * TAILLE))
            tronc:SetAngles(Angle(0, ply:EyeAngles().y, 0))
            tronc:SetModelScale(TAILLE, 0)
            tronc:Spawn()
            tronc:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)   -- ne bloque personne
            SafeRemoveEntityDelayed(tronc, LOG_DUREE)
            fumeeDepart = tronc:WorldSpaceCenter()
        end
    end

    Fumee(fumeeDepart)
    ply:EmitSound(SON, 75, 100)

    ply:SetPos(arrivee)
    ply:SetVelocity(-ply:GetVelocity())
    ply.NA_PermutFin = CurTime() + INVULN
end

net.Receive("permutation_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Etourdi", false) then return end   -- immobilisé : pas de permutation

    local cout = NA_Stat(ply, ID, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = NA_Stat(ply, ID, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    Permuter(ply)
end)

hook.Add("EntityTakeDamage", "Permutation_Invulnerable", function(ent)
    if ent:IsPlayer() and (ent.NA_PermutFin or 0) > CurTime() then return true end
end)

hook.Add("PlayerDeath", "Permutation_Mort", function(ply) ply.NA_PermutFin = nil end)
hook.Add("PlayerDisconnected", "Permutation_Nettoyage", function(ply) pret[ply] = nil end)
