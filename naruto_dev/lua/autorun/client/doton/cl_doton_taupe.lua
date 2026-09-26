--========================================================
-- Doton : Voyage souterrain (CLIENT)
--
-- Envoie l'appui au serveur (sv_doton_taupe.lua, qui décide de tout ; rappuyer fait sortir).
-- Particule sous terre affichée tant que le serveur le dit (message "doton_taupe_fx").
-- Elle N'EST PAS accrochée au joueur : l'invisibilité coupe toutes les particules accrochées à lui
-- (cl_fumainvi.lua), elle est donc posée dans le monde et déplacée avec lui à chaque image.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "big_atg_voyage_souterrain"   -- particles/doton_taupe.pcf : atg_voyage_souterrain (atg_particules3.pcf) 1,5 fois plus grande
--========================================================

game.AddParticles("particles/atg_particules3.pcf")
game.AddParticles("particles/doton_taupe.pcf")
PrecacheParticleSystem(FX)
PrecacheParticleSystem("atg_jutsu_petrifiant")

NA_Cast = NA_Cast or {}
NA_Cast.doton_taupe = function()
    net.Start("doton_taupe_cast")
    net.SendToServer()
end

local actifs = {}   -- joueur -> particule

local function Arreter(ply)
    local fx = actifs[ply]
    actifs[ply] = nil
    if fx and fx:IsValid() then fx:StopEmission(false, true) end
end

net.Receive("doton_taupe_fx", function()
    local ply   = net.ReadEntity()
    local actif = net.ReadBool()
    if not IsValid(ply) then return end

    Arreter(ply)
    if actif then actifs[ply] = CreateParticleSystemNoEntity(FX, ply:GetPos(), angle_zero) end
end)

hook.Add("Think", "DotonTaupe_Suit", function()
    for ply, fx in pairs(actifs) do
        if IsValid(ply) and fx and fx:IsValid() then
            fx:SetControlPoint(0, ply:GetPos())
        else
            Arreter(ply)
        end
    end
end)
