--========================================================
-- Roue de papier (SERVEUR)
-- Deux roues de papier partent côte à côte devant le lanceur et roulent au sol
-- dans la direction de son regard. Elles blessent et repoussent ceux qu'elles
-- touchent (entité kami_paper_wheel, lua/entities).
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_roue_cast")
util.AddNetworkString("kami_roue_mains")    -- particules dans les mains pendant l'animation
util.AddNetworkString("kami_roue_impact")   -- particule d'impact au sol

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

local DEGATS       = 30     -- dégâts par roue et par cible
local INTERVALLE   = 0.6    -- secondes avant qu'une même cible soit re-blessée
local VITESSE      = 1000    -- vitesse de roulage
local DUREE_VIE    = 1    -- secondes d'ALLER (distance = vitesse x durée) ; ensuite les roues reviennent
local DUREE_RETOUR = 4    -- secondes maximum pour revenir (elles disparaissent en te rejoignant)
local ECHELLE      = 0.6    -- taille des roues (1 = ~145 unités de diamètre)
local ECART        = 28     -- distance de chaque roue à l'axe du regard
local DEVANT       = 50     -- distance de départ devant le lanceur
local POUSSEE      = 350    -- projection de la cible vers l'avant
local SOULEVEMENT  = 200    -- projection de la cible vers le haut
local RECHARGE     = 10     -- secondes entre deux lancers
local CHAKRA_COUT  = 30     -- chakra par lancer (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.8    -- incantation avant l'attaque
local DELAI_ROUES  = 0.8    -- délai entre l'animation d'attaque et le départ des roues
local MAINS_APRES  = 0.3    -- les particules des mains restent encore un peu après le départ des roues
local ANIM_ATTAQUE = "nrp_ninjutsu_attack_d28nj3_start"   -- anim_extension_mod7.mdl

--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kami_roue", stat, base) end

-- particules : déclarées ET précachées côté serveur aussi
game.AddParticles("particles/solve_kami_geams.pcf")
PrecacheParticleSystem("kami_03_solve_geams_bone")
PrecacheParticleSystem("kami_03_solve_geams_trace_v2")
PrecacheParticleSystem("kami_03_solve_geams_add_trail")
PrecacheParticleSystem("kami_02_solve_geams_weapon")
for _, nom in ipairs({ "", "_add", "_add_1", "_add_3", "_add_4", "_add_6", "_add_blood", "_add_blood_02" }) do
    PrecacheParticleSystem("kami_02_solve_geams_impact_hit" .. nom)
end

-- téléchargement pour les joueurs qui n'ont pas le contenu
resource.AddFile("particles/solve_kami_geams.pcf")
for _, ext in ipairs({ "mdl", "vvd", "dx90.vtx", "dx80.vtx" }) do
    resource.AddFile("models/clan/ame/kami/roue_kami_geams." .. ext)
end
for _, mat in ipairs({
    "models/billy/kami/2knneff1_01_0", "models/billy/kami/2knneff1_awapaper00_0",
    "effects/papertrail/paper_geams_solve_03", "dslayer/particles/puffsmoke",
    "yamaterial/ya_new_water_trail_1", "narutorp/effects/rasengan/ring_18",
}) do
    resource.AddFile("materials/" .. mat .. ".vmt")
    resource.AddFile("materials/" .. mat .. ".vtf")
end

local nextUse = {}
local casting = {}

-- Hauteur du sol sous un point
local function Sol(pos)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 50),
        endpos = pos - Vector(0, 0, 300),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos.z or pos.z
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- direction à plat : les roues roulent au sol, elles ne montent pas avec le regard
    local yaw = ply:EyeAngles().y
    local avant = Angle(0, yaw, 0):Forward()
    local droite = Angle(0, yaw, 0):Right()

    local echelle = Niv(ply, "echelle", ECHELLE)
    local rayon = 71.5 * echelle
    local ecart = Niv(ply, "ecart", ECART)
    local base = ply:GetPos() + avant * Niv(ply, "devant", DEVANT)

    local roues = {}
    local touches = {}   -- une cible blessée par une roue ne l'est pas aussitôt par l'autre

    for _, cote in ipairs({ 1, -1 }) do
        local pos = base + droite * ecart * cote
        local ent = ents.Create("kami_paper_wheel")
        if not IsValid(ent) then return end

        pos.z = Sol(pos) + rayon * ent.HauteurSolFraction
        ent:SetPos(pos)
        ent:SetOwner(ply)
        ent.Direction   = avant
        ent.Decalage    = droite * ecart * cote   -- au retour, chaque roue reste de son côté
        ent.Vitesse     = Niv(ply, "vitesse", VITESSE)
        ent.DureeVie    = Niv(ply, "duree_vie", DUREE_VIE)
        ent.DureeRetour = Niv(ply, "duree_retour", DUREE_RETOUR)
        ent.Echelle     = echelle
        ent.Degats      = NA_Stat(ply, "kami_roue", "degats", DEGATS)
        ent.Intervalle  = Niv(ply, "intervalle", INTERVALLE)
        ent.Poussee     = Niv(ply, "poussee", POUSSEE)
        ent.Soulevement = Niv(ply, "soulevement", SOULEVEMENT)
        ent.Touches     = touches
        ent:Spawn()
        roues[#roues + 1] = ent
    end

    -- les deux roues partagent UNE hitbox (voir kami_paper_wheel.lua)
    if #roues == 2 then
        roues[1]:SetPartenaire(roues[2])
        roues[2]:SetPartenaire(roues[1])
    end

    ply:EmitSound("geams/solve_jutsu/meiton/solve_meiton_absorption_chakra_start.wav", 70, 80)
end

net.Receive("kami_roue_cast", function(_, ply)
    if not NA_Debloquee(ply, "kami_roue") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] then return end

    if (nextUse[ply] or 0) > CurTime() then
        ply:ChatPrint("Roue de papier : encore " .. math.ceil(nextUse[ply] - CurTime()) .. " secondes")
        return
    end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:ChatPrint("Pas assez de chakra pour la Roue de papier.")
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - cout))
    end

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local delai = Niv(ply, "delai_roues", DELAI_ROUES)

    casting[ply] = true
    nextUse[ply] = CurTime() + mudra + delai + Niv(ply, "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kami_roue", nextUse[ply] - CurTime()) end -- recharge visible dans la barre

    -- particules dans chaque main pendant l'incantation et l'attaque
    net.Start("kami_roue_mains")
        net.WriteEntity(ply)
        net.WriteFloat(mudra + delai + MAINS_APRES)
    net.Broadcast()

    ply:EmitSound("base/mudra_sound_geams.wav", 80, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    -- fin des mudras : animation d'attaque
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then
            if IsValid(ply) then casting[ply] = nil end
            return
        end
        NA_AnimJutsu(ply, ANIM_ATTAQUE)
    end)

    -- puis les roues partent
    timer.Simple(mudra + delai, function()
        if IsValid(ply) then casting[ply] = nil end
        Lancer(ply)
    end)
end)

hook.Add("PlayerDeath", "KamiRoue_Death", function(ply)
    casting[ply] = nil
end)

hook.Add("PlayerDisconnected", "KamiRoue_Cleanup", function(ply)
    casting[ply] = nil
    nextUse[ply] = nil
end)
