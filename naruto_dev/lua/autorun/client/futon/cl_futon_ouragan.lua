--========================================================
-- Futon : Ouragan de vent (CLIENT)
-- Lancement depuis la barre de techniques (la particule est gérée par l'entité futon_ouragan).
--========================================================

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("atg_projection1")
for _, s in ipairs({ "", "1", "2", "3", "4", "5", "6" }) do PrecacheParticleSystem("atg_projection1_add" .. s) end

NA_Cast = NA_Cast or {}
NA_Cast.futon_ouragan = function()
    net.Start("futon_ouragan_cast")
    net.SendToServer()
end
