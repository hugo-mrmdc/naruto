--========================================================
-- Kenjutsu : Aller-retour (CLIENT)
-- Lancement depuis la barre de techniques ; animation, coups et particules sont côté serveur.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kenjutsu_allerretour = function()
    -- pas de cible à portée : on ne lance rien (même zone que le serveur, sv_kenjutsu_allerretour.lua)
    local ply = LocalPlayer()
    local portee = NA_Stat and NA_Stat(ply, "kenjutsu_allerretour", "portee", 450) or 450
    local trouve = false
    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), portee)) do
        if ent ~= ply and ((ent:IsPlayer() and ent:Alive()) or ent:IsNPC() or ent:IsNextBot()) then trouve = true break end
    end
    if not trouve then return false end

    net.Start("kenjutsu_allerretour_cast")
    net.SendToServer()
end

game.AddParticles("particles/solve_kenjutsu_expert.pcf")
PrecacheParticleSystem("solve_ken_nrm_hit_03")
PrecacheParticleSystem("solve_ken_nrm_hit_03_circle")
