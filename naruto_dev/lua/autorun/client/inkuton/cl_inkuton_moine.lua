-- Inkuton : Moine d'encre (CLIENT) : lancement depuis la barre de techniques, et chargement des ressources.
--
-- Particules et modèle sont chargés ICI, une seule fois au démarrage, et non à chaque apparition d'un moine :
-- game.AddParticles sur un gros .pcf (patlick_atgparticules.pcf : 2,8 Mo) et le chargement d'un modèle au premier
-- affichage provoquaient un micro freeze à chaque invocation. Les noms doivent rester ceux de l'entité inkuton_moine.
game.AddParticles("particles/solve_inkuton_geams.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
for _, fx in ipairs({
    "solve_inkuton_dispawn_moine", "solve_inkuton_moine_spawn_trap", "solve_inkuton_moine_rush", "golem_encre_impact_pat",
}) do
    PrecacheParticleSystem(fx)
end
util.PrecacheModel("models/inkuton/inkutonmonk.mdl")

NA_Cast = NA_Cast or {}
NA_Cast.inkuton_moine = function()
    net.Start("inkuton_moine_cast")
    net.SendToServer()
end
