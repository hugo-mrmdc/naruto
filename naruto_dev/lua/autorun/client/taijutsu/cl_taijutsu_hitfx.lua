--========================================================
-- Taijutsu : particules d'impact (CLIENT)
-- Reçoit la position d'un coup touché et y pose la particule :
--   rang B (enchaînement aérien, coup de pied relevé) : martialhit_glow
--   coup de pied descendant (rang C) : gamabunta_hit_pat (patlick_atgparticules.pcf)
--========================================================

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("gamabunta_hit_pat")

-- poussière quand la cible de l'enchaînement aérien retouche le sol (dust_conquer : composée de
-- sous-effets, il faut tous les précharger sinon elle reste invisible)
game.AddParticles("particles/solve_impact_autoattack.pcf")
for _, suffixe in ipairs({ "", "_1", "_2", "_3", "_4", "_5", "_6", "_7", "_charge", "_ring", "_settle", "_sharp", "_specks" }) do
    PrecacheParticleSystem("dust_conquer" .. suffixe)
end

PrecacheParticleSystem("auraburst_settle")

net.Receive("taijutsu_sol_fx", function()
    local pos = net.ReadVector()
    ParticleEffect("dust_conquer", pos, angle_zero)
    ParticleEffect("auraburst_settle", pos, angle_zero)
end)

-- rang B : martialhit_glow (solve_impact_autoattack.pcf, composée de sous-effets : on précharge aussi la variante bright)
PrecacheParticleSystem("martialhit_glow")
PrecacheParticleSystem("martialhit_glow_bright")

net.Receive("taijutsu_hitb_fx", function()
    ParticleEffect("martialhit_glow", net.ReadVector(), angle_zero)
end)

-- Coup de pied descendant (rang C) : l'ancienne particule des rang B
net.Receive("taijutsu_descendant_fx", function()
    ParticleEffect("gamabunta_hit_pat", net.ReadVector(), angle_zero)
end)
