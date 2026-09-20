--========================================================
-- Kaguya : Absorption (CLIENT)
-- Lancement depuis la barre de techniques, et lien de particule entre le
-- lanceur et sa cible (NW2Entity "NA_KaguyaAttireCible", sv_kaguya_danse.lua).
--
-- La particule izox_kaguya_attire est faite pour relier deux points :
-- le point 0 = le lanceur (sa main), le point 1 = la cible.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX        = "izox_kaguya_attire"   -- particles/1izoxsolvenr.pcf
-- os d'où part le lien : le torse (Spine4 = haut du torse, Spine2 = milieu,
-- ValveBiped.Bip01_Spine = bas du dos)
local OS_TORSE  = "ValveBiped.Bip01_Spine4"
local DECALAGE  = Vector(0, 0, 0)        -- décalage du bout côté lanceur
local HAUT_CIBLE = 0                     -- décalage vertical du bout côté cible
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kaguya_danse = function()
    net.Start("kaguya_danse_cast")
    net.SendToServer()
end

game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem(FX)

local liens = {}   -- joueur -> effet de particule

-- Bout du lien côté lanceur : son torse s'il a l'os, sinon le centre du corps
local function BoutLanceur(ply)
    local id = ply:LookupBone(OS_TORSE) or ply:LookupBone("ValveBiped.Bip01_Spine2")
    if id then
        local pos = ply:GetBonePosition(id)
        if pos and pos ~= ply:GetPos() then return pos + DECALAGE end
    end
    return ply:WorldSpaceCenter() + Vector(0, 0, 10) + DECALAGE
end

local function Arreter(ply)
    local fx = liens[ply]
    if fx then
        fx:StopEmission(false, true, false)
        if IsValid(ply) then ply:StopParticles() end
    end
    liens[ply] = nil
end

local function Demarrer(ply)
    Arreter(ply)
    local fx = CreateParticleSystem(ply, FX, PATTACH_CUSTOMORIGIN)
    if not fx then return end
    liens[ply] = fx
end

hook.Add("Think", "NA_KaguyaAttire_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local cible = ply:GetNW2Entity("NA_KaguyaAttireCible")
        local actif = ply:Alive() and IsValid(cible)

        if actif and not liens[ply] then
            Demarrer(ply)
        elseif not actif and liens[ply] then
            Arreter(ply)
        end

        local fx = liens[ply]
        if fx and actif then
            fx:SetControlPoint(0, BoutLanceur(ply))
            fx:SetControlPoint(1, cible:WorldSpaceCenter() + Vector(0, 0, HAUT_CIBLE))
        end
    end

    for ply in pairs(liens) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
