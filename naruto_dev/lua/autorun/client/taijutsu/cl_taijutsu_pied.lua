--========================================================
-- Taijutsu : Coup de pied tournoyant (CLIENT)
-- Lancement depuis la barre de techniques ; l'animation passe par
-- Jutsu_Anim_Play (jutsu_anim_cl.lua), tout le reste est côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.taijutsu_pied = function()
    net.Start("taijutsu_pied_cast")
    net.SendToServer()
end

-- Particule posée sur la cible touchée (cac_hit_pat : composée de sous-effets,
-- il faut tous les précharger sinon elle reste invisible)
game.AddParticles("particles/patlick_atgparticules.pcf")
for _, suffixe in ipairs({ "", "_add", "_add1", "_add2", "_add3", "_add4", "_add5", "_add_a", "_add_b", "_add_c", "_add_d", "_add_e" }) do
    PrecacheParticleSystem("cac_hit_pat" .. suffixe)
end

net.Receive("taijutsu_pied_fx", function()
    ParticleEffect("cac_hit_pat", net.ReadVector(), angle_zero)
end)
