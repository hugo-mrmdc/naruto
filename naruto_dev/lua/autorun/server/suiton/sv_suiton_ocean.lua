--========================================================
-- Suiton : Océan (SERVEUR) - rang S
--
-- Après les mudras, une zone d'océan (entité suiton_ocean, lua/entities : modèle lv_zone_eau + particule [23]_suiton_ocean)
-- se pose au sol devant le lanceur : elle attire légèrement vers son centre et blesse tout le monde dedans (sauf le lanceur)
-- pendant sa durée. Une seule à la fois par lanceur. Le serveur décide de tout : incantation, recharge, chakra.
--
-- Réseau : "suiton_ocean_cast" (client -> serveur)
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_ocean_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 8      -- secondes
local RAYON        = 450    -- rayon de la zone (le modèle est agrandi à cette taille)
local DEGATS       = 12     -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local ATTRACTION   = 120    -- vitesse d'aspiration vers le centre (légère)
local DISTANCE     = 500    -- distance max devant le lanceur où elle apparaît

local RECHARGE     = 40     -- secondes après la FIN de l'océan avant de pouvoir relancer
local CHAKRA_COUT  = 80
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "suiton_ocean"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/nature/suiton/lv_zone_eau." .. ext)
end
resource.AddFile("materials/models/loeve/lv_zone_eau/lv_zone_eau.vmt")
resource.AddFile("materials/models/loeve/lv_zone_eau/lv_zone_eau.vtf")
resource.AddFile("particles/atg_farisv2.pcf")
game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem("[23]_suiton_ocean")
util.PrecacheModel("models/nature/suiton/lv_zone_eau.mdl")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local zones   = {}   -- joueur -> son océan

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if IsValid(zones[ply]) then zones[ply]:Remove() end

    -- au sol, devant le lanceur (jusqu'à DISTANCE, ou le premier mur)
    local dep = ply:GetPos() + Vector(0, 0, 40)
    local fwd = ply:GetAimVector()
    fwd.z = 0
    fwd:Normalize()
    local tr = util.TraceLine({ start = dep, endpos = dep + fwd * Niv(ply, "distance", DISTANCE), filter = ply, mask = MASK_SOLID_BRUSHONLY })
    local sol = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 20), endpos = tr.HitPos - Vector(0, 0, 400), filter = ply, mask = MASK_SOLID_BRUSHONLY })

    local z = ents.Create("suiton_ocean")
    if not IsValid(z) then return end
    z:SetPos(sol.Hit and sol.HitPos or ply:GetPos())
    z:SetOwner(ply)
    z.Duree      = Niv(ply, "duree", DUREE)
    z.Rayon      = Niv(ply, "rayon", RAYON)
    z.Degats     = Niv(ply, "degats", DEGATS)
    z.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    z.Attraction = Niv(ply, "attraction", ATTRACTION)
    z:Spawn()
    zones[ply] = z
end

net.Receive("suiton_ocean_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if enCours[ply] or IsValid(zones[ply]) or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin de l'océan (pas d'océans empilés)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, ID, total) end

    enCours[ply] = true
    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Poser(ply)
    end)
end)

-- l'océan disparaît si son lanceur meurt ou part
local function Nettoyer(ply)
    enCours[ply] = nil
    if IsValid(zones[ply]) then zones[ply]:Remove() end
    zones[ply] = nil
end

hook.Add("PlayerDeath", "SuitonOcean_Mort", Nettoyer)
hook.Add("PlayerDisconnected", "SuitonOcean_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
