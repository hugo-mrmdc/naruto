--========================================================
-- Fuma : Aura (CLIENT)
-- Lancement depuis la barre de techniques, et particule d'aura autour de chaque
-- joueur qui a le buff (NW2Bool "NA_AuraFuma", sv_fumaaura.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "fuma_buff"   -- particles/fuma.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.fuma_aura = function()
    net.Start("fuma_aura_cast")
    net.SendToServer()
end

game.AddParticles("particles/fuma.pcf")
PrecacheParticleSystem(FX)

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

hook.Add("Think", "NA_AuraFuma", function()
    for _, ply in ipairs(player.GetAll()) do
        -- pas d'aura sur un joueur invisible (Fuma) : elle dessinerait sa silhouette. Elle revient à la réapparition.
        local actif = ply:Alive() and ply:GetNW2Bool("NA_AuraFuma", false) and not ply:GetNWBool("IsInvisible", false)
        if actif and not ancres[ply] then
            Demarrer(ply)
        elseif not actif and ancres[ply] then
            Arreter(ply)
        end

        local ancre = ancres[ply]
        if IsValid(ancre) then ancre:SetPos(ply:GetPos()) end
    end

    -- joueurs partis
    for ply in pairs(ancres) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
