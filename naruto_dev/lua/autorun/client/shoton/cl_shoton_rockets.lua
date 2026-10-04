--========================================================
-- Shoton : Roquettes (CLIENT) : lancement depuis la barre de techniques + explosion des roquettes
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.shoton_rockets = function()
    net.Start("shoton_rockets_cast")
    net.SendToServer()
end

net.Receive("shoton_rocket_boom", function()
    ParticleEffect("solve_custom_explo_pink_emeraude", net.ReadVector(), angle_zero)
end)

-- Anneau de poussière aux pieds du lanceur, juste avant qu'il décolle (particles/solve_impact_autoattack.pcf)
net.Receive("shoton_rockets_sol", function()
    local ply = net.ReadEntity()
    if IsValid(ply) then CreateParticleSystem(ply, "auraburst_sharp", PATTACH_ABSORIGIN) end
end)
