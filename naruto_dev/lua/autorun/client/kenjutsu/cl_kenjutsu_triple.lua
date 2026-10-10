--========================================================
-- Kenjutsu : Triple lame (CLIENT)
-- Lancement depuis la barre de techniques ; animation, coups et particules sont côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kenjutsu_triple = function()
    net.Start("kenjutsu_triple_cast")
    net.SendToServer()
end

-- Particules composées de sous-effets : il faut tous les précharger sinon elles restent invisibles
game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
for _, base in ipairs({ "triple_estoc_slash_pat", "triple_estoc_slash_pat_2", "triple_estoc_slash_pat_3" }) do
    for _, suffixe in ipairs({ "", "_add", "_add1", "_add2", "_add3", "_add4", "_add5", "_add6", "_add7" }) do
        PrecacheParticleSystem(base .. suffixe)
    end
end
PrecacheParticleSystem("solve_ken_nrm_hit_03")
PrecacheParticleSystem("solve_ken_nrm_hit_03_circle")
