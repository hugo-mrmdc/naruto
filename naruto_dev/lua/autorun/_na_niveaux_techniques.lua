--========================================================
-- Stats des techniques NIVEAU PAR NIVEAU (PARTAGÉ serveur + client)
--
-- C'est ICI qu'on règle ce que chaque niveau change sur une technique.
--
--   NA_NIV_TECH.<id de la technique> = {
--       [1] = { stat = valeur, ... },   -- niveau 1 : TOUTES les stats réglées
--       [2] = { stat = valeur },        -- niveaux suivants : seulement ce qui change
--       ...
--   }
--
-- Un niveau qui ne donne pas une stat garde la valeur du niveau d'avant.
-- Une stat réglée ici REMPLACE le pourcentage général (PAR_NIVEAU de _na_niveaux.lua).
-- Une technique absente de ce fichier garde le pourcentage général.
--
-- Côté serveur, la technique lit la stat avec :
--   NA_Stat(ply, "chinoike_vortex", "rayon", RAYON_COEUR)
-- (la valeur de base sert si la stat n'est pas réglée ici)
--
-- Stats déjà branchées dans toutes les techniques : degats, chakra, recharge
-- (+ soin pour kaguya_danse, recharge_rate pour fuma_jugement).
--
-- "hitbox" = DEMI-taille de la zone qui touche (plus grand = plus facile à toucher).
-- Branchée dans les techniques qui ont une hitbox :
--   katon_boule (18), katon_saut (18), suiton_requin (18), mokuton_arche (40, visée),
--   fuma_tp (16, joueurs/PNJ seulement), fuma_jugement (18, le fil),
--   jinton_cube (20, visée), jinton_laser (45), salamandre_poison (6)
--   (entre parenthèses : valeur actuelle dans le fichier serveur)
-- Pour une autre stat (durée, rayon...), il faut la passer par NA_Stat dans le
-- fichier serveur de la technique (voir sv_chinoike_vortex.lua).
--
-- Les stats réglées ici s'affichent dans la fiche de la bibliothèque (F6),
-- avec la valeur actuelle -> valeur au niveau suivant.
--========================================================

if SERVER then AddCSLuaFile() end

NA_NIV = NA_NIV or {}
NA_NIV_TECH = NA_NIV_TECH or {}

-- Nom affiché dans la bibliothèque et unité, dans l'ordre d'affichage.
-- Une stat absente de cette liste s'affiche avec son nom en majuscules.
NA_NIV.NOMS = {
    { "degats",     "DÉGÂTS",      "" },
    { "soin",       "SOIN",        "" },
    { "chakra",     "CHAKRA",      "" },
    { "recharge",   "RECHARGE",    " S" },
    { "duree",      "DURÉE",       " S" },
    { "rayon",      "RAYON",       "" },
    { "hitbox",     "HITBOX",      "" },
    { "portee",     "PORTÉE",      "" },
    { "force",      "FORCE",       "" },
    { "vitesse",    "VITESSE",     "" },
    { "nombre",     "NOMBRE",      "" },
}

--========================================================
-- Chinoike : Vortex de sang (sv_chinoike_vortex.lua)
--========================================================
NA_NIV_TECH.chinoike_vortex = {
    [1] = { degats = 10, chakra = 30, recharge = 20, duree = 3.5, rayon = 200, force = 3000 },
    [2] = { degats = 12 },
    [3] = { degats = 14, duree = 4,   rayon = 230 },
    [4] = { degats = 16, recharge = 18 },
    [5] = { degats = 20, duree = 5,   rayon = 260, force = 3600 },
}

--========================================================
-- Modèle à copier pour une autre technique :
--
-- NA_NIV_TECH.katon_boule = {
--     [1] = { degats = 25, chakra = 15, recharge = 1, hitbox = 18 },
--     [2] = { degats = 30 },
--     [3] = { degats = 35, recharge = 0.8, hitbox = 24 },
--     [4] = { degats = 40 },
--     [5] = { degats = 50, chakra = 10 },
-- }
--========================================================
