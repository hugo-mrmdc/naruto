--========================================================
-- Kenjutsu : Tornade de lame (CLIENT)
-- Lancement depuis la barre de techniques ; animation, tornade et dégâts sont côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kenjutsu_tornade = function()
    net.Start("kenjutsu_tornade_cast")
    net.SendToServer()
end

-- Particules composées de sous-effets : il faut tous les précharger sinon elles restent invisibles
game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
for _, suffixe in ipairs({ "", "_add", "_add1", "_add2", "_add3", "_add4", "_add5", "_add6" }) do
    PrecacheParticleSystem("kenjutsu_tornade_pat" .. suffixe)
end
PrecacheParticleSystem("solve_ken_nrm_hit_03")
PrecacheParticleSystem("solve_ken_nrm_hit_03_circle")
