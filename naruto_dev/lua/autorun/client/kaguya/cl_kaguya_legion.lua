--========================================================
-- Kaguya : Légion d'os (CLIENT)
-- Lancement depuis la barre de techniques, et particule d'os autour de chaque
-- joueur qui a la technique active (NW2Bool "NA_LegionOs", sv_kaguya_legion.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "[12]_kaguya_legion_bones"   -- particles/atg_farisv2.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kaguya_legion = function()
    net.Start("kaguya_legion_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem(FX)

-- ancre invisible par joueur : la particule reste à ses pieds, sans tourner
-- avec la caméra
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

hook.Add("Think", "NA_LegionOs_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and ply:GetNW2Bool("NA_LegionOs", false)
        if actif and not ancres[ply] then
            Demarrer(ply)
        elseif not actif and ancres[ply] then
            Arreter(ply)
        end

        local ancre = ancres[ply]
        if IsValid(ancre) then ancre:SetPos(ply:GetPos()) end
    end

    for ply in pairs(ancres) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
