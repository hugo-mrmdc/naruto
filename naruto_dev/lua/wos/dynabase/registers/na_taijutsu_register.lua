--========================================================
-- Enregistrement dans wOS DynaBase du pack d'animations de taijutsu ([ATG] RESSOURCES #3, workshop 3391053710).
-- models/anims_taijutsu.mdl contient 130 séquences (fsc_*_idle/walk/BL/BR/FL/FR, *_warwax_idle_sub...) mais ce pack
-- n'a aucun registre : sans cet enregistrement DynaBase ne les ajoute pas au modèle du joueur.
-- (Il faut relancer la map après l'ajout.)
--========================================================

wOS.DynaBase:RegisterSource({
    Name = "NA Taijutsu",
    Type =  WOS_DYNABASE.EXTENSION,
    Shared = "models/anims_taijutsu.mdl",
})

wOS.DynaBase:RegisterSource({
    Name = "NA Shinobi Attack",
    Type =  WOS_DYNABASE.EXTENSION,
    Shared = "models/shinobi_project_anm_attack.mdl",
})

hook.Add( "PreLoadAnimations", "wOS.DynaBase.MountNATaijutsu", function( gender )
    if gender != WOS_DYNABASE.SHARED then return end

    IncludeModel( "models/anims_taijutsu.mdl" )
    IncludeModel( "models/shinobi_project_anm_attack.mdl" )
end )
