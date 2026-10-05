--========================================================
-- Raiton : Kirin (CLIENT)
-- Lancement depuis la barre de techniques ; particules du nuage et de l'impact (message "raiton_kirin_fx",
-- sv_raiton_kirin.lua). Le Kirin et sa traînée sont affichés par l'entité raiton_kirin.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.raiton_kirin = function()
    net.Start("raiton_kirin_cast")
    net.SendToServer()
end

local FX_NUAGE     = "solve_kirin_cloud"
local FX_IMPACT    = "solve_raiton_kirin_bigimpact_floor"
local DUREE_IMPACT = 3

game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem(FX_NUAGE)
PrecacheParticleSystem(FX_IMPACT)
util.PrecacheModel("models/raiton/lv_kirin.mdl")

net.Receive("raiton_kirin_fx", function()
    local nuage = net.ReadBool()
    local pos   = net.ReadVector()
    local duree = nuage and net.ReadFloat() or DUREE_IMPACT

    local fx = CreateParticleSystemNoEntity(nuage and FX_NUAGE or FX_IMPACT, pos, angle_zero)
    if not fx then return end
    timer.Simple(duree, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end
    end)
end)
