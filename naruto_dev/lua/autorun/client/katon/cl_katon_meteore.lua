--========================================================
-- Katon : Météore (CLIENT)
-- Lancement depuis la barre de techniques ; particule solve_katon_chute_celeste_explo (particles/solve_new_katon.pcf) au point
-- d'impact envoyé par le serveur (message "katon_meteore_fx", sv_katon_meteore.lua). Le météore lui-même est affiché par
-- l'entité katon_meteore.
--
-- Comme la Nuée ardente, la particule est posée avec ses DEUX premiers points de contrôle au même endroit (sinon, si elle
-- se sert du point 1, elle apparaîtrait autour de l'origine de la carte).
--========================================================

-- Particules jouées à l'impact (particles/solve_new_katon.pcf), { nom, délai en secondes, durée avant arrêt }. La première est
-- l'explosion principale ; les suivantes l'accompagnent. Retire une ligne pour la supprimer, ajoute-en pour en rajouter
-- (noms possibles : solve_katon_bigball_impact, solve_katon_gigaball_impact, solve_katon_floor_impact, solve_katon_new_ring,
-- solve_katon_explo_wave_floor_poing_xx, solve_katon_dragon_impact_big, solve_katon_multipleballs_impact, solve_katon_tornado_floor...).
local EFFETS = {
    { "solve_katon_chute_celeste_explo",         0,    4 },   -- explosion principale
    { "solve_katon_gigaball_impact",             0,    3 },   -- énorme impact de boule de feu
    { "solve_katon_explo_wave_floor_poing_xx",   0.05, 3 },   -- onde de choc au sol
    { "solve_katon_floor_impact",                0.1,  3 },   -- impact au sol
    { "solve_katon_dragon_impact_big",           0.15, 3 },   -- gros impact
}

game.AddParticles("particles/solve_new_katon.pcf")
for _, e in ipairs(EFFETS) do PrecacheParticleSystem(e[1]) end
util.PrecacheModel("models/nature/katon/atg_katon_meteor.mdl")

NA_Cast = NA_Cast or {}
NA_Cast.katon_meteore = function()
    net.Start("katon_meteore_cast")
    net.SendToServer()
end

net.Receive("katon_meteore_fx", function()
    local pos = net.ReadVector()
    for _, e in ipairs(EFFETS) do
        local nom, delai, duree = e[1], e[2], e[3]
        timer.Simple(delai, function()
            local fx = CreateParticleSystemNoEntity(nom, pos)
            if not fx then return end
            fx:SetControlPoint(0, pos)
            fx:SetControlPoint(1, pos)
            timer.Simple(duree, function()
                if fx and fx:IsValid() then fx:StopEmission(false, true) end
            end)
        end)
    end
end)
