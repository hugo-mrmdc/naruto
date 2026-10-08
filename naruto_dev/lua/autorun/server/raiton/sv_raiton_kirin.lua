--========================================================
-- Raiton : Kirin (SERVEUR) - rang S
--
-- Après les mudras, un nuage d'orage (solve_kirin_cloud) se forme au-dessus du point visé ; le Kirin (entité raiton_kirin)
-- en sort et fonce vers le sol. À l'impact : particule solve_raiton_kirin_bigimpact_floor, dégâts + étourdissement.
-- Le serveur décide de tout : chakra, recharge, dégâts. Affichage des particules : cl_raiton_kirin.lua.
--
-- Réseau : "raiton_kirin_cast" (client -> serveur), "raiton_kirin_fx" (serveur -> clients : nuage / impact)
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_kirin_cast")
util.AddNetworkString("raiton_kirin_fx")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 150
local STUN         = 2      -- secondes d'étourdissement
local RAYON        = 350    -- zone touchée autour de l'impact
local VITESSE      = 1800   -- vitesse du Kirin
local ECHELLE      = 1      -- taille du Kirin (1 = taille du modèle)
local PORTEE       = 1200   -- distance max du point visé
local HAUTEUR      = 200    -- hauteur du nuage au-dessus du point visé
local MONTE        = 0      -- le Kirin apparaît ce nombre d'unités AU-DESSUS du centre du nuage
local DELAI_NUAGE  = 1.0    -- secondes entre l'apparition du nuage et la sortie du Kirin
local DUREE_NUAGE  = 3      -- secondes d'affichage du nuage

local RECHARGE     = 50
local CHAKRA_COUT  = 90
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 1.2
local ANIM_APPEL   = "nrp_ninjutsu_trow_kirin"
local ANIM_VITESSE = 1
--========================================================

local ID = "raiton_kirin"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_raiton.pcf")
for _, ext in ipairs({ ".mdl", ".vvd", ".dx90.vtx", ".dx80.vtx", ".phy" }) do
    resource.AddFile("models/raiton/lv_kirin" .. ext)
end
for _, m in ipairs({ "lv_base", "lv_contour" }) do
    for _, ext in ipairs({ ".vmt", ".vtf" }) do
        resource.AddFile("materials/models/loeve/lv_kirin/" .. m .. ext)
    end
end
util.PrecacheModel("models/raiton/lv_kirin.mdl")

local enCours = {}
local pret    = {}

-- point visé, ramené au sol
local function PointVise(ply)
    local debut = ply:EyePos()
    local portee = Niv(ply, "portee", PORTEE)
    local tr = util.TraceLine({
        start = debut, endpos = debut + ply:GetAimVector() * portee,
        filter = ply, mask = MASK_SOLID,
    })
    -- regard qui ne touche rien (ciel...) : on vise le sol DEVANT le lanceur, à la portée max (pas sous le point du ciel : il tomberait sur lui)
    local depart = tr.Hit and (tr.HitPos + tr.HitNormal * 5) or (debut + Angle(0, ply:EyeAngles().y, 0):Forward() * portee)
    local sol = util.TraceLine({
        start = depart, endpos = depart - Vector(0, 0, 4000),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or depart
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local cible = PointVise(ply)
    -- le nuage reste sous le plafond s'il y en a un
    local haut = util.TraceLine({
        start = cible + Vector(0, 0, 10), endpos = cible + Vector(0, 0, Niv(ply, "hauteur", HAUTEUR)),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local nuage = haut.HitPos - Vector(0, 0, haut.Hit and 40 or 0)

    net.Start("raiton_kirin_fx")
        net.WriteBool(true)
        net.WriteVector(nuage)
        net.WriteFloat(DUREE_NUAGE)
    net.Broadcast()

    timer.Simple(Niv(ply, "delai_nuage", DELAI_NUAGE), function()
        if not IsValid(ply) then return end
        local figer = Niv(ply, "debug", 0) ~= 0
        if figer then
            for _, e in ipairs(ents.FindByClass("raiton_kirin")) do e:Remove() end   -- un seul Kirin figé à la fois
        end
        local k = ents.Create("raiton_kirin")
        if not IsValid(k) then return end
        k:SetPos(nuage + Vector(Niv(ply, "decal_x", 0), Niv(ply, "decal_y", 0), Niv(ply, "monte", MONTE)))
        k.FaceMoi = Niv(ply, "face_moi", 1) ~= 0
        k.Face    = Niv(ply, "face", 0)
        k.AnimCycle = Niv(ply, "anim_cycle", 0.5)
        k.Debug = figer
        k.Centrer = Niv(ply, "centrer", 1) ~= 0
        k:SetOwner(ply)
        k.Cible   = cible
        k.Vitesse = Niv(ply, "vitesse", VITESSE)
        k.Echelle = Niv(ply, "echelle", ECHELLE)
        k.Degats  = Niv(ply, "degats", DEGATS)
        k.Rayon   = Niv(ply, "rayon", RAYON)
        k.Stun    = Niv(ply, "stun", STUN)
        k.Orientation = Angle(Niv(ply, "angle_pitch", 0), Niv(ply, "angle_yaw", -90), Niv(ply, "angle_roll", 0))
        k:Spawn()
    end)
end

net.Receive("raiton_kirin_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "debug", 0) ~= 0 and 0 or Niv(ply, "recharge", RECHARGE)   -- debug : pas de recharge
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    enCours[ply] = true
    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDeath", "RaitonKirin_Mort", function(ply) enCours[ply] = nil end)
hook.Add("PlayerDisconnected", "RaitonKirin_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
