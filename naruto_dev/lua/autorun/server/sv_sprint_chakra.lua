--========================================================
-- Course et course de chakra (SERVEUR)
--   Shift          -> course normale
--   Shift x2 rapide -> course de chakra (plus rapide, consomme du chakra)
--   R maintenu      -> recharge du chakra (sur place, animation + particules :
--                      sh_recharge_chakra.lua, cl_recharge_chakra.lua)
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

local CHAKRA_COUT     = 0    -- chakra dépensé par seconde de course de chakra
local CHAKRA_REGEN    = 0     -- régénération AUTOMATIQUE par seconde (0 = aucune : on recharge avec R)
local CHAKRA_DELAI    = 1.5   -- secondes d'attente avant que la régénération automatique reprenne

local CHAKRA_RECHARGE = 30    -- chakra récupéré par seconde en maintenant R
local RECHARGE_COUPURE = 1    -- un coup reçu coupe la recharge : secondes avant de pouvoir recharger
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
    return ply:GetNW2Float("NA_Chakra", NA_ChakraMax(ply))
end

local function SetChakra(ply, value)
    ply:SetNW2Float("NA_Chakra", math.Clamp(value, 0, NA_ChakraMax(ply)))
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
    if ply:GetNW2Bool("NA_Souterrain", false) then return end   -- pas de course de chakra sous terre (sv_doton_taupe.lua)
    if ply:GetNW2Bool("NA_Canalise", false) then return end   -- technique canalisée en cours (32 Points, Tourbillon...)
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
-- Peut-on recharger maintenant ? (R maintenu, au sol ou en l'air, rien d'autre en cours, pas plein)
local function PeutRecharger(ply, now)
    if not ply:KeyDown(IN_RELOAD) then return false end
    if ply:InVehicle() then return false end   -- au sol OU en saut : les deux marchent
    if GetChakra(ply) >= NA_ChakraMax(ply) then return false end
    if (ply.NA_RechargeBloquee or 0) > now then return false end   -- vient de prendre un coup
    if ply:GetNW2Bool("NA_Etourdi", false) then return false end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return false end
    if NA_EnMudra and NA_EnMudra(ply) then return false end
    return true
end

-- un coup reçu coupe la recharge
hook.Add("EntityTakeDamage", "NA_RechargeChakra_Coupure", function(cible, dmg)
    if not cible:IsPlayer() or dmg:GetDamage() <= 0 then return end
    if not cible:GetNW2Bool("NA_RechargeChakra", false) then return end
    cible.NA_RechargeBloquee = CurTime() + RECHARGE_COUPURE
    cible:SetNW2Bool("NA_RechargeChakra", false)
end)

-- Recharge (R), course de chakra et régénération automatique d'un joueur
local function MettreAJour(ply, now, dt)
    if not ply:Alive() then
        StopChakraRun(ply)
        if ply:GetNW2Bool("NA_RechargeChakra", false) then ply:SetNW2Bool("NA_RechargeChakra", false) end
        return
    end

    -- recharge à la touche R : sur place, tant que la touche est maintenue
    local recharge = not chakraRun[ply] and PeutRecharger(ply, now)
    if ply:GetNW2Bool("NA_RechargeChakra", false) ~= recharge then
        ply:SetNW2Bool("NA_RechargeChakra", recharge)
    end
    if recharge then
        SetChakra(ply, GetChakra(ply) + CHAKRA_RECHARGE * dt)
        return
    end

    if chakraRun[ply] then
        -- on ne consomme que si le joueur avance vraiment VERS L'AVANT
        -- (en arrière / sur le côté, la course de chakra est suspendue : sh_sprint_chakra.lua)
        local versAvant = not NA_SprintChakra or NA_SprintChakra.ToucheVersLAvant(ply)
        local moving = ply:GetVelocity():Length2D() > 40 and ply:KeyDown(IN_SPEED) and versAvant

        if not moving then
            nextRegen[ply] = now + CHAKRA_DELAI
            return
        end

        local left = GetChakra(ply) - CHAKRA_COUT * dt
        SetChakra(ply, left)

        if left <= 0 then
            StopChakraRun(ply)
            ply:EmitSound("buttons/button10.wav", 60, 90, 0.4)
        end
        return
    end

    -- régénération automatique (CHAKRA_REGEN, 0 = désactivée ; coupée tant que
    -- le Ketsuryugan ou l'armure d'os consomment du chakra : sv_chinoike_ketsuryugan.lua,
    -- sv_kaguya_armure.lua)
    if CHAKRA_REGEN <= 0 then return end
    if (nextRegen[ply] or 0) > now then return end
    if ply:GetNW2Bool("NA_Ketsuryugan", false) or ply:GetNW2Bool("NA_ArmureOs", false) or ply:GetNW2Bool("NA_SenjuErmite", false) then return end
    local cur = GetChakra(ply)
    if cur < NA_ChakraMax(ply) then
        SetChakra(ply, cur + CHAKRA_REGEN * dt)
    end
end

local nextTick = 0

hook.Add("Think", "NA_Sprint_Chakra", function()
    if GamemodeGereDeja() then return end

    local now = CurTime()
    if now < nextTick then return end
    local dt = 0.1
    nextTick = now + dt

    -- La recharge (R) marche aussi pendant qu'un drain consomme du chakra
    -- (Ketsuryugan, armure d'os...) : les deux s'additionnent.
    for _, ply in ipairs(player.GetAll()) do
        MettreAJour(ply, now, dt)
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
    SetChakra(ply, NA_ChakraMax(ply))

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
