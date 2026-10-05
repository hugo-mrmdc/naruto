--========================================================
-- Grosse boule de feu (CLIENT)
--
-- Envoie l'appui au serveur (sv_katon_grosse_boule.lua, qui décide de tout).
-- La boule (aura) est affichée par l'entité katon_grosse_boule ; l'impact
-- est joué ici à la réception du message du serveur.
--========================================================

local FX_IMPACT = "solve_katon_bigball_impact"   -- particles/solve_new_katon.pcf

game.AddParticles("particles/solve_new_katon.pcf")
PrecacheParticleSystem("solve_katon_bigball_aura")
PrecacheParticleSystem(FX_IMPACT)

NA_Cast = NA_Cast or {}
NA_Cast.katon_grosse_boule = function()
    net.Start("katon_grosse_boule")
    net.SendToServer()
end

net.Receive("katon_grosse_boule_impact", function()
    ParticleEffect(FX_IMPACT, net.ReadVector(), angle_zero)
end)
