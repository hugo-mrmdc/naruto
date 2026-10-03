--========================================================
-- Hyoton : Pics de glace (CLIENT)
-- Lancement depuis la barre de techniques (les pics sont créés par le serveur).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_pics = function()
    net.Start("hyoton_pics_cast")
    net.SendToServer()
end

-- Particule à chaque apparition d'un pic (particles/1izoxsolvenr.pcf)
game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem("izox_hyoton_hit")

net.Receive("hyoton_pics_touche", function()
    ParticleEffect("izox_hyoton_hit", net.ReadVector(), angle_zero)
end)
