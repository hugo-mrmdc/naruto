--========================================================
-- Futon : Tornade (SERVEUR)
--
-- Après une courte incantation, lance une tornade de vent (entité futon_tornade, lua/entities)
-- qui AVANCE devant le joueur dans la direction de son regard, en blessant tout sur son passage.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("futon_tornade_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 4      -- durée de la tornade (secondes)
local VITESSE      = 300    -- vitesse d'avance (unités par seconde)
local RAYON        = 130    -- rayon du cylindre qui blesse (à régler sur la taille de la particule)
local HAUTEUR      = 250    -- hauteur du cylindre qui blesse
local DEGATS       = 6      -- dégâts par tick
local INTERVALLE   = 0.25   -- secondes entre deux ticks
local RECUL        = 300    -- projection vers l'extérieur de la tornade, à chaque tick (0 = aucune)
local SOULEVE      = 220    -- projection vers le haut, à chaque tick
local RECHARGE     = 12     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.8    -- incantation avant l'apparition de la tornade
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "futon_tornade", stat, base) end

resource.AddFile("particles/solve_futon.pcf")
game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_tornado_move_s")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- la direction est celle du regard AU MOMENT du départ, ramenée à l'horizontale
    local aim = ply:GetAimVector()
    aim.z = 0
    if aim:LengthSqr() < 0.01 then aim = ply:GetForward() end
    aim:Normalize()

    -- posée au sol, un peu devant le joueur
    local depart = ply:GetPos() + aim * 120
    local sol = util.TraceLine({ start = depart + Vector(0, 0, 60), endpos = depart - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })

    local ent = ents.Create("futon_tornade")
    if not IsValid(ent) then return end

    ent:SetPos(sol.Hit and sol.HitPos or depart)
    ent:SetOwner(ply)
    ent.Direction  = aim
    ent.Duree      = Niv(ply, "duree", DUREE)
    ent.Vitesse    = Niv(ply, "vitesse", VITESSE)
    ent.Rayon      = Niv(ply, "rayon", RAYON)
    ent.Hauteur    = Niv(ply, "hauteur", HAUTEUR)
    ent.Degats     = Niv(ply, "degats", DEGATS)
    ent.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    ent.Recul      = Niv(ply, "recul", RECUL)
    ent.Souleve    = Niv(ply, "souleve", SOULEVE)
    ent:Spawn()
end

net.Receive("futon_tornade_cast", function(_, ply)
    if not NA_Debloquee(ply, "futon_tornade") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "futon_tornade", recharge) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDisconnected", "FutonTornade_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
