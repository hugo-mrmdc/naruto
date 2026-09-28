--========================================================
-- Senju : Renforcement (CLIENT)
--
-- Lancement / arrêt depuis la barre de techniques, et AFFICHAGE de l'aura sur
-- chaque joueur qui l'a (NW2Bool "NA_SenjuRenfo", sv_senju_renfo.lua) :
-- tout le monde la voit.
--
-- L'aura (aura_senju_renfo et ses deux systèmes annexes _outils1 / _outils2, lancés
-- automatiquement avec elle) est collée au modèle du joueur : elle suit ses os.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "aura_senju_renfo"   -- particles/slyzz_particles.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.senju_renfo = function()
    net.Start("senju_renfo_cast")
    net.SendToServer()
end

game.AddParticles("particles/slyzz_particles.pcf")
PrecacheParticleSystem(FX)

local actives = {}   -- joueur -> système de particules

local function Porte(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_SenjuRenfo", false)
        and not ply:IsDormant() and not ply:GetNWBool("IsInvisible", false)
end

local function Arreter(ply)
    local ps = actives[ply]
    if ps and ps:IsValid() then ps:StopEmission() end   -- les dernières particules finissent leur vie
    actives[ply] = nil
end

hook.Add("Think", "NA_SenjuRenfo_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local ps = actives[ply]
        if Porte(ply) then
            if not (ps and ps:IsValid()) then
                actives[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0)
            end
        elseif ps then
            Arreter(ply)
        end
    end

    for ply in pairs(actives) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)
