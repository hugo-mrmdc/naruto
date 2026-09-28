--========================================================
-- Senju : Soin (CLIENT)
--
-- Lancement depuis la barre de techniques, et AFFICHAGE de l'aura de soin sur
-- chaque joueur qui se soigne (NW2Bool "NA_SenjuSoin", sv_senju_soin.lua) :
-- tout le monde la voit. L'aura dure autant que le soin.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "aura_senju_renfo_pat"   -- particles/patlick_atgparticules.pcf (avec ses variantes _add, _add1)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.senju_soin = function()
    net.Start("senju_soin_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)

local actives = {}   -- joueur -> système de particules

local function Soigne(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_SenjuSoin", false)
        and not ply:IsDormant() and not ply:GetNWBool("IsInvisible", false)
end

local function Arreter(ply)
    local ps = actives[ply]
    if ps and ps:IsValid() then ps:StopEmission() end   -- les dernières particules finissent leur vie
    actives[ply] = nil
end

hook.Add("Think", "NA_SenjuSoin_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local ps = actives[ply]
        if Soigne(ply) then
            if not (ps and ps:IsValid()) then
                -- centrée sur le corps (et non sur les pieds)
                actives[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ply:OBBMaxs().z * 0.45))
            end
        elseif ps then
            Arreter(ply)
        end
    end

    for ply in pairs(actives) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
