--========================================================
-- Mokuton : Mains de bois (SERVEUR)
--
-- Après une courte incantation, les mains du Bouddha rieur (entité mokuton_wood_hand, lua/entities)
-- surgissent du sol à l'endroit visé (PORTEE max), jouent nr_LB_spawn et disparaissent quand elle est finie.
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("mokuton_wood_hand_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE       = 900    -- distance max du point visé
local DEGATS       = 30     -- dégâts de la frappe (une fois par personne touchée)
local RAYON        = 200    -- rayon de la zone qui frappe, autour des mains (developer 1 pour la voir)
local SOULEVE      = 350    -- projection vers le haut
local ECHELLE      = 1      -- taille des mains (1 = environ 330 unités de large)
local ANGLE_YAW    = 0      -- rotation des mains par rapport à ton regard (degrés)
local RECHARGE     = 12     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant l'apparition (le point visé est pris à sa FIN)
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2      -- vitesse de l'animation (1 = normale, 2 = deux fois plus vite)
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "mokuton_wood_hand", stat, base) end

resource.AddFile("particles/solve_doton.pcf")   -- particule des mains : solve_doton_spike_spawn_add1
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_spike_spawn_add1")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

-- Point visé : ce que le regard touche dans la portée, sinon le sol sous le point de portée max ; posé AU SOL
local function PointVise(ply)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut, endpos = debut + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply, mask = MASK_SOLID,
    })
    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 20), endpos = tr.HitPos - Vector(0, 0, 4000),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or tr.HitPos
end

local function Poser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local mains = ents.Create("mokuton_wood_hand")
    if not IsValid(mains) then return end
    mains.Echelle = Niv(ply, "echelle", ECHELLE)
    mains.Degats  = Niv(ply, "degats", DEGATS)
    mains.Rayon   = Niv(ply, "rayon", RAYON)
    mains.Souleve = Niv(ply, "souleve", SOULEVE)
    mains:SetOwner(ply)
    mains:SetPos(PointVise(ply))
    mains:SetAngles(Angle(0, ply:EyeAngles().y + ANGLE_YAW, 0))
    mains:Spawn()
end

net.Receive("mokuton_wood_hand_cast", function(_, ply)
    if not NA_Debloquee(ply, "mokuton_wood_hand") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    if NA_StopChakraRun then NA_StopChakraRun(ply) end   -- lancer une technique coupe la course de chakra

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "mokuton_wood_hand", recharge) end   -- recharge visible dans la barre

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    timer.Simple(mudra, function()
        enCours[ply] = nil
        Poser(ply)   -- point visé à la fin des mudras
    end)
end)

hook.Add("PlayerDisconnected", "MokutonWoodHand_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
