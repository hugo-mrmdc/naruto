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
-- Niveau 1 = explosion seule (léger) ; 2 = + onde de choc et impact au sol (moyen) ; 3 = tout (très beau mais lourd).
-- Se règle en jeu avec la commande :  na_meteore_fx 1 / 2 / 3
local EFFETS = {
    { "solve_katon_chute_celeste_explo",         0,    2.5, 1 },   -- explosion principale
    { "solve_katon_explo_wave_floor_poing_xx",   0.05, 1.2, 2 },   -- onde de choc au sol
    { "solve_katon_floor_impact",                0.35, 1.2, 2 },   -- impact au sol
    { "solve_katon_gigaball_impact",             0.1,  2,   3 },   -- énorme impact de boule de feu (lourd)
    { "solve_katon_dragon_impact_big",           0.15, 2,   3 },   -- gros impact (lourd)
}
local cvFx = CreateClientConVar("na_meteore_fx", "2", true, false, "Qualité des effets du météore Katon : 1 léger, 2 moyen, 3 complet", 1, 3)

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
    local niveau = cvFx:GetInt()
    for _, e in ipairs(EFFETS) do
        if e[4] > niveau then continue end
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
