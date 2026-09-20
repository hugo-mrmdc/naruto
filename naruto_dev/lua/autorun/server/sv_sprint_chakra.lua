--========================================================
-- Course et course de chakra (SERVEUR)
--   Shift          -> course normale
--   Shift x2 rapide -> course de chakra (plus rapide, consomme du chakra)
--
-- Le serveur décide de tout : le client ne fait qu'appuyer sur ses touches.
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

local VITESSE_MARCHE  = 200   -- vitesse normale
local VITESSE_COURSE  = 340   -- Shift
local VITESSE_CHAKRA  = 650   -- double Shift
local SAUT_NORMAL     = 200   -- hauteur de saut normale
local SAUT_CHAKRA     = 200   -- hauteur de saut en course de chakra

local CHAKRA_MAX      = 100   -- réserve de chakra
local CHAKRA_COUT     = 0    -- chakra dépensé par seconde de course de chakra
local CHAKRA_REGEN    = 12    -- chakra récupéré par seconde
local CHAKRA_DELAI    = 1.5   -- secondes d'attente avant que la régénération reprenne
local CHAKRA_MINIMUM  = 10    -- chakra requis pour démarrer une course de chakra

local DOUBLE_TAP      = 0.35  -- délai maxi entre les deux Shift (secondes)

--========================================================

-- Le gamemode Naruto RP a son propre système de chakra et de vitesses :
-- on ne prend la main que hors de ce gamemode.
local function GamemodeGereDeja()
    return NRP ~= nil and NRP.Config ~= nil and NRP.Config.Chakra ~= nil
end

local lastTap = {}
local chakraRun = {}
local nextRegen = {}

local function GetChakra(ply)
    return ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
end

local function SetChakra(ply, value)
    ply:SetNW2Float("NA_Chakra", math.Clamp(value, 0, CHAKRA_MAX))
end

local function ApplySpeeds(ply, chakra)
    if not IsValid(ply) then return end

    -- La course "normale" passe par IN_SPEED, géré par le moteur : il suffit de
    -- changer la vitesse de course pour passer en mode chakra.
    ply:SetWalkSpeed(VITESSE_MARCHE)
    ply:SetRunSpeed(chakra and VITESSE_CHAKRA or VITESSE_COURSE)
    ply:SetJumpPower(chakra and SAUT_CHAKRA or SAUT_NORMAL)

    ply:SetNW2Bool("NA_ChakraRun", chakra or false)
end

local function StopChakraRun(ply)
    if not chakraRun[ply] then return end
    chakraRun[ply] = nil
    nextRegen[ply] = CurTime() + CHAKRA_DELAI
    ApplySpeeds(ply, false)
end

-- Utilisable par les autres scripts : lancer un jutsu ou frapper coupe la course de chakra
NA_StopChakraRun = StopChakraRun

-- Demande du client quand il lance une technique depuis la barre (_na_registre.lua)
util.AddNetworkString("NA_ArretCourseChakra")
net.Receive("NA_ArretCourseChakra", function(_, ply)
    if IsValid(ply) then StopChakraRun(ply) end
end)

local function StartChakraRun(ply)
    if chakraRun[ply] then return end
    -- en vol avec les ailes, la course de chakra n'a pas de sens (et viderait la jauge)
    if ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Vol", false) then return end
    if GetChakra(ply) < CHAKRA_MINIMUM then
        ply:EmitSound("buttons/button10.wav", 60, 100, 0.4)
        return
    end

    chakraRun[ply] = true
    ApplySpeeds(ply, true)
end

----------------------------------------------------------
-- Détection du double Shift
----------------------------------------------------------
hook.Add("KeyPress", "NA_Sprint_KeyPress", function(ply, key)
    if key ~= IN_SPEED then return end
    if GamemodeGereDeja() then return end
    if not IsValid(ply) or not ply:Alive() then return end

    -- état réseau : le client s'en sert pour jouer l'animation de course
    ply:SetNW2Bool("NA_Run", true)

    local now = CurTime()
    if (lastTap[ply] or 0) + DOUBLE_TAP > now then
        StartChakraRun(ply)
    end
    lastTap[ply] = now
end)

hook.Add("KeyRelease", "NA_Sprint_KeyRelease", function(ply, key)
    if key ~= IN_SPEED then return end
    if IsValid(ply) then ply:SetNW2Bool("NA_Run", false) end
    StopChakraRun(ply)
end)

----------------------------------------------------------
-- Consommation et régénération
----------------------------------------------------------
local nextTick = 0

hook.Add("Think", "NA_Sprint_Chakra", function()
    if GamemodeGereDeja() then return end

    local now = CurTime()
    if now < nextTick then return end
    local dt = 0.1
    nextTick = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not ply:Alive() then
            StopChakraRun(ply)
            continue
        end

        if chakraRun[ply] then
            -- on ne consomme que si le joueur avance vraiment
            -- on ne consomme que si le joueur avance vraiment VERS L'AVANT
            -- (en arrière / sur le côté, la course de chakra est suspendue : sh_sprint_chakra.lua)
            local versAvant = not NA_SprintChakra or NA_SprintChakra.ToucheVersLAvant(ply)
            local moving = ply:GetVelocity():Length2D() > 40 and ply:KeyDown(IN_SPEED) and versAvant

            if not moving then
                nextRegen[ply] = now + CHAKRA_DELAI
                continue
            end

            local left = GetChakra(ply) - CHAKRA_COUT * dt
            SetChakra(ply, left)

            if left <= 0 then
                StopChakraRun(ply)
                ply:EmitSound("buttons/button10.wav", 60, 90, 0.4)
            end
            continue
        end

        -- régénération
        if (nextRegen[ply] or 0) > now then continue end
        local cur = GetChakra(ply)
        if cur < CHAKRA_MAX then
            SetChakra(ply, cur + CHAKRA_REGEN * dt)
        end
    end
end)

----------------------------------------------------------
-- Apparition / nettoyage
----------------------------------------------------------
hook.Add("PlayerSpawn", "NA_Sprint_Setup", function(ply)
    if GamemodeGereDeja() then return end

    chakraRun[ply] = nil
    nextRegen[ply] = 0
    ply:SetNW2Bool("NA_Run", false)
    SetChakra(ply, CHAKRA_MAX)

    -- le modèle du joueur est posé un peu après l'apparition par d'autres scripts :
    -- on applique les vitesses juste après pour ne pas se faire écraser
    timer.Simple(0.2, function()
        if IsValid(ply) then ApplySpeeds(ply, false) end
    end)
end)

hook.Add("PlayerDeath", "NA_Sprint_Death", StopChakraRun)

hook.Add("PlayerDisconnected", "NA_Sprint_Cleanup", function(ply)
    chakraRun[ply] = nil
    lastTap[ply] = nil
    nextRegen[ply] = nil
end)
