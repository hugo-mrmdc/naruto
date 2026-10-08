--========================================================
-- Doton : Dragon de terre (SERVEUR)
--
-- Après les mudras, un dragon de roche (entité doton_dragon, lua/entities) sort du sol devant le lanceur. Pendant sa
-- durée il s'oriente vers l'endroit où regarde le lanceur et tire des projectiles de pierre (doton_dragon_balle).
-- Un seul dragon à la fois par lanceur. Le serveur décide de tout : chakra, recharge, tirs, dégâts.
--
-- Réseau : "doton_dragon_cast" (client -> serveur)
--========================================================

if not SERVER then return end

util.AddNetworkString("doton_dragon_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 5      -- secondes pendant lesquelles le dragon reste
local CADENCE      = 0.3    -- secondes entre deux projectiles
local DEGATS       = 20     -- dégâts d'un projectile
local VITESSE      = 1600   -- vitesse d'un projectile
local ECHELLE      = 1.2    -- taille du dragon (1 = taille du modèle : ~165 de long, ~140 de haut)
local DEVANT       = 90     -- distance, devant le lanceur, où sort le dragon

local RECHARGE     = 25     -- secondes après la FIN du dragon avant de pouvoir relancer
local CHAKRA_COUT  = 60
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2
--========================================================

local ID = "doton_dragon"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, n in ipairs({ "doton_dragon_01", "doton_bullet_01" }) do
    for _, ext in ipairs({ ".mdl", ".vvd", ".dx90.vtx", ".phy" }) do
        resource.AddFile("models/nature/doton/" .. n .. ext)
    end
end
for _, f in ipairs({ "mi_eff_earthdragon_a.vmt", "mi_eff_earthdragon_a.vtf", "white.vmt", "white.vtf" }) do
    resource.AddFile("materials/models/solve_custom_assets_geams/doton/" .. f)
end

util.PrecacheModel("models/nature/doton/doton_dragon_01.mdl")
util.PrecacheModel("models/nature/doton/doton_bullet_01.mdl")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local dragons = {}   -- joueur -> son dragon

local function Invoquer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if IsValid(dragons[ply]) then dragons[ply]:Remove() end

    -- au sol, devant le lanceur
    local dir = Angle(0, ply:EyeAngles().y, 0):Forward()
    local p = ply:GetPos() + dir * Niv(ply, "devant", DEVANT)
    local sol = util.TraceLine({
        start = p + Vector(0, 0, 120), endpos = p - Vector(0, 0, 500),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })

    local d = ents.Create("doton_dragon")
    if not IsValid(d) then return end
    d:SetPos(sol.Hit and sol.HitPos or p)
    d:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    d:SetOwner(ply)
    d.Duree    = Niv(ply, "duree", DUREE)
    d.Cadence  = Niv(ply, "cadence", CADENCE)
    d.Degats   = Niv(ply, "degats", DEGATS)
    d.Vitesse  = Niv(ply, "vitesse", VITESSE)
    d.Echelle  = Niv(ply, "echelle", ECHELLE)
    d:Spawn()
    dragons[ply] = d
end

net.Receive("doton_dragon_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if enCours[ply] or IsValid(dragons[ply]) or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin du dragon (pas de dragons empilés)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, ID, total) end

    enCours[ply] = true
    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Invoquer(ply)
    end)
end)

-- le dragon disparaît si son lanceur meurt ou part
local function Nettoyer(ply)
    enCours[ply] = nil
    if IsValid(dragons[ply]) then dragons[ply]:Remove() end
    dragons[ply] = nil
end

hook.Add("PlayerDeath", "DotonDragon_Mort", Nettoyer)
hook.Add("PlayerDisconnected", "DotonDragon_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
