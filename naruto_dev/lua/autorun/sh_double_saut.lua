--========================================================
-- Double saut (PARTAGÉ serveur + client)
--
-- En l'air, un nouvel appui sur Espace relance un saut (une seule fois,
-- jusqu'à ce qu'on retouche le sol) et joue l'animation nrp_base_doublejump
-- chez tout le monde.
--
-- Fait dans SetupMove, exécuté par le serveur ET en prédiction par le client :
-- le saut part immédiatement, sans latence.
--========================================================

if SERVER then AddCSLuaFile() end

--========================================================
-- RÉGLAGES
--========================================================
local ACTIF        = true
local FORCE        = 400                    -- vitesse vers le haut du 2e saut (saut normal : 200)
local ANIMATION    = "nrp_base_doublejump"  -- "" = pas d'animation
local COUT_CHAKRA  = 0                      -- chakra consommé par double saut (0 = gratuit)
local SEULEMENT_EN_COURSE_CHAKRA = false    -- true = double saut uniquement en course de chakra
local DELAI_MIN    = 0.15                   -- secondes minimum après le 1er saut (évite le double appui accidentel)
--========================================================

if SERVER then
    local function JouerAnim(ply)
        if ANIMATION == "" then return end
        -- message réseau du système d'animation de l'addon (jutsu_anim_sv.lua)
        net.Start("Jutsu_Anim_Play")
            net.WriteEntity(ply)
            net.WriteString(ANIMATION)
        net.Broadcast()
    end

    NA_DoubleSaut_JouerAnim = JouerAnim
end

local function Possible(ply)
    if ply:GetMoveType() ~= MOVETYPE_WALK then return false end   -- noclip, échelle, vol
    if ply:WaterLevel() >= 2 then return false end
    if ply:InVehicle() then return false end
    if ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Vol", false) then return false end   -- en vol
    if (ply:GetNWBool("MokutonRide", false) or ply:GetNWBool("InkutonRide", false)) then return false end
    if ply:GetNW2Bool("NA_Golem", false) then return false end
    if ply:GetNW2Bool("NA_Canalise", false) then return false end   -- technique canalisée en cours (32 Points, Tourbillon...)
    if SEULEMENT_EN_COURSE_CHAKRA and not ply:GetNW2Bool("NA_ChakraRun", false) then return false end
    if COUT_CHAKRA > 0 and ply:GetNW2Float("NA_Chakra", NA_CHAKRA_MAX or 100) < COUT_CHAKRA then return false end
    return true
end

hook.Add("SetupMove", "NA_DoubleSaut", function(ply, mv)
    if not ACTIF or not ply:Alive() then return end

    -- au sol : le double saut est de nouveau disponible
    if ply:IsOnGround() then
        ply.NA_DoubleSautFait = nil
        ply.NA_DecollageSaut = CurTime()
        return
    end

    if not mv:KeyPressed(IN_JUMP) then return end
    if CurTime() - (ply.NA_DecollageSaut or 0) < DELAI_MIN then return end

    -- déjà fait pendant ce saut ? (sauf si la prédiction rejoue ce même instant)
    local fait = ply.NA_DoubleSautFait
    if fait and math.abs(fait - CurTime()) > 0.001 then return end

    if not Possible(ply) then return end

    local vel = mv:GetVelocity()
    vel.z = FORCE
    mv:SetVelocity(vel)
    ply.NA_DoubleSautFait = CurTime()

    if SERVER and not fait then
        if COUT_CHAKRA > 0 then
            ply:SetNW2Float("NA_Chakra", math.max(ply:GetNW2Float("NA_Chakra", NA_CHAKRA_MAX or 100) - COUT_CHAKRA, 0))
        end
        NA_DoubleSaut_JouerAnim(ply)
        ply:EmitSound("player/suit_sprint.wav", 60, 110, 0.5)
    end
end)
