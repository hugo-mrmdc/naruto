--========================================================
-- Liste des animations du joueur (CLIENT)
--
--   na_anim_liste            résumé : nombre de séquences par pack
--   na_anim_liste [filtre]   écrit dans garrysmod/data/na_anim_liste.txt les séquences de ton modèle
--                            dont le nom contient "filtre" (sans filtre : toutes) et en résume le
--                            nombre dans la console. Utile pour vérifier qu'un pack DynaBase est monté.
--   Exemples : na_anim_liste CustomMan_Guard   /   na_anim_liste solve_naruto   /   na_anim_liste atg_
--========================================================
concommand.Add("na_anim_liste", function(_, _, args)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local filtre = string.lower(args[1] or "")

    -- sans filtre : résumé par pack (un nom de séquence typique de chaque pack monté)
    if filtre == "" then
        local packs = {
            { "mod6 / nrp (anciens packs)", "nrp_sword" }, { "anims_taijutsu", "fsc_" }, { "phalanx", "phalanx_" },
            { "ryoku", "ryoku_" }, { "Shinobi CustomMan", "customman_" }, { "Shinobi Bee", "bee_" },
            { "Shinobi guard", "guard_" }, { "ATG riddick", "atg_" }, { "ATG poscomb", "solve_naruto" },
        }
        local n = ply:GetSequenceCount()
        MsgC(Color(255, 180, 80), "[Anim] ", color_white, ply:GetModel(), " : ", n, " séquences au total
")
        local compte = {}
        for i = 0, n - 1 do
            local nom = string.lower(ply:GetSequenceName(i) or "")
            for k, p in ipairs(packs) do
                if string.find(nom, p[2], 1, true) then compte[k] = (compte[k] or 0) + 1 end
            end
        end
        for k, p in ipairs(packs) do print(string.format("   %-28s (%-14s) : %d", p[1], p[2], compte[k] or 0)) end
        return
    end

    local lignes, n = {}, ply:GetSequenceCount()
    for i = 0, n - 1 do
        local nom = ply:GetSequenceName(i)
        if nom and (filtre == "" or string.find(string.lower(nom), filtre, 1, true)) then
            lignes[#lignes + 1] = i .. "  " .. nom
        end
    end

    file.Write("na_anim_liste.txt", "modele: " .. ply:GetModel() .. "\nsequences totales: " .. n ..
        "\nfiltre: " .. (filtre == "" and "(aucun)" or filtre) .. "\ntrouvées: " .. #lignes .. "\n\n" .. table.concat(lignes, "\n"))

    MsgC(Color(255, 180, 80), "[Anim] ", color_white, ply:GetModel(), " : ", n, " séquences au total, ",
        #lignes, " pour le filtre \"", filtre, "\" -> data/na_anim_liste.txt\n")
    for i = 1, math.min(#lignes, 15) do print("   " .. lignes[i]) end
    if #lignes > 15 then print("   ... (la suite est dans le fichier)") end
end)
