--========================================================
-- Futton : Émanation de vapeur (CLIENT)
-- Lancement depuis la barre de techniques, et particule de vapeur autour de chaque joueur qui a le buff
-- (NW2Bool "NA_FuttonVapeur", sv_futton_vapeur.lua).
--========================================================

local FX = "emanation_vapeur_pat"   -- particles/patlick_atgparticules.pcf

NA_Cast = NA_Cast or {}
NA_Cast.futton_vapeur = function()
    net.Start("futton_vapeur_cast")
    net.SendToServer()
end

-- ancre invisible par joueur : la particule suit ses pieds sans tourner avec la caméra
local ancres = {}

local function Arreter(ply)
    local ancre = ancres[ply]
    if IsValid(ancre) then
        ancre:StopParticles()
        ancre:Remove()
    end
    ancres[ply] = nil
end

local function Demarrer(ply)
    Arreter(ply)
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(ply:GetPos())
    ancre:SetAngles(angle_zero)
    ancres[ply] = ancre
    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
end

hook.Add("Think", "NA_FuttonVapeur", function()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and ply:GetNW2Bool("NA_FuttonVapeur", false)
        if actif and not ancres[ply] then
            Demarrer(ply)
        elseif not actif and ancres[ply] then
            Arreter(ply)
        end
        if IsValid(ancres[ply]) then ancres[ply]:SetPos(ply:GetPos()) end
    end
    for ply in pairs(ancres) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
