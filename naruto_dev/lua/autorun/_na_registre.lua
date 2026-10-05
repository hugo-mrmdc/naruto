--========================================================
-- Registre des techniques (chargé en PREMIER : le "_" passe avant les autres noms)
--
-- Chaque technique range sa fonction de lancement dans NA_Cast.<id>.
-- La touche historique de la technique ET la barre de techniques (touches 1 à 6)
-- passent toutes les deux par NA_Lancer(id) : une seule logique de lancement,
-- et une technique en recharge ne peut pas être lancée.
--========================================================

if SERVER then
    AddCSLuaFile()
    return
end

NA_Cast = NA_Cast or {}

----------------------------------------------------------
-- Menus (F2 techniques, F4 inventaire, F6 bibliothèque) : un seul ouvert à la fois.
-- Chaque menu s'inscrit avec sa fonction de fermeture, et ferme les autres
-- quand il s'ouvre.
----------------------------------------------------------
NA_Menus = NA_Menus or {}

function NA_EnregistrerMenu(nom, fermer)
    NA_Menus[nom] = fermer
end

function NA_FermerAutresMenus(nom)
    for autre, fermer in pairs(NA_Menus) do
        if autre ~= nom then fermer() end
    end
end

-- Touches historiques des techniques (N, Y, H, B, T, I...).
-- false = les techniques ne se lancent QUE depuis la barre (touches 1 à 6).
-- true  = les anciennes touches marchent aussi.
local TOUCHES_DIRECTES = false

function NA_TouchesDirectes()
    return TOUCHES_DIRECTES
end

----------------------------------------------------------
-- Recharges
-- Deux sources, on garde la plus longue :
--   1) la vraie recharge envoyée par le serveur (NA_CD, _na_cooldowns.lua) ;
--   2) la durée "cd" de la liste des techniques, comptée depuis le dernier
--      lancement : elle couvre le temps d'incantation, avant que le serveur
--      ait enregistré quoi que ce soit.
----------------------------------------------------------
NA_DernierLancer = NA_DernierLancer or {}
NA_DernierRefus = NA_DernierRefus or {}

local function CdListe(id)
    local info = NA_TechniqueParId and NA_TechniqueParId(id)
    local cd = info and info.cd or 0
    -- la recharge baisse avec le niveau de la technique (_na_niveaux.lua)
    if cd > 0 and NA_Stat then cd = NA_Stat(LocalPlayer(), id, "recharge", cd) end
    return cd
end

-- Secondes restantes avant de pouvoir relancer "id"
function NA_ResteRecharge(id)
    local ply = LocalPlayer()
    local serveur = (NA_CD and IsValid(ply)) and NA_CD.Reste(ply, id) or 0

    local local_ = 0
    local dernier = NA_DernierLancer[id]
    local cd = CdListe(id)
    if dernier and cd > 0 then
        local_ = math.max(0, cd - (CurTime() - dernier))
    end

    return math.max(serveur, local_)
end

-- Durée totale de la recharge en cours (pour le secteur de la barre)
function NA_DureeRecharge(id)
    local ply = LocalPlayer()
    local serveurReste = (NA_CD and IsValid(ply)) and NA_CD.Reste(ply, id) or 0
    local serveurTotal = (NA_CD and IsValid(ply)) and NA_CD.Total(ply, id) or 0
    local cd = CdListe(id)

    local dernier = NA_DernierLancer[id]
    local localReste = (dernier and cd > 0) and math.max(0, cd - (CurTime() - dernier)) or 0

    if serveurReste >= localReste and serveurTotal > 0 then
        return serveurTotal
    end
    return cd > 0 and cd or serveurTotal
end

----------------------------------------------------------
-- Délai avant la technique suivante
-- Après avoir lancé une technique, on ne peut en lancer AUCUNE autre pendant ce délai.
-- Valeur par technique : champ "delai" de son entrée dans cl_techniques_ui.lua, sinon la table ci-dessous,
-- sinon la valeur de son rang. Affiché dans la fiche de la technique (menu F2 / bibliothèque).
----------------------------------------------------------
NA_DELAI_RANG = { C = 0.4, B = 0.4, A = 0.4, S = 0.6 }
NA_DELAI_APRES = NA_DELAI_APRES or {
    -- id de technique = secondes avant de pouvoir lancer N'IMPORTE QUELLE autre technique (0 = aucun délai). Une technique absente
    -- de la liste prend la valeur de son rang (NA_DELAI_RANG ci-dessus).

    -- Katon
    katon_boule = 0.4,                 -- Boule de feu (rang C)
    katon_dome = 0.4,                  -- Dôme de feu (rang C)
    katon_souffle = 0.4,               -- Souffle katon (rang C)
    katon_tornade = 0.4,               -- Tornade de feu (rang B)
    katon_nuee = 1,                  -- Nuée ardente (rang A)
    katon_meteore = 0.6,               -- Météore (rang S)
    katon_grosse_boule = 0.4,          -- Grosse boule de feu (rang B)

    -- Uchiha
    katon_saut = 0.4,                  -- Boule de feu sautée (rang C)
    katon_dragons = 0.4,               -- Dragons de feu (rang B)
    uchiha_genjutsu = 0.4,             -- Genjutsu du Sharingan (rang B)
    uchiha_shuriken = 0.4,             -- Shuriken géant (rang C)

    -- Inkuton
    inkuton_chiens = 0.4,              -- Chiens d'encre (rang C)
    inkuton_singes = 0.4,              -- Singes d'encre (rang B)
    inkuton_serpents = 0.4,            -- Serpents d'encre (rang C)
    inkuton_moine = 0.4,               -- Moine d'encre (rang B)
    inkuton_dieux = 0.4,               -- Dieux d'encre (rang A)
    inkuton_dragon = 0.6,              -- Dragon d'encre (rang S)

    -- Bakuton
    bakuton_oiseaux = 0.4,             -- Oiseaux explosifs (rang C)
    bakuton_mignons = 0.4,             -- Mignons d'argile (rang C)
    bakuton_araignees = 0.4,           -- Mines explosives (rang B)
    bakuton_meute = 0.4,               -- Meute d'araignées (rang B)
    bakuton_dragon = 0.4,              -- Dragon d'argile (rang B)
    bakuton_bombe = 0.6,               -- Déflagration (rang S)

    -- Futton
    futton_vapeur = 0.4,               -- Émanation de vapeur (rang C)
    futton_tornade = 0.4,              -- Tornade de vapeur (rang C)
    futton_cage = 0.4,                 -- Cage de vapeur (rang B)
    futton_monde = 0.6,                -- Monde de vapeur (rang S)

    -- Hyoton
    hyoton_dome = 0.4,                 -- Dôme de glace (rang C)
    hyoton_pics = 0.4,                 -- Pics de glace (rang C)
    hyoton_vague = 0.4,                -- Vague de glace (rang B)
    hyoton_loup = 0.4,                 -- Loups de glace (rang B)
    hyoton_prison = 0.4,               -- Prison de glace (rang A)

    -- Shoton
    shoton_cristal = 0.4,              -- Cristal (rang C)
    shoton_armure = 0.4,               -- Armure de cristal (rang C)
    shoton_rockets = 0.4,              -- Roquettes (rang B)
    shoton_pics = 0.4,                 -- Pics de cristal (rang A)
    shoton_chute = 0.4,                -- Chute de cristal (rang B)

    -- Futton
    futton_prison = 0.4,               -- Prison de vapeur (rang A)
    futton_projectile = 0.4,           -- Projectile de vapeur (rang B)

    -- Suiton
    suiton_requin = 0.4,               -- Requin d'eau (rang B)
    suiton_tsunami = 0.6,              -- Tsunami (rang S)
    suiton_ocean = 0.4,                -- Océan (rang A)
    suiton_pluie = 0.4,                -- Pluie suiton (rang B)
    suiton_waterball = 0.4,            -- Boule d'eau (rang C)
    suiton_prison = 0.4,               -- Prison aqueuse (rang C)
    suiton_bulle = 0.4,                -- Bulles (rang C)

    -- Futon
    futon_windslash = 0.4,             -- Wind Slash (rang C)
    futon_tornade = 0.4,               -- Tornade (rang C)
    futon_windball = 0.4,              -- Wind Ball (rang C)
    futon_ouragan = 0.4,               -- Ouragan de vent (rang B)
    futon_grand_ouragan = 0.4,         -- Grand ouragan (rang A)
    futon_rasenshuriken = 0.6,         -- Rasenshuriken (rang S)
    futon_expulsion = 0.4,             -- Expulsion de vent (rang B)

    -- Raiton
    raiton_jugement = 0.4,             -- Jugement de l'éclair (rang C)
    raiton_cercle = 0.4,               -- Cercle de foudre (rang C)
    raiton_zone = 0.4,                 -- Zone de foudre (rang B)
    raiton_chidori = 0.4,              -- Chidori (rang A)
    raiton_kirin = 0.6,                -- Kirin (rang S)
    raiton_poing = 0.4,                -- Poing de foudre (rang B)
    raiton_boule = 0.4,                -- Boule de foudre (rang C)

    -- Doton
    doton_pierre = 0.4,                -- Boule de roche (rang C)
    doton_seisme = 0.4,                -- Séisme (rang C)
    doton_taupe = 0.4,                 -- Voyage souterrain (rang C)
    doton_pics = 0.4,                  -- Pics de pierre (rang B)
    doton_dragon = 0.4,                -- Dragon de terre (rang A)
    doton_golem = 0.6,                 -- Golem de roche (rang S)
    doton_eruption = 0.4,              -- Éruption de roche (rang B)

    -- Mokuton
    mokuton_arche = 0.4,               -- Arche (rang C)
    mokuton_fleur = 0.4,               -- Fleur (rang C)
    mokuton_protection = 0.4,          -- Protection de bois (rang C)
    mokuton_wood_hand = 0.4,           -- Mains de bois (rang B)
    mokuton_dragon = 0.4,              -- Dragon (rang B)
    mokuton_golem = 0.4,               -- Golem de bois (rang A)

    -- Salamandre
    salamandre_dome = 0.4,             -- Dôme de brume (rang B)
    salamandre_poison = 0.4,           -- Crachat de poison (rang C)
    salamandre_tornade = 0.4,          -- Typhon de poison (rang A)
    salamandre_corps = 0.4,            -- Corps de poison (rang B)

    -- Fuma
    fuma_tp = 0.4,                     -- Téléportation (rang C)
    fuma_jugement = 0.4,               -- Jugement des Quatre Lames (rang B)
    fuma_aura = 0.4,                   -- Aura Fuma (rang B)
    fuma_ciel = 0.4,                   -- Shuriken Céleste (rang A)
    fuma_invisibilite = 0.4,           -- Invisibilité (rang C)

    -- Kami
    kami_circle = 0.4,                 -- Kami Circle (rang B)
    kami_shuriken = 0.4,               -- Shuriken de papier (rang C)
    kami_bouclier = 0.4,               -- Paper Shield (rang B)
    kami_ailes = 0.4,                  -- Ailes de papier (rang A)
    kami_roue = 0.4,                   -- Roue de papier (rang B)

    -- Jinton
    jinton_cube = 0.4,                 -- Cube de confinement (rang C)
    jinton_bouclier = 0.4,             -- Bouclier Jinton (rang C)
    jinton_laser = 0.4,                -- Rayon de dissolution (rang A)

    -- Kaguya
    kaguya_armure = 0.4,               -- Armure d'os (rang C)
    kaguya_legion = 0.4,               -- Légion d'os (rang A)
    kaguya_danse = 0.4,                -- Danse des os (rang C)

    -- Senju
    senju_renfo = 0.4,                 -- Renforcement Senju (rang B)
    senju_soin = 0.4,                  -- Soin Senju (rang B)
    senju_frappe = 0.4,                -- Frappe terrestre (rang B)
    senju_pied = 0.4,                  -- Coup de pied céleste (rang A)
    senju_ermite = 0.6,                -- Ermite naturel (rang S)

    -- Chinoike
    chinoike_ketsuryugan = 0.4,        -- Ketsuryugan (rang C)
    chinoike_genjutsu = 0.4,           -- Genjutsu du Ketsuryugan (rang C)
    chinoike_pluie = 0.4,              -- Pluie de sang (rang B)
    chinoike_vortex = 0.4,             -- Vortex de sang (rang B)

    -- Hyuga
    hyuga_byakugan = 0.4,              -- Byakugan (rang C)
    hyuga_paume = 0.4,                 -- Paume du Hakke (rang C)
    hyuga_32points = 0.4,              -- 32 Points du Hakke (rang B)
    hyuga_64points = 0.4,              -- 64 Points du Hakke (rang A)
    hyuga_tourbillon = 0.4,            -- Tourbillon Divin (rang A)

    -- Uchiha
    uchiha_sharingan = 0.4,            -- Sharingan (rang C)

    -- Kiminari
    kiminari_frappe = 0.4,             -- Frappe noire (rang C)
    kiminari_prison = 0.4,             -- Prison noire (rang C)
    kiminari_laser = 0.4,              -- Laser Circus (rang B)
    kiminari_boulets = 0.4,            -- Boulets noirs (rang A)

    -- Jiton
    jiton_sarcophage = 0.4,            -- Sarcophage de sable (rang C)
    jiton_emergence = 0.4,             -- Émergence de sable (rang C)
    jiton_vortex = 0.4,                -- Vortex de sable (rang B)
    jiton_tornade = 0.4,               -- Tornade de sable (rang B)
    jiton_nuage = 0.4,                 -- Nuage de sable (rang A)
}
NA_VerrouFin = NA_VerrouFin or 0   -- jusqu'à quand aucune technique ne peut être lancée

function NA_DelaiApres(id)
    local info = NA_TechniqueParId and NA_TechniqueParId(id)
    return (info and info.delai) or NA_DELAI_APRES[id] or NA_DELAI_RANG[info and info.rang or "C"] or 0.5
end

----------------------------------------------------------
-- Techniques à activer / désactiver (même touche)
--   id -> NW2Bool posé par le serveur tant que la technique est active.
-- Quand elle est active, rappuyer la COUPE toujours : ni recharge, ni mains
-- vides, ni immobilisation ne peuvent empêcher de l'arrêter.
----------------------------------------------------------
NA_BASCULES = NA_BASCULES or {}
NA_BASCULES.chinoike_ketsuryugan = "NA_Ketsuryugan"   -- sv_chinoike_ketsuryugan.lua
NA_BASCULES.kaguya_armure = "NA_ArmureOs"             -- sv_kaguya_armure.lua
NA_BASCULES.senju_renfo = "NA_SenjuRenfo"              -- server/senju/sv_senju_renfo.lua
NA_BASCULES.senju_ermite = "NA_SenjuErmite"            -- server/senju/sv_senju_ermite.lua
NA_BASCULES.hyuga_byakugan = "NA_Byakugan"            -- server/hyuga/sv_hyuga_byakugan.lua
NA_BASCULES.uchiha_sharingan = "NA_Sharingan"          -- server/uchiha/sv_uchiha_sharingan.lua
NA_BASCULES.doton_golem = "NA_Golem"                  -- server/doton/sv_doton_golem.lua (rappuyer détruit le golem)
NA_BASCULES.mokuton_golem = "NA_Golem"                -- server/mokuton/mokuton_golem_sv.lua (rappuyer redonne l'apparence normale)

function NA_TechniqueActive(id, ply)
    ply = ply or LocalPlayer()
    local nw = NA_BASCULES[id]
    return nw ~= nil and IsValid(ply) and ply:GetNW2Bool(nw, false)
end

----------------------------------------------------------
-- Lancement
----------------------------------------------------------
-- developer 1 : raison des refus affichée dans la console
local function Diag(id, raison)
    local dev = GetConVar("developer")
    if dev and dev:GetInt() > 0 then print("[Techniques] " .. id .. " refusé : " .. raison) end
end

function NA_Lancer(id)
    local fn = NA_Cast[id]
    if not fn then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return false end

    -- technique active : rappuyer la coupe, sans aucune autre vérification
    if NA_TechniqueActive(id, ply) then
        local ok, err = pcall(fn)
        if not ok then
            MsgC(Color(255, 80, 80), "[Techniques] erreur en coupant " .. id .. " : " .. tostring(err) .. "\n")
            return false
        end
        Diag(id, "désactivation envoyée")
        NA_DernierLancer[id] = CurTime()
        return true
    end

    -- pas encore débloquée dans la bibliothèque (F6, _na_niveaux.lua)
    if NA_Debloquee and not NA_Debloquee(ply, id) then
        NA_DernierRefus[id] = CurTime()
        notification.AddLegacy("Technique verrouillée : débloque-la dans la bibliothèque (F6).", NOTIFY_ERROR, 3)
        Diag(id, "pas débloquée")
        return false
    end

    -- sous terre (Doton : voyage souterrain) : pas de jutsu, E pour ressortir (sv_doton_taupe.lua)
    if ply:GetNW2Bool("NA_Souterrain", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "sous terre")
        return false
    end

    -- transformé en golem (Mokuton) : pas de jutsu ; seul le golem lui-même se relance (c'est la bascule ci-dessus)
    if ply:GetNW2Bool("NA_Golem", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "transformé en golem")
        return false
    end

    -- dans le cocon de bois (Mokuton : protection) : pas de jutsu, sauf les 0.2 dernières secondes
    -- (NA_HobiJutsu, server/mokuton/mokuton_protection_sv.lua ; NA_Hobi reste vrai un peu plus longtemps,
    -- pour l'invincibilité et le cocon visible)
    if ply:GetNW2Bool("NA_HobiJutsu", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "dans le cocon de bois")
        return false
    end

    -- en train de recharger son chakra (R) : pas de jutsu
    if NA_EnRechargeChakra and NA_EnRechargeChakra(ply) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "recharge du chakra en cours")
        return false
    end

    -- immobilisé (cube Jinton...) : pas de jutsu
    if ply:GetNW2Bool("NA_Etourdi", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "tu es immobilisé")
        return false
    end

    -- singes d'encre accrochés (sv_inkuton_singes.lua) : pas de jutsu
    if ply:GetNW2Bool("NA_Singes", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "des singes d'encre te tiennent")
        return false
    end

    -- technique canalisée en cours (32 Points du Hakke, Tourbillon Divin...) :
    -- pas d'autre jutsu tant qu'elle dure (NW2Bool générique, réutilisable)
    if ply:GetNW2Bool("NA_Canalise", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "technique canalisée en cours")
        return false
    end

    -- sur la vague du Tsunami (Suiton, rang A) : pas d'autre jutsu tant qu'elle dure (le Tsunami lui-même se relance pour en descendre :
    -- c'est la bascule en haut de la fonction)
    if ply:GetNW2Float("NA_TsunamiFin", 0) > CurTime() then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "sur la vague du Tsunami")
        return false
    end

    -- sur un dragon monté (Bakuton NA_Dragon, Mokuton MokutonRide, Inkuton InkutonRide) : pas d'autre jutsu, quel que soit le
    -- dragon (pas les Dragons de feu Katon, qui ne se montent pas). Seul le dragon lui-même se relance (pour en descendre / le renvoyer).
    if (ply:GetNW2Bool("NA_Dragon", false) or ply:GetNWBool("MokutonRide", false) or ply:GetNWBool("InkutonRide", false))
        and id ~= "bakuton_dragon" and id ~= "mokuton_dragon" and id ~= "inkuton_dragon" then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "sur un dragon")
        return false
    end

    -- mains vides ou mode caméra : pas de jutsu (cl_selecteur_armes.lua)
    if NA_JutsuBloque and NA_JutsuBloque(ply) then
        NA_DernierRefus[id] = CurTime()   -- la case clignote en rouge, sans son
        Diag(id, "mains vides ou mode caméra")
        return false
    end

    -- délai après la technique précédente
    if NA_VerrouFin > CurTime() then
        Diag(id, string.format("délai après la technique précédente (%.1f s)", NA_VerrouFin - CurTime()))
        NA_DernierRefus[id] = CurTime()
        return false
    end

    -- en recharge : pas utilisable
    if NA_ResteRecharge(id) > 0 then
        Diag(id, string.format("en recharge (%.1f s)", NA_ResteRecharge(id)))
        NA_DernierRefus[id] = CurTime()   -- la case clignote en rouge, sans son
        return false
    end

    local ok, err = pcall(fn)
    if not ok then
        MsgC(Color(255, 80, 80), "[Techniques] erreur en lançant " .. id .. " : " .. tostring(err) .. "\n")
        return false
    end

    NA_DernierLancer[id] = CurTime()
    NA_VerrouFin = CurTime() + NA_DelaiApres(id)
    if NA_DemarrerDuree then NA_DemarrerDuree(id) end   -- barre de durée (cl_duration_bars.lua)

    -- un jutsu lancé pendant l'invisibilité Fuma fait réapparaître (sv_fumainv.lua)
    if id ~= "fuma_invisibilite" and ply:GetNWBool("IsInvisible", false) then
        net.Start("Invis_Reveler")
        net.SendToServer()
    end

    -- lancer une technique coupe la course de chakra (sv_sprint_chakra.lua)
    if ply:GetNW2Bool("NA_ChakraRun", false) then
        net.Start("NA_ArretCourseChakra")
        net.SendToServer()
    end
    return true
end
