--========================================================
-- Dôme de brume de la salamandre (SERVEUR)
--
-- Pose au sol une zone toxique (entité salamandre_zone, lua/entities) qui
-- blesse et empoisonne tout le monde dedans, sauf le lanceur.
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("dome_Salamandre")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 5      -- durée de la zone (secondes)
local RAYON        = 500    -- rayon de la zone (= taille du dôme de fumée godio_fumee_sala)
local DEGATS       = 5      -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local POISON_DUREE = 3      -- poison appliqué à chaque tick (0 = pas de poison)
local RECHARGE     = 6      -- secondes après la FIN de la zone avant de pouvoir relancer
local CHAKRA_COUT  = 15     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX   = 100    -- doit correspondre à sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.8    -- incantation avant l'apparition de la zone
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

resource.AddFile("particles/godio_salamandre.pcf")

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

    local zone = ents.Create("salamandre_zone")
    if not IsValid(zone) then return end

    zone:SetPos(pos)
    zone:SetOwner(ply)
    zone.Duree = DUREE
    zone.Rayon = RAYON
    zone.Degats = NA_Stat(ply, "salamandre_dome", "degats", DEGATS)
    zone.Intervalle = INTERVALLE
    zone.PoisonDuree = POISON_DUREE
    zone:Spawn()

    zones[ply] = zone
end

net.Receive("dome_Salamandre", function(_, ply)
    if not NA_Debloquee(ply, "salamandre_dome") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or IsValid(zones[ply]) then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "salamandre_dome", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "salamandre_dome", "chakra", CHAKRA_COUT) then
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - NA_Stat(ply, "salamandre_dome", "chakra", CHAKRA_COUT)))
    end

    -- la recharge démarre après la fin de la zone (avant : 2 s, on pouvait empiler les dômes)
    local total = DUREE_MUDRA + DUREE + NA_Stat(ply, "salamandre_dome", "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "salamandre_dome", total) end -- recharge visible dans la barre

    casting[ply] = true

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
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

hook.Add("PlayerDeath", "SalamandreDome_Death", Nettoyer)
hook.Add("PlayerDisconnected", "SalamandreDome_Cleanup", function(ply)
    Nettoyer(ply)
    nextUse[ply] = nil
end)
