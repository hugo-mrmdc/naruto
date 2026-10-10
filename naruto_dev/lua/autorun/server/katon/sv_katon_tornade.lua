--========================================================
-- Tornade de feu (SERVEUR)
--
-- Pose au sol une tornade de flammes (entité katon_tornade, lua/entities) qui
-- attire, blesse et brûle tout le monde dedans, sauf le lanceur.
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_tornade")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 5      -- durée de la tornade (secondes)
local RAYON        = 350    -- rayon d'attraction / de dégâts
local DEGATS       = 5      -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local ATTRACTION   = 600    -- vitesse d'aspiration vers le centre
local BRULURE_DUREE = 4     -- brûlure appliquée aux cibles (0 = pas de brûlure)
local BRULURE_DPS  = 4
local RECHARGE     = 12     -- secondes après la FIN de la tornade avant de pouvoir relancer
local CHAKRA_COUT  = 30     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.8    -- incantation avant l'apparition de la tornade
local DISTANCE     = 400    -- distance max devant le lanceur où elle apparaît
local TAILLE_VISEE = 35     -- demi-taille de la boîte de visée : un ennemi dedans est visé
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "katon_tornade", stat, base) end

resource.AddFile("particles/solve_new_katon.pcf")

local casting = {}
local nextUse = {}
local zones   = {}   -- joueur -> tornade active (une seule à la fois)

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- au sol, devant le joueur (jusqu'à DISTANCE, ou le premier mur)
    local dep = ply:GetPos() + Vector(0, 0, 40)
    local fwd = ply:GetAimVector()
    fwd.z = 0
    fwd:Normalize()
    local tr = util.TraceLine({
        start = dep, endpos = dep + fwd * DISTANCE,
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 20),
        endpos = tr.HitPos - Vector(0, 0, 400),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local pos = sol.Hit and sol.HitPos or ply:GetPos()

    -- ennemi dans la ligne de visée (boîte lancée jusqu'au décor, comme la Chute de cristal Shoton) : la tornade se pose sous lui
    local oeil = ply:GetShootPos()
    local vise = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * DISTANCE, filter = ply, mask = MASK_SOLID_BRUSHONLY })
    local t = Vector(TAILLE_VISEE, TAILLE_VISEE, TAILLE_VISEE)
    local suivi, dMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, vise.HitPos, t)) do   -- _na_visee.lua
        if NA_InkutonEstCible and NA_InkutonEstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < dMin then suivi, dMin = ent, d end
        end
    end
    if suivi then pos = suivi:GetPos() end

    local zone = ents.Create("katon_tornade")
    if not IsValid(zone) then return end

    zone:SetPos(pos)
    zone:SetOwner(ply)
    zone.Duree = Niv(ply, "duree", DUREE)
    zone.Rayon = Niv(ply, "rayon", RAYON)
    zone.Degats = Niv(ply, "degats", DEGATS)
    zone.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    zone.Attraction = Niv(ply, "attraction", ATTRACTION)
    zone.BrulureDuree = Niv(ply, "brulure_duree", BRULURE_DUREE)
    zone.BrulureDps = Niv(ply, "brulure_dps", BRULURE_DPS)
    zone:Spawn()

    zones[ply] = zone
end

net.Receive("katon_tornade", function(_, ply)
    if not NA_Debloquee(ply, "katon_tornade") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or IsValid(zones[ply]) then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then return end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - cout))
    end

    -- la recharge démarre après la fin de la tornade (on ne peut pas les empiler)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "katon_tornade", total) end -- recharge visible dans la barre

    casting[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        if IsValid(ply) then casting[ply] = nil end
        Poser(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage : la tornade disparaît si son lanceur meurt ou part
----------------------------------------------------------
local function Nettoyer(ply)
    casting[ply] = nil
    if IsValid(zones[ply]) then zones[ply]:Remove() end
    zones[ply] = nil
end

hook.Add("PlayerDeath", "KatonTornade_Death", Nettoyer)
hook.Add("PlayerDisconnected", "KatonTornade_Cleanup", function(ply)
    Nettoyer(ply)
    nextUse[ply] = nil
end)
