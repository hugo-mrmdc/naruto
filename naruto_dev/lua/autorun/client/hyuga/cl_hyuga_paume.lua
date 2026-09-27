--========================================================
-- Hyuga : Paume du Hakke (CLIENT)
-- Lancement depuis la barre de techniques (l'animation passe par
-- Jutsu_Anim_Play, jutsu_anim_cl.lua, sans code ici). Explosion de chakra
-- (Hyuga_shinoz_2) sur le lanceur à l'impact, touche ou pas
-- ("hyuga_paume_fx", sv_hyuga_paume.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_IMPACT = "Hyuga_shinoz_2"   -- particles/ctg_hyuga_jutsus.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyuga_paume = function()
    net.Start("hyuga_paume_cast")
    net.SendToServer()
end

game.AddParticles("particles/ctg_hyuga_jutsus.pcf")
PrecacheParticleSystem(FX_IMPACT)

-- éclate devant la paume du lanceur, orientée dans le sens du regard
-- (point de contrôle 0 = départ, 1 = arrivée : comme kiminari_laser_fx).
-- S'éteint toute seule (fade-out + durée de vie propres à la particule).
net.Receive("hyuga_paume_fx", function()
    net.ReadEntity()   -- lanceur (non utilisé : la particule n'est pas attachée, voir plus haut)
    local depart = net.ReadVector()
    local arrivee = net.ReadVector()

    local fx = CreateParticleSystemNoEntity(FX_IMPACT, depart, (arrivee - depart):Angle())
    if not fx or not fx:IsValid() then return end

    fx:SetControlPoint(0, depart)
    fx:SetControlPoint(1, arrivee)
end)
