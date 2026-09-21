--========================================================
-- Ailes de papier (SERVEUR)
-- Fixe les ailes dans le dos du joueur et lui permet de voler.
-- Le vol consomme du chakra ; à zéro, les ailes disparaissent.
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_wings_toggle")

local MODELE   = "models/clan/ame/kami/wings.mdl"
local SEQUENCE = "idle"

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

-- Vitesses de vol, inertie et rotation du corps : dans lua/kami/sh_kami_wings_move.lua
-- (partagé serveur + client pour que le vol soit prédit et fluide).
local CHAKRA_MAX    = 100   -- doit correspondre à sv_sprint_chakra.lua
local CHAKRA_COUT   = 6     -- chakra par seconde de vol
local CHAKRA_MINI   = 15    -- chakra requis pour décoller
local RECHARGE      = 3     -- secondes avant de pouvoir relancer après l'atterrissage
local DUREE_MUDRA   = 0.8   -- incantation avant l'apparition des ailes
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

--========================================================

-- Téléchargement pour les joueurs : chaque fichier du modèle doit être listé,
-- le .mdl seul ne suffit pas (sans .vvd ni .vtx, le modèle reste une erreur).
resource.AddFile("models/clan/ame/kami/wings.mdl")
resource.AddFile("models/clan/ame/kami/wings.vvd")
resource.AddFile("models/clan/ame/kami/wings.dx90.vtx")
resource.AddFile("materials/models/narutorp/kami/wings.vmt")
resource.AddFile("materials/models/narutorp/kami/wings.vtf")

local wings = {}      -- joueur -> entité ailes
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

    -- Fusion au squelette : le modèle n'a qu'un os commun (Bip01_Spine2),
    -- il se colle donc tout seul dans le dos.
    -- Pas de EF_PARENT_ANIMATES ici : cet effet force les ailes à suivre le cycle
    -- d'animation du joueur, ce qui empêchait leur propre "idle" de tourner.
    ent:SetParent(ply)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_BONEMERGE_FASTCULL)
    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetOwner(ply)

    JouerIdle(ent)

    wings[ply] = ent
    return ent
end

local function RetirerAiles(ply)
    if IsValid(wings[ply]) then
        wings[ply]:Remove()
    end
    wings[ply] = nil
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

    -- Le déplacement est calculé par le hook "Move" partagé (sh_kami_wings_move.lua),
    -- avec prédiction côté client : on reste en déplacement "marche" normal.
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetVelocity(-ply:GetVelocity())   -- on part de l'arrêt
    ply:SetNW2Bool("NA_Wings", true)

    ply:EmitSound("ambient/wind/wind_snippet3.wav", 70, 100, 0.6)
end

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

    if GetChakra(ply) < CHAKRA_MINI then
        ply:ChatPrint("Pas assez de chakra pour les ailes de papier.")
        return
    end

    casting[ply] = true

    -- mudras, puis apparition des ailes
    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()

    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        if IsValid(ply) then casting[ply] = nil end
        if not IsValid(ply) or not ply:Alive() then return end
        Decoller(ply)
    end)
end)

----------------------------------------------------------
-- Animation des ailes : l'idle tourne en boucle
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
            wings[ply] = nil
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
