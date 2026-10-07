--========================================================
-- Jinton : Cubes lancés (CLIENT)
-- Lancement depuis la barre de techniques. Les cubes sont l'entité jinton_cubes_proj.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_cubes = function()
    net.Start("jinton_cubes_cast")
    net.SendToServer()
end

--========================================================
-- Impact au sol quand le cube a fini de grandir : particules JINTON
--
-- Pour changer l'effet, modifie IMPACT_FX : { particule, durée en secondes avant de la couper }.
-- Autres particules Jinton à essayer (testables avec la commande : na_fx <nom> 3) :
--   atg_farisv2.pcf          : [7]_jinton_vortex_expl, [7]_jinton_bubble, [7]_jinton_slashes, [7]_jinton_anigilation
--   patlick_atgparticules.pcf : jinton_explosion_pat, jinton_aura_pat, trace_cube_jinton_pat
--   solve_jinton_geams.pcf   : hit_jinton, solve_geams_01_j
--========================================================
game.AddParticles("particles/atg_farisv2.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_jinton_geams.pcf")

local IMPACT_FX = {
    { "[7]_jinton_cube_expl",        1.2 },   -- explosion du cube (atg_farisv2.pcf)
    { "jinton_explosion_sphere_pat", 1.2 },   -- explosion en sphère (patlick_atgparticules.pcf)
}
for _, fx in ipairs(IMPACT_FX) do PrecacheParticleSystem(fx[1]) end

net.Receive("jinton_cubes_sol", function()
    local pos = net.ReadVector()
    for _, def in ipairs(IMPACT_FX) do
        local fx = CreateParticleSystemNoEntity(def[1], pos, angle_zero)
        if fx then
            timer.Simple(def[2], function()
                if fx and fx:IsValid() then fx:StopEmission(false, true) end   -- true = disparaît tout de suite (pas de fondu)
            end)
        end
    end
end)
