--========================================================
-- Enregistrement dans wOS DynaBase des packs d'animations qui contiennent les animations du Chidori
-- (M_NI_SHT_Ninjutsu_Chidori_Charge_Lv1, _Run_Lv3_Loop, _Attack_Lv3_End...) : sans cet enregistrement, DynaBase ne
-- les ajoute pas au modèle du joueur et la séquence est "introuvable".
-- Les deux .mdl sont dans models/player/ de cet addon. Même format que les registres de Solve Naruto / Blade Symphony.
-- (wOS charge tous les fichiers de lua/wos/dynabase/registers/ ; il faut relancer la map après l'ajout.)
--========================================================

wOS.DynaBase:RegisterSource({
    Name = "NA Chidori (bb)",
    Type =  WOS_DYNABASE.EXTENSION,
    Shared = "models/player/kojin_wiltos/anim_extension_bb.mdl",
})

wOS.DynaBase:RegisterSource({
    Name = "NA Chidori (cancer)",
    Type =  WOS_DYNABASE.EXTENSION,
    Shared = "models/player/wiltos/anim_extension_cancer.mdl",
})

hook.Add( "PreLoadAnimations", "wOS.DynaBase.MountNAChidori", function( gender )
    if gender != WOS_DYNABASE.SHARED then return end

    IncludeModel( "models/player/kojin_wiltos/anim_extension_bb.mdl" )
    IncludeModel( "models/player/wiltos/anim_extension_cancer.mdl" )
end )
