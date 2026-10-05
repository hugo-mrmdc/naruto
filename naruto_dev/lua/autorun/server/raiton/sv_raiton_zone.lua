--========================================================
-- Raiton : Zone de foudre (SERVEUR)
--
-- Pose au sol, autour du lanceur, une zone de foudre (entité raiton_zone, lua/entities) : dégâts à chaque tick
-- et, toutes les PULSE secondes, étourdissement de tous ceux qui sont dedans (sauf le lanceur).
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_zone_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 10     -- durée de la zone (secondes)
local RAYON        = 450    -- rayon de la zone (à régler sur la taille de solve_raiton_area : ~500)
local DEGATS       = 4      -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local PULSE        = 3      -- secondes entre deux étourdissements
local STUN         = 1      -- secondes d'étourdissement
local RECHARGE     = 15     -- secondes après la FIN de la zone avant de pouvoir relancer
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2
--========================================================

local ID = "raiton_zone"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_raiton.pcf")
game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_area")
PrecacheParticleSystem("solve_raiton_ball_link_vplayer")

local enCours = {}
local pret    = {}
local zones   = {}   -- joueur -> zone active (une seule à la fois)

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- au sol, sous le lanceur (même s'il saute)
    local tr = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 10), endpos = ply:GetPos() - Vector(0, 0, 400),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })

    local zone = ents.Create("raiton_zone")
    if not IsValid(zone) then return end
    zone:SetPos(tr.Hit and tr.HitPos or ply:GetPos())
    zone:SetOwner(ply)
    zone.Duree      = Niv(ply, "duree", DUREE)
    zone.Rayon      = Niv(ply, "rayon", RAYON)
    zone.Degats     = Niv(ply, "degats", DEGATS)
    zone.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    zone.Pulse      = Niv(ply, "pulse", PULSE)
    zone.Stun       = Niv(ply, "stun", STUN)
    zone:Spawn()
    zones[ply] = zone
end

net.Receive("raiton_zone_cast", function(_, ply)
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

    -- la recharge démarre après la fin de la zone (pas de zones empilées)
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
        Poser(ply)
    end)
end)

-- la zone disparaît si son lanceur meurt ou part
local function Nettoyer(ply)
    enCours[ply] = nil
    if IsValid(zones[ply]) then zones[ply]:Remove() end
    zones[ply] = nil
end

hook.Add("PlayerDeath", "RaitonZone_Mort", Nettoyer)
hook.Add("PlayerDisconnected", "RaitonZone_Nettoyage", function(ply)
    Nettoyer(ply)
    pret[ply] = nil
end)
