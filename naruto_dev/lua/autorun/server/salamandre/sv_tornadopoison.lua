--========================================================
-- Typhon de poison de la salamandre (SERVEUR)
--
-- Pose un typhon (entité salamandre_typhon, lua/entities) là où le joueur
-- regarde, dans la limite de PORTEE_MAX. Le typhon aspire les ennemis vers
-- son centre, qui les blesse et les empoisonne.
--
-- Lancé par la commande "spawn_tornado" (utilisée par la barre de techniques).
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE_MAX        = 900    -- distance maximale de placement devant le joueur
local DUREE             = 6      -- durée du typhon (secondes)
local RAYON_ATTRACTION  = 220    -- rayon dans lequel les ennemis sont aspirés
local RAYON_COEUR       = 220    -- rayon du cœur qui blesse (~ taille des particules, agrandies x2)
local FORCE_ATTRACTION  = 3000   -- puissance d'aspiration des joueurs
local TOURBILLON        = 900    -- rotation autour du centre (0 = aspiration en ligne droite)
local VITESSE_PNJ       = 350    -- vitesse d'aspiration des PNJ / nextbots
local DEGATS            = 8      -- dégâts par tick dans le cœur
local INTERVALLE        = 0.5    -- secondes entre deux ticks
local POISON_DUREE      = 3      -- poison dans le cœur (0 = pas de poison)
local RECHARGE          = 12     -- secondes après la FIN du typhon avant de relancer
local CHAKRA_COUT       = 25     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX        = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA       = 1.0    -- incantation avant l'apparition du typhon
local ANIM_APPEL        = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "salamandre_tornade", stat, base) end

resource.AddFile("particles/godio_salamandre.pcf")

local casting = {}
local nextUse = {}
local typhons = {}   -- joueur -> typhon actif (un seul à la fois)

----------------------------------------------------------
-- Point visé : là où regarde le joueur, au plus à PORTEE_MAX, posé au sol
----------------------------------------------------------
local function PointVise(ply)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut,
        endpos = debut + ply:GetAimVector() * Niv(ply, "portee_max", PORTEE_MAX),
        filter = ply,
        mask = MASK_SOLID,          -- s'arrête aussi sur un joueur ou un PNJ visé
    })

    local pos = tr.HitPos
    -- contre un mur : on recule un peu pour ne pas poser le typhon dedans
    if tr.Hit and tr.HitNormal.z < 0.7 then
        pos = pos + tr.HitNormal * 24
    end

    -- puis on descend jusqu'au sol (visée en l'air ou au-dessus d'un vide)
    local sol = util.TraceLine({
        start = pos + Vector(0, 0, 16),
        endpos = pos - Vector(0, 0, 2000),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or pos
end

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local typhon = ents.Create("salamandre_typhon")
    if not IsValid(typhon) then return end

    typhon:SetPos(PointVise(ply))
    typhon:SetOwner(ply)
    typhon.Duree = Niv(ply, "duree", DUREE)
    typhon.RayonAttraction = Niv(ply, "rayon_attraction", RAYON_ATTRACTION)
    typhon.RayonCoeur = Niv(ply, "rayon_coeur", RAYON_COEUR)
    typhon.ForceAttraction = Niv(ply, "force_attraction", FORCE_ATTRACTION)
    typhon.Tourbillon = Niv(ply, "tourbillon", TOURBILLON)
    typhon.VitesseAttractionPNJ = Niv(ply, "vitesse_pnj", VITESSE_PNJ)
    typhon.Degats = NA_Stat(ply, "salamandre_tornade", "degats", DEGATS)
    typhon.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    typhon.PoisonDuree = Niv(ply, "poison_duree", POISON_DUREE)
    typhon:Spawn()

    typhons[ply] = typhon
end

concommand.Add("spawn_tornado", function(ply)
    if not NA_Debloquee(ply, "salamandre_tornade") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or IsValid(typhons[ply]) then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "salamandre_tornade", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "salamandre_tornade", "chakra", CHAKRA_COUT) then
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - NA_Stat(ply, "salamandre_tornade", "chakra", CHAKRA_COUT)))
    end

    -- la recharge démarre après la fin du typhon
    local total = Niv(ply, "duree_mudra", DUREE_MUDRA) + Niv(ply, "duree", DUREE) + NA_Stat(ply, "salamandre_tornade", "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "salamandre_tornade", total) end -- recharge visible dans la barre

    casting[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    -- le point visé est pris à la FIN de l'incantation : on peut viser pendant les mudras
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        if IsValid(ply) then casting[ply] = nil end
        Poser(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage : le typhon disparaît si son lanceur meurt ou part
----------------------------------------------------------
local function Nettoyer(ply)
    casting[ply] = nil
    if IsValid(typhons[ply]) then typhons[ply]:Remove() end
    typhons[ply] = nil
end

hook.Add("PlayerDeath", "SalamandreTyphon_Death", Nettoyer)
hook.Add("PlayerDisconnected", "SalamandreTyphon_Cleanup", function(ply)
    Nettoyer(ply)
    nextUse[ply] = nil
end)

-- Portée partagée avec l'aperçu de visée côté client (cl_tornadopoison.lua)
SetGlobal2Float("NA_TyphonPortee", PORTEE_MAX)
SetGlobal2Float("NA_TyphonRayon", RAYON_ATTRACTION)
