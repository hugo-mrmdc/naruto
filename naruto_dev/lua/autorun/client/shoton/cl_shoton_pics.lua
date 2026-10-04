--========================================================
-- Shoton : Pics de cristal (CLIENT)
-- Lancement depuis la barre de techniques (les cristaux sont créés par le serveur) + particules de chaque rangée.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.shoton_pics = function()
    net.Start("shoton_pics_cast")
    net.SendToServer()
end

net.Receive("shoton_pics_touche", function()
    local pos = net.ReadVector()
    local sol = util.TraceLine({ start = pos + Vector(0, 0, 100), endpos = pos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
    ParticleEffect("solve_custom_explo_pink_pikes_emeraude", sol.Hit and sol.HitPos or pos, angle_zero)
end)
