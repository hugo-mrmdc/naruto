--========================================================
-- Jiton : Tornade de sable (CLIENT)
-- Lancement depuis la barre de techniques. La tornade elle-même (entité
-- jiton_tornade) et ses particules sont gérées par lua/entities/jiton_tornade.lua.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jiton_tornade = function()
    net.Start("jiton_tornade_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem("[1]_sand_tornado")
