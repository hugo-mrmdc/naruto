--========================================================
-- Apparence du joueur (SERVEUR) : tenue + tête + cheveux
--
-- Les tenues sont des corps sans tête : on fusionne au squelette du joueur un
-- modèle de tête et un modèle de cheveux (prop_dynamic en EF_BONEMERGE).
--
-- Utilisé ailleurs, NE PAS renommer :
--   ply.NA_Head / ply.NA_Hair      -> invisibilité Fuma (sv_fumainv.lua), gamemode
--   hook PlayerSpawn "NA_SetHeadAndHair" -> détection par le gamemode Naruto RP
--   NA_AppliquerApparence(ply)     -> à appeler après tout changement de modèle
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES
--========================================================
local TENUE_DEFAUT   = "models/tenue/senju/genin/senju_a.mdl"
local COULEUR_CORPS  = Color(255, 210, 180)     -- teinte appliquée au modèle du joueur

-- Tête : PAS de teinte sur toute la tête (elle colorait aussi le blanc des yeux) ;
-- la couleur de peau est dans le matériau du visage ($color2 de
-- materials/models/naruto_dev/tete/visage.vmt), posé sur le matériau 0 (visage).
local TETE    = { modele = "models/head_03.mdl",     couleur = Color(255, 255, 255), visage = "models/naruto_dev/tete/visage" }
local CHEVEUX = { modele = "models/hairs1_head.mdl", couleur = Color(0, 0, 0) }

-- Modèles qui ont DÉJÀ une tête : on n'y ajoute ni tête ni cheveux
-- (sinon deux têtes l'une dans l'autre). Un préfixe suffit.
local MODELES_AVEC_TETE = {
    "models/player/",
}

-- Délai après l'apparition : laisse les autres scripts (gamemode, loadout)
-- poser leur modèle avant qu'on ajoute la tête.
local DELAI = 0.1
--========================================================

resource.AddFile("materials/" .. TETE.visage .. ".vmt")

-- tenue par défaut, partagée avec sv_armure.lua (retrait de tenue)
NA_TENUE_DEFAUT = TENUE_DEFAUT

local function ADejaUneTete(modele)
    modele = string.lower(modele or "")
    for _, prefixe in ipairs(MODELES_AVEC_TETE) do
        if string.StartWith(modele, prefixe) then return true end
    end
    return false
end

local function RetirerPieces(ply)
    for _, cle in ipairs({ "NA_Head", "NA_Hair" }) do
        if IsValid(ply[cle]) then ply[cle]:Remove() end
        ply[cle] = nil
    end
end

-- Respecte l'invisibilité Fuma si elle est active
local function AppliquerInvisibilite(ply, ent)
    if not IsValid(ent) then return end
    local normale = ent.__NA_NormalColor or color_white

    if ply:GetNWBool("IsInvisible", false) then
        ent:SetNoDraw(true)
        ent:DrawShadow(false)
        ent:SetColor(Color(normale.r, normale.g, normale.b, 0))
    else
        ent:SetNoDraw(false)
        ent:DrawShadow(true)
        ent:SetColor(normale)
    end
end

-- Tête et cheveux du joueur : les réglages ci-dessus, modifiés par son choix
-- (menu de personnalisation : sv_perso.lua). Rend aussi le choix lui-même.
local function Definitions(ply)
    local p = NA_PersoDe and NA_PersoDe(ply) or NA_PERSO.DEFAUT
    local tete, cheveux = table.Copy(TETE), table.Copy(CHEVEUX)

    if p.visage > 0 then
        tete.modele = NA_PERSO.ModeleTete(p)
        tete.visage = nil   -- pas de matériau de la tête d'origine : la peau est posée côté client
        tete.barbe  = p.barbe
    end
    cheveux.modele = NA_PERSO.ModeleCheveux(p)
    cheveux.coupe = NA_PERSO.CoupeCheveux(p)   -- coupe (bodygroup) du modèle d'origine
    -- pas de teinte sur le modèle (elle colorerait bandeaux et bandages) : la couleur des
    -- cheveux est posée côté client sur leur matériau (NA_TeinterCheveux, cl_perso.lua)
    cheveux.couleur = Color(255, 255, 255)
    return tete, cheveux, p
end

local function CreerPiece(ply, def)
    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    ent:SetModel(def.modele)
    ent:SetPos(ply:GetPos())
    ent:SetAngles(ply:GetAngles())
    ent:Spawn()

    ent:SetParent(ply)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_BONEMERGE_FASTCULL)
    ent:AddEffects(EF_PARENT_ANIMATES)
    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetOwner(ply)
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)

    ent.__NA_NormalColor = def.couleur
    ent:SetColor(def.couleur)
    if def.visage then ent:SetSubMaterial(0, def.visage) end   -- visage teinté couleur peau
    if def.coupe then ent:SetBodygroup(0, def.coupe) end       -- bodygroup "Headgear" du modèle de coiffure d'origine
    if def.barbe then ent:SetBodygroup(1, def.barbe) end       -- bodygroup "beard" des visages

    AppliquerInvisibilite(ply, ent)
    return ent
end

-- Informe les clients des pièces portées (utilisé pour les poser sur le corps
-- après la mort, voir cl_playerskin.lua). Chaîne vide = aucune.
local function Publier(ply, avecTete, tete, cheveux, choix)
    ply:SetNW2String("NA_TeteModele", avecTete and tete.modele or "")
    ply:SetNW2String("NA_CheveuxModele", avecTete and cheveux.modele or "")
    ply:SetNW2Vector("NA_TeteCouleur", Vector(tete.couleur.r, tete.couleur.g, tete.couleur.b))
    ply:SetNW2Vector("NA_CheveuxCouleur", Vector(cheveux.couleur.r, cheveux.couleur.g, cheveux.couleur.b))
    ply:SetNW2String("NA_TeteVisage", avecTete and tete.visage or "")
    ply:SetNW2String("NA_Perso", avecTete and NA_PERSO.Encoder(choix) or "")   -- détails du visage (cl_perso.lua)
    -- entité de la tête : les clients la font cligner des yeux (cl_clignement.lua)
    ply:SetNW2Entity("NA_TeteEnt", avecTete and ply.NA_Head or NULL)
    ply:SetNW2Entity("NA_CheveuxEnt", avecTete and ply.NA_Hair or NULL)   -- couleur des cheveux : cl_perso.lua
end

----------------------------------------------------------
-- Pose (ou retire) la tête et les cheveux selon le modèle ACTUEL du joueur.
-- À appeler après chaque SetModel (tenue équipée, gamemode...).
----------------------------------------------------------
function NA_AppliquerApparence(ply)
    if not IsValid(ply) then return end

    RetirerPieces(ply)

    if not ply:Alive() or ADejaUneTete(ply:GetModel()) then
        Publier(ply, false, TETE, CHEVEUX)
        return
    end

    if not ply:LookupBone("ValveBiped.Bip01_Head1") and not ply:LookupBone("ValveBiped.Bip01_Head") then
        -- modèle sans squelette humain : rien à fusionner
        Publier(ply, false, TETE, CHEVEUX)
        return
    end

    local tete, cheveux, choix = Definitions(ply)
    ply.NA_Head = CreerPiece(ply, tete)
    ply.NA_Hair = CreerPiece(ply, cheveux)
    Publier(ply, true, tete, cheveux, choix)

    -- pas de teinte sur le joueur : elle colorerait aussi la tenue. La peau du corps est
    -- teintée à part, côté client (NA_PeauCorps, cl_perso.lua). On garde la transparence
    -- (invisibilité Fuma).
    ply:SetColor(Color(255, 255, 255, ply:GetColor().a))
    if NA_AppliquerYeux then NA_AppliquerYeux(ply) end   -- yeux choisis (sv_yeux.lua)
end

----------------------------------------------------------
-- Apparition
----------------------------------------------------------
hook.Add("PlayerSpawn", "NA_SetHeadAndHair", function(ply)
    -- un minuteur par joueur : des apparitions rapprochées ne s'empilent pas
    timer.Create("NA_Apparence_" .. ply:EntIndex(), DELAI, 1, function()
        if not IsValid(ply) or not ply:Alive() then return end

        -- la tenue équipée (sv_armure.lua) survit à la mort ; sinon la tenue par défaut
        ply:SetModel(ply.NA_Tenue or TENUE_DEFAUT)
        ply:SetRenderMode(RENDERMODE_NORMAL)
        ply:SetColor(COULEUR_CORPS)

        NA_AppliquerApparence(ply)
    end)
end)

-- À la mort : on retire les pièces (sinon la tête reste suspendue en l'air,
-- à l'endroit du joueur invisible). Le client les repose sur le corps.
hook.Add("PlayerDeath", "NA_Apparence_Mort", function(ply)
    RetirerPieces(ply)
end)

hook.Add("PlayerDisconnected", "NA_Apparence_Nettoyage", function(ply)
    timer.Remove("NA_Apparence_" .. ply:EntIndex())
    RetirerPieces(ply)
end)
