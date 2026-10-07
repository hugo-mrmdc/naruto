--========================================================
-- Dôme de feu (SERVEUR)
--
-- Pose au sol une zone de flammes (entité katon_zone, lua/entities) qui
-- blesse et brûle tout le monde dedans, sauf le lanceur.
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_dome")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 5      -- durée de la zone (secondes)
local RAYON        = 300    -- rayon de la zone (= taille du dôme fire_dome_charge)
local DEGATS       = 6      -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local BRULURE_DUREE = 4     -- brûlure appliquée aux cibles (0 = pas de brûlure)
local BRULURE_DPS  = 4
local RECHARGE     = 10     -- secondes après la FIN de la zone avant de pouvoir relancer
local CHAKRA_COUT  = 20     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.8    -- incantation avant l'apparition de la zone
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2      -- vitesse de lecture de l'animation (1 = normale, 2 = deux fois plus vite)
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "katon_dome", stat, base) end

resource.AddFile("particles/1izoxsolvenr.pcf")

local casting = {}
local nextUse = {}
local zones   = {}   -- joueur -> zone active (une seule à la fois)

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- au sol, sous le joueur (même s'il saute)
    local tr = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 10),
        endpos = ply:GetPos() - Vector(0, 0, 400),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    local pos = tr.Hit and tr.HitPos or ply:GetPos()

    local zone = ents.Create("katon_zone")
    if not IsValid(zone) then return end

    zone:SetPos(pos)
    zone:SetOwner(ply)
    zone.Duree = Niv(ply, "duree", DUREE)
    zone.Rayon = Niv(ply, "rayon", RAYON)
    zone.Degats = Niv(ply, "degats", DEGATS)
    zone.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    zone.BrulureDuree = Niv(ply, "brulure_duree", BRULURE_DUREE)
    zone.BrulureDps = Niv(ply, "brulure_dps", BRULURE_DPS)
    zone:Spawn()

    zones[ply] = zone
end

net.Receive("katon_dome", function(_, ply)
    if not NA_Debloquee(ply, "katon_dome") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or IsValid(zones[ply]) then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then return end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - cout))
    end

    -- la recharge démarre après la fin de la zone (on ne peut pas empiler les dômes)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "katon_dome", total) end -- recharge visible dans la barre

    casting[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL, nil, ANIM_VITESSE)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        if IsValid(ply) then casting[ply] = nil end
        Poser(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage : la zone disparaît si son lanceur meurt ou part
----------------------------------------------------------
local function Nettoyer(ply)
    casting[ply] = nil
    if IsValid(zones[ply]) then zones[ply]:Remove() end
    zones[ply] = nil
end

hook.Add("PlayerDeath", "KatonDome_Death", Nettoyer)
hook.Add("PlayerDisconnected", "KatonDome_Cleanup", function(ply)
    Nettoyer(ply)
    nextUse[ply] = nil
end)
