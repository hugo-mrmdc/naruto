--========================================================
-- Ailes de papier (SERVEUR)
-- Fixe les ailes dans le dos du joueur et lui permet de voler.
-- Le vol consomme du chakra ; à zéro, les ailes disparaissent.
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_wings_toggle")

local MODELE   = "models/clan/ame/kami/ailekami.mdl"
local MODELE_FAUX = "models/clan/ame/kami/fauxkami.mdl"   -- faux de papier tenue de la main droite pendant le vol
local SEQUENCE = "aileland"   -- séquences du modèle : aileidle, aileatk, aileland, aileprotect_start/loop/end

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

-- Vitesses de vol, inertie et rotation du corps : dans lua/kami/sh_kami_wings_move.lua
-- (partagé serveur + client pour que le vol soit prédit et fluide).
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local CHAKRA_COUT   = 6     -- chakra par seconde de vol
local CHAKRA_MINI   = 15    -- chakra requis pour décoller
local RECHARGE      = 3     -- secondes avant de pouvoir relancer après l'atterrissage
local DUREE_MUDRA   = 0.8   -- incantation avant l'apparition des ailes
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kami_ailes", stat, base) end

-- Téléchargement pour les joueurs : chaque fichier du modèle doit être listé,
-- le .mdl seul ne suffit pas (sans .vvd ni .vtx, le modèle reste une erreur).
for _, ext in ipairs({ "mdl", "vvd", "dx90.vtx", "dx80.vtx", "phy" }) do
    resource.AddFile("models/clan/ame/kami/ailekami." .. ext)
end
for _, ext in ipairs({ "mdl", "vvd", "dx90.vtx", "dx80.vtx", "phy" }) do
    resource.AddFile("models/clan/ame/kami/fauxkami." .. ext)
end
for _, mat in ipairs({ "2knneff1_01_0", "2knneff1_awapaper00_0", "ntxr005" }) do
    resource.AddFile("materials/models/billy/kami/" .. mat .. ".vmt")
    resource.AddFile("materials/models/billy/kami/" .. mat .. ".vtf")
end

-- Particules de papier sur le corps et les ailes (jouées par les clients : cl_kami_wings.lua)
game.AddParticles("particles/solve_kami_geams.pcf")
PrecacheParticleSystem("kami_02_solve_geams_tornado_v2")
PrecacheParticleSystem("kami_02_solve_geams_weapon")
resource.AddFile("particles/solve_kami_geams.pcf")
resource.AddFile("materials/effects/papertrail/paper_geams_solve_03.vmt")
resource.AddFile("materials/effects/papertrail/paper_geams_solve_03.vtf")

--[[
    Placement des ailes : le MÊME qu'avec l'ancien modèle (wings.mdl), dont l'os racine
    était ValveBiped.Bip01_Spine2 : les ailes partent donc du haut du dos.
    ailekami a son propre squelette (il ne peut pas se fondre au corps) : il est collé
    à l'os Spine2 du joueur (ici, côté serveur) et le DÉCALAGE est appliqué à l'affichage
    par chaque client (cl_kami_wings.lua), à partir de ces convars répliquées.

    Réglable EN JEU dans la console, sans redémarrer, valeurs dans le repère de l'os :
        kami_aile_x / _y / _z            position (x : le long de la colonne vers le haut)
        kami_aile_pitch / _yaw / _roll   orientation
        kami_aile_echelle                taille

    Les valeurs écrites dans PLACEMENT (juste en dessous) sont celles qui s'appliquent :
    elles sont remises à chaque chargement du script (démarrage, changement de map),
    quoi qu'il y ait eu de sauvegardé avant. Les commandes ne servent qu'à essayer des
    valeurs en direct ; pour les garder, reporte-les dans PLACEMENT.
]]
local OS_DOS = "ValveBiped.Bip01_Spine2"

-- >>> LES VALEURS À MODIFIER SONT ICI <<<
local PLACEMENT = {
    x      = 15,   -- le long de la colonne, vers le haut
    y      = 3.3,    -- avant / arrière
    z      = 0,      -- gauche / droite
    pitch  = 0,
    yaw    = 90,
    roll   = 90,
    echelle = 1,     -- taille
}

-- Pas d'ARCHIVE : une valeur essayée en console ne survit pas au redémarrage
local FLAGS = { FCVAR_REPLICATED }
for nom, valeur in pairs(PLACEMENT) do
    local cv = CreateConVar("kami_aile_" .. nom, tostring(valeur), FLAGS, "Ailes de papier : " .. nom)
    cv:SetFloat(valeur)   -- le code fait foi, même si une ancienne valeur était sauvegardée
end

local wings = {}      -- joueur -> entité ailes
local faux = {}       -- joueur -> entité faux (main droite)
local etatAvant = {}  -- joueur -> déplacement d'origine
local nextUse = {}
local casting = {}

local function GetChakra(ply)
    return ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
end

local function SetChakra(ply, v)
    ply:SetNW2Float("NA_Chakra", math.Clamp(v, 0, CHAKRA_MAX))
end

----------------------------------------------------------
-- Ailes
----------------------------------------------------------

-- La séquence "idle" du modèle ne boucle pas toute seule : on la relance
-- dès qu'elle est terminée (durée lue dans le modèle).
local function JouerIdle(ent)
    if not IsValid(ent) then return end

    local seq = ent:LookupSequence(SEQUENCE)
    if not seq or seq < 0 then return end

    ent:ResetSequence(seq)
    ent:SetCycle(0)
    ent:SetPlaybackRate(1)
    -- entrée moteur du prop_dynamic : relance aussi l'animation côté client
    ent:Fire("SetAnimation", SEQUENCE)

    local duree = ent:SequenceDuration(seq)
    if not duree or duree <= 0 then duree = 1 end
    ent.NA_ProchaineBoucle = CurTime() + duree
end

local function EntretenirIdle(ent)
    if not IsValid(ent) then return end
    if (ent.NA_ProchaineBoucle or 0) > CurTime() then return end
    JouerIdle(ent)
end

local function CreerAiles(ply)
    if IsValid(wings[ply]) then return wings[ply] end

    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    ent:SetModel(MODELE)
    ent:SetPos(ply:GetPos())
    ent:SetAngles(ply:GetAngles())

    -- prop_dynamic sait boucler tout seul l'animation nommée dans "DefaultAnim"
    ent:SetKeyValue("DefaultAnim", SEQUENCE)
    ent:SetKeyValue("solid", "0")
    ent:Spawn()
    ent:Activate()

    -- Collé à l'os du dos (comme l'ancien modèle, dont la racine était Spine2)
    ent:SetParent(ply)
    ent:FollowBone(ply, ply:LookupBone(OS_DOS) or 0)
    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetOwner(ply)

    JouerIdle(ent)

    wings[ply] = ent
    return ent
end

-- La faux (fauxkami) a pour os racine ValveBiped.Bip01_R_Hand : fusionnée au joueur
-- (bonemerge), elle se retrouve d'elle-même dans sa main droite.
local function CreerFaux(ply)
    if IsValid(faux[ply]) then return faux[ply] end

    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    ent:SetModel(MODELE_FAUX)
    ent:SetPos(ply:GetPos())
    ent:SetAngles(ply:GetAngles())
    ent:SetKeyValue("solid", "0")
    ent:Spawn()
    ent:Activate()

    ent:SetParent(ply)
    ent:AddEffects(EF_BONEMERGE)
    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetOwner(ply)

    faux[ply] = ent
    return ent
end

local function RetirerAiles(ply)
    if IsValid(wings[ply]) then
        wings[ply]:Remove()
    end
    wings[ply] = nil

    if IsValid(faux[ply]) then
        faux[ply]:Remove()
    end
    faux[ply] = nil
end

----------------------------------------------------------
-- Vol
----------------------------------------------------------
local function Atterrir(ply, silencieux)
    if not wings[ply] and not etatAvant[ply] then return end

    RetirerAiles(ply)

    if IsValid(ply) then
        local old = etatAvant[ply] or {}
        ply:SetMoveType(old.move or MOVETYPE_WALK)
        ply:SetWalkSpeed(old.walk or 200)
        ply:SetRunSpeed(old.run or 400)
        ply:SetNW2Bool("NA_Wings", false)

        -- on retombe de haut : pas de dégâts de chute pendant quelques secondes
        ply.MokutonNoFall = CurTime() + 5

        if not silencieux then
            ply:EmitSound("ambient/wind/wind_snippet1.wav", 65, 110, 0.5)
        end
    end

    etatAvant[ply] = nil
    nextUse[ply] = CurTime() + NA_Stat(ply, "kami_ailes", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kami_ailes", NA_Stat(ply, "kami_ailes", "recharge", RECHARGE)) end -- recharge visible dans la barre
end

local function Decoller(ply)
    if IsValid(wings[ply]) then return end

    etatAvant[ply] = {
        move = ply:GetMoveType(),
        walk = ply:GetWalkSpeed(),
        run  = ply:GetRunSpeed(),
    }

    CreerAiles(ply)
    CreerFaux(ply)

    -- Le déplacement est calculé par le hook "Move" partagé (sh_kami_wings_move.lua),
    -- avec prédiction côté client : on reste en déplacement "marche" normal.
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetVelocity(-ply:GetVelocity())   -- on part de l'arrêt
    ply:SetNW2Bool("NA_Wings", true)

    -- en vol : toujours les poings (combo aérien), plus de changement d'arme (hook plus bas)
    if not ply:HasWeapon("naruto_poings") then ply:Give("naruto_poings") end
    ply:SelectWeapon("naruto_poings")

    ply:EmitSound("ambient/wind/wind_snippet3.wav", 70, 100, 0.6)
end

hook.Add("PlayerSwitchWeapon", "NA_Wings_Poings", function(ply, _, newWep)
    if ply:GetNW2Bool("NA_Wings", false) and IsValid(newWep) and newWep:GetClass() ~= "naruto_poings" then
        return true
    end
end)

----------------------------------------------------------
-- Touche
----------------------------------------------------------
net.Receive("kami_wings_toggle", function(_, ply)
    if not NA_Debloquee(ply, "kami_ailes") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end

    -- en vol : on replie les ailes
    if IsValid(wings[ply]) then
        Atterrir(ply)
        return
    end

    if casting[ply] then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    if GetChakra(ply) < Niv(ply, "chakra_mini", CHAKRA_MINI) then
        ply:ChatPrint("Pas assez de chakra pour les ailes de papier.")
        return
    end

    casting[ply] = true

    -- mudras, puis apparition des ailes
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)

    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        if IsValid(ply) then casting[ply] = nil end
        if not IsValid(ply) or not ply:Alive() then return end
        Decoller(ply)
    end)
end)

----------------------------------------------------------
-- Animation des ailes : la séquence (aileland) tourne en boucle
-- (le pilotage, lui, est dans lua/kami/sh_kami_wings_move.lua)
----------------------------------------------------------
hook.Add("Think", "NA_Wings_Idle", function()
    for ply, ent in pairs(wings) do
        EntretenirIdle(ent)
    end
end)

----------------------------------------------------------
-- Consommation de chakra
----------------------------------------------------------
local nextTick = 0

hook.Add("Think", "NA_Wings_Chakra", function()
    local now = CurTime()
    if now < nextTick then return end
    local dt = 0.25
    nextTick = now + dt

    for ply, ent in pairs(wings) do
        if not IsValid(ply) or not ply:Alive() then
            if IsValid(ent) then ent:Remove() end
            if IsValid(faux[ply]) then faux[ply]:Remove() end
            wings[ply] = nil
            faux[ply] = nil
            etatAvant[ply] = nil
            continue
        end

        local reste = GetChakra(ply) - NA_Stat(ply, "kami_ailes", "chakra", CHAKRA_COUT) * dt
        SetChakra(ply, reste)

        if reste <= 0 then
            Atterrir(ply)
            ply:ChatPrint("Chakra épuisé : les ailes se dissipent.")
        end
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "NA_Wings_Death", function(ply)
    casting[ply] = nil
    Atterrir(ply, true)
end)

hook.Add("PlayerSpawn", "NA_Wings_Spawn", function(ply)
    casting[ply] = nil
    Atterrir(ply, true)
end)

hook.Add("PlayerDisconnected", "NA_Wings_Cleanup", function(ply)
    RetirerAiles(ply)
    etatAvant[ply] = nil
    nextUse[ply] = nil
    casting[ply] = nil
end)
