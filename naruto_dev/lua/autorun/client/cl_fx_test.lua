--========================================================
-- Test de particules (CLIENT) : na_fx <nom> [secondes]
-- Joue la particule là où tu regardes (5 s par défaut), pour la voir avant de la brancher sur une technique.
--   Exemples : na_fx nr_chakra_Rasenshuriken   na_fx pat_rasenshuriken_explo 3   na_fx rasenshuri_pat 10
-- na_fx_liste <texte> : affiche les noms de la liste ci-dessous qui contiennent ce texte.
--========================================================

-- fichiers de particules chargés pour le test (ceux qui contiennent des Rasenshuriken / shuriken)
local PCF = {
    "argano3", "atg_particules", "patlick_atgparticules", "atg_particules_prison_aqueuse", "atg_faris",
    "kami_particles", "solve_futon", "solve_new_katon", "solve_jinton_geams", "patlick_atgsuiton", "solve_kami_geams",
}
for _, f in ipairs(PCF) do game.AddParticles("particles/" .. f .. ".pcf") end

local NOMS = {
    "nr_chakra_Rasenshuriken", "nr_chakra_Rasenshuriken_hit", "nr_Shoton_Shuriken_1", "nr_Shoton_Shuriken_hit",
    "nr_kenjutsu_minato_rasengan", "rasenshuri_pat", "pat_rasenshuriken_explo", "Rasenshuriken_Explosion_event_test",
    "atg_rasen_shuriken_explo", "shuriken", "shuriken_yome_pat", "shuriken_s_wind", "shurikensphere",
    "solve_wind_attach_wind_shuriken", "solve_katon_shuriken_aura", "solve_katon_shuriken_aura_start",
    "kami_shuriken", "_paper_shuriken", "rasengan_pat", "rasengan_hit_pat", "rasen_solve_explo", "rasengan",
}
for _, n in ipairs(NOMS) do PrecacheParticleSystem(n) end

concommand.Add("na_fx", function(ply, _, args)
    local nom = args[1]
    if not nom then print("Usage : na_fx <nom de particule> [secondes]   (na_fx_liste pour des idées)") return end
    local duree = tonumber(args[2]) or 5

    PrecacheParticleSystem(nom)
    local tr = ply:GetEyeTrace()
    local pos = tr.HitPos + tr.HitNormal * 5
    local fx = CreateParticleSystemNoEntity(nom, pos, angle_zero)
    if not fx then print("Particule introuvable : " .. nom) return end
    print("Particule jouée : " .. nom)
    timer.Simple(duree, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end
    end)
end)

concommand.Add("na_fx_liste", function(_, _, args)
    local filtre = string.lower(args[1] or "")
    for _, n in ipairs(NOMS) do
        if filtre == "" or string.find(string.lower(n), filtre, 1, true) then print(n) end
    end
end)
