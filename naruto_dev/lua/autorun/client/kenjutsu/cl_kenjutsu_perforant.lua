--========================================================
-- Kenjutsu : Estoc perforant (CLIENT)
-- Lancement depuis la barre de techniques ; animation et dash sont côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kenjutsu_perforant = function()
    net.Start("kenjutsu_perforant_cast")
    net.SendToServer()
end

-- Particules composées de sous-effets : il faut tous les précharger sinon elles restent invisibles
game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
for _, n in ipairs({ "solve_ken_nrm_hit_03", "solve_ken_nrm_hit_03_circle" }) do PrecacheParticleSystem(n) end
for _, base in ipairs({ "dash_perforant_slash_pat", "dash_perforant_hitground_pat" }) do
    for _, suffixe in ipairs({ "", "_add", "_add1", "_add2", "_add3", "_add4", "_add5", "_add6" }) do
        PrecacheParticleSystem(base .. suffixe)
    end
end
