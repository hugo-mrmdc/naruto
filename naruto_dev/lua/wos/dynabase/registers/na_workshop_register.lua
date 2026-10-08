--========================================================
-- Enregistrement dans wOS DynaBase de packs d'animations du workshop 3391053710 ([ATG] RESSOURCES #3).
-- Les .mdl sont montés avec le workshop (pas copiés dans cet addon). Même format que na_taijutsu_register.lua.
--
--   Shinobi (shinobi_project_anm_*) : NON montés, squelette incompatible (voir plus bas).
--   ATG poscomb     : atg_poscomb (747 séquences "solve_naruto_*_attacks_combo*") + anim_extension_riddick (90 "atg_*")
--
-- Il faut relancer la map après l'ajout. Le moteur limite le nombre de séquences d'un modèle : pour en
-- alléger un, retire sa ligne dans LISTE.
--========================================================

local LISTE = {
    -- Shinobi combat / ninjutsu : DÉSACTIVÉS. Les packs shinobi_project_anm_* (et anims_taijutsu en grande partie) sont faits
    -- pour un autre squelette (CharacterRoot, Hips, Spine...) : sur un joueur ValveBiped le moteur ignore toutes leurs
    -- séquences (vérifié avec na_anim_liste : 0 séquence présente). Il faudrait les retargeter pour les utiliser.
    -- ATG poscomb
    { "NA ATG Poscomb",             "models/anim/atg_poscomb.mdl" },
    { "NA ATG Riddick",             "models/anim/atg_anim_extension_riddick.mdl" },
}

for _, p in ipairs(LISTE) do
    wOS.DynaBase:RegisterSource({
        Name = p[1],
        Type = WOS_DYNABASE.EXTENSION,
        Shared = p[2],
    })
end

hook.Add( "PreLoadAnimations", "wOS.DynaBase.MountNAWorkshop", function( gender )
    if gender != WOS_DYNABASE.SHARED then return end

    for _, p in ipairs(LISTE) do
        IncludeModel( p[2] )
    end
end )
