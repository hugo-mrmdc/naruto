--========================================================
-- Futon : Grand ouragan (SERVEUR)
--
-- Après les mudras, un ouragan de vent (entité futon_grand_ouragan, lua/entities) se pose au sol devant le lanceur : il
-- attire vers son centre et blesse tout le monde dedans (sauf le lanceur) pendant sa durée. Un seul à la fois par lanceur.
-- Le serveur décide de tout : incantation, recharge, chakra.
--
-- Réseau : "futon_grand_ouragan_cast" (client -> serveur)
--========================================================

if not SERVER then return end

util.AddNetworkString("futon_grand_ouragan_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 5      -- secondes
local RAYON        = 380    -- rayon d'attraction / de dégâts
local DEGATS       = 10     -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local ATTRACTION   = 250    -- vitesse d'aspiration vers le centre
local DISTANCE     = 450    -- distance max devant le lanceur où il apparaît

local RECHARGE     = 22     -- secondes après la FIN de l'ouragan avant de pouvoir relancer
local CHAKRA_COUT  = 60
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
--========================================================

local ID = "futon_grand_ouragan"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_futon.pcf")
game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_ouragan_x")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local zones   = {}   -- joueur -> son ouragan

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

    local z = ents.Create("futon_grand_ouragan")
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

net.Receive("futon_grand_ouragan_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if enCours[ply] or IsValid(zones[ply]) or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin de l'ouragan (pas d'ouragans empilés)
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

-- l'ouragan disparaît si son lanceur meurt ou part
local function Nettoyer(ply)
    enCours[ply] = nil
    if IsValid(zones[ply]) then zones[ply]:Remove() end
    zones[ply] = nil
end

hook.Add("PlayerDeath", "FutonGrandOuragan_Mort", Nettoyer)
hook.Add("PlayerDisconnected", "FutonGrandOuragan_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
