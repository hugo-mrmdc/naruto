--========================================================
-- Grosse boule de feu (SERVEUR)
--
-- Après les mudras, lance une énorme boule de feu (entité katon_grosse_boule,
-- lua/entities) qui explose au contact. Le serveur décide de tout.
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_grosse_boule")
util.AddNetworkString("katon_grosse_boule_impact")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local VITESSE      = 900    -- vitesse du projectile
local VIE          = 3      -- secondes avant qu'elle s'éteigne sans contact
local HITBOX       = 40     -- taille de la boule (collision)
local DEGATS       = 60     -- dégâts de l'explosion
local RAYON_EXPLO  = 220    -- rayon de l'explosion
local BRULURE_DUREE = 4
local BRULURE_DPS  = 5
local RECHARGE     = 10
local CHAKRA_COUT  = 35
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 1.0    -- incantation avant le tir
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_TIR     = "nrp_ninjutsu_trow_fireball_lv3"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "katon_grosse_boule", stat, base) end

resource.AddFile("particles/solve_new_katon.pcf")

local casting = {}
local nextUse = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local ang = ply:EyeAngles()
    local dir = ang:Forward()

    local boule = ents.Create("katon_grosse_boule")
    if not IsValid(boule) then return end

    boule:SetPos(ply:EyePos() + dir * 50)
    boule:SetAngles(ang)
    boule:SetOwner(ply)
    boule.Dir          = dir
    boule.Vitesse      = Niv(ply, "vitesse", VITESSE)
    boule.Vie          = Niv(ply, "vie", VIE)
    boule.Hitbox       = Niv(ply, "hitbox", HITBOX)
    boule.Degats       = Niv(ply, "degats", DEGATS)
    boule.RayonExplo   = Niv(ply, "rayon", RAYON_EXPLO)
    boule.BrulureDuree = Niv(ply, "brulure_duree", BRULURE_DUREE)
    boule.BrulureDps   = Niv(ply, "brulure_dps", BRULURE_DPS)
    boule:Spawn()
end

net.Receive("katon_grosse_boule", function(_, ply)
    if not NA_Debloquee(ply, "katon_grosse_boule") then return end   -- pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then return end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - cout))
    end

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "katon_grosse_boule", total) end

    casting[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra + 0.5) end

    timer.Simple(mudra, function()
        if not IsValid(ply) then return end
        casting[ply] = nil
        if not ply:Alive() then return end
        NA_AnimJutsu(ply, ANIM_TIR)
        Lancer(ply)
    end)
end)

local function Nettoyer(ply) casting[ply] = nil end
hook.Add("PlayerDeath", "KatonGrosseBoule_Death", Nettoyer)
hook.Add("PlayerDisconnected", "KatonGrosseBoule_Cleanup", function(ply)
    casting[ply] = nil
    nextUse[ply] = nil
end)
