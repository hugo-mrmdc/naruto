--========================================================
-- Inventaire et équipement (CLIENT)
-- Ouvre avec F4, ou la commande console : mon_menu
--
--   Gauche : filtres, recherche et grille de quatre colonnes
--   Textures : ui/newUi/optimized (sources conservées dans newUi)
--   Droite : l'équipement autour de l'aperçu 3D du personnage
--
-- Équiper : clic droit ou double-clic sur un objet.
-- Retirer : clic droit ou double-clic sur un emplacement d'équipement.
-- Tourner le personnage : clic gauche maintenu sur l'aperçu.
--
-- Les objets s'ajoutent avec AjouterItem(...) (voir la commande test_items).
-- Les messages envoyés au serveur n'ont pas changé :
--   NA_EquipArmure / NA_UnequipArmure  (sv_armure.lua)
--   Accessory_Set / Accessory_Remove   (accessory_sv.lua)
--   NA_EquiperEpee / NA_RetirerEpee    (sv_selecteur_armes.lua)
--
-- Ajouter une épée à l'inventaire : ajouter_epee <nom>  (ex. ajouter_epee zabuza)
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local NB_CASES = 40
local TOUCHE = KEY_F4

-- Couleurs accordées au parchemin
local C_TEXTE      = Color(74, 52, 40)
local C_TEXTE_DOUX = Color(125, 100, 80)
local C_ROUGE      = Color(165, 45, 40)
local C_SURVOL     = Color(255, 255, 255, 45)
local C_INFOBULLE  = Color(245, 235, 210, 250)

local TYPES = {
    armure     = { nom = "Tenue",      couleur = Color(70, 110, 170) },
    arme       = { nom = "Arme",       couleur = Color(165, 55, 45) },
    accessoire = { nom = "Accessoire", couleur = Color(175, 125, 35) },
    objet      = { nom = "Objet",      couleur = Color(80, 125, 70) },
}

-- Emplacements d'équipement, de part et d'autre du personnage
local EMPLACEMENTS = {
    { id = "armure",     nom = "Tenue",      icone = "ui/inventory/icon_tenue.png",      cote = "gauche" },
    { id = "masque",     nom = "Masque",     icone = "ui/inventory/icon_masque.png",     cote = "gauche" },
    { id = "arme",       nom = "Arme",       icone = "ui/inventory/icon_katana.png",     cote = "droite" },
    { id = "accessoire", nom = "Accessoire", icone = "ui/inventory/icon_accessoire.png", cote = "droite" },
}

-- Polices recréées à l'ouverture, à la taille du menu (f = 1 pour un menu de 566 px de haut)
local derniereEchellePolice
local function CreerPolices(f)
    f = math.max(f or 1, 0.7)
    if derniereEchellePolice == f then return end
    derniereEchellePolice = f
    surface.CreateFont("NA.Inv.Titre",  { font = "Roboto", size = math.Round(30 * f), weight = 800 })
    surface.CreateFont("NA.Inv.Onglet", { font = "Roboto", size = math.Round(21 * f), weight = 800 })
    surface.CreateFont("NA.Inv.Texte",  { font = "Roboto", size = math.Round(18 * f), weight = 600 })
    surface.CreateFont("NA.Inv.Petit",  { font = "Roboto", size = math.Round(15 * f), weight = 600 })
    surface.CreateFont("NA.Inv.Qte",    { font = "Roboto", size = math.Round(15 * f), weight = 800 })
end
CreerPolices(1)

-- Matériaux chargés une seule fois (l'ancienne version les recréait à chaque image)
local mats = {}
local function M(chemin)
    local m = mats[chemin]
    if not m then
        m = Material(chemin, "smooth mips")
        mats[chemin] = m
    end
    return m
end

-- Décoder une texture à la fois avant le premier F4, sans tout charger
-- pendant la même image. Le cache est aussi utilisé par le dessin du menu.
local texturesAPreparer = {
    "ui/newUi/optimized/fond_v2.png", "ui/newUi/optimized/caseEmpty.png",
    "ui/newUi/optimized/equipecase.png", "ui/newUi/optimized/comun.png",
    "ui/newUi/optimized/rare.png", "ui/newUi/optimized/epique.png",
    "ui/newUi/optimized/legendaire.png", "ui/newUi/optimized/utiliser.png",
    "ui/main_menu/btn_base_close.png", "ui/inventory/icon_tenue.png",
    "ui/inventory/icon_masque.png", "ui/inventory/icon_katana.png",
    "ui/inventory/icon_accessoire.png",
}
local prochaineTexture = 1
timer.Create("NA_Inventaire_PreparerTextures", 0.25, 0, function()
    if not IsValid(LocalPlayer()) then return end
    M(texturesAPreparer[prochaineTexture])
    prochaineTexture = prochaineTexture + 1
    if prochaineTexture > #texturesAPreparer then
        timer.Remove("NA_Inventaire_PreparerTextures")
    end
end)

----------------------------------------------------------
-- Données
----------------------------------------------------------
local Inventaire = {}
local SlotsEquipement = {}

-- Rareté visuelle de l'objet, conservée lors des échanges d'équipement.
-- Images de rareté réduites à 256 x 256 px, partagées par la grille et l'équipement.
local RARETES = {
    commun = { rang = 1, nom = "Commun", couleur = Color(205, 205, 205), texture = "comun" },
    rare = { rang = 2, nom = "Rare", couleur = Color(90, 175, 255), texture = "rare" },
    epique = { rang = 3, nom = "Épique", couleur = Color(195, 115, 255), texture = "epique" },
    legendaire = { rang = 4, nom = "Légendaire", couleur = Color(255, 216, 75), texture = "legendaire" },
}
-- Bordures des nouveaux cadres, coordonnées normalisées sur 256 par axe.
-- Le PNG est vertical : conserver ses marges transparentes et son halo.
-- Comparer les cadres eux-mêmes : les ornements dépassent volontairement.
local CADRES_RARETE = {
    comun = { 7.5, 33, 242, 175 },
    rare = { 7.5, 33, 242, 175 },
    epique = { 7.5, 33, 242, 175 },
    legendaire = { 7.5, 33, 242, 175 },
}
local ALIAS_RARETES = { common = "commun", epic = "epique", legendary = "legendaire", ["épique"] = "epique", ["légendaire"] = "legendaire" }
local function NormaliserRarete(valeur)
    local cle = string.Trim(string.lower(tostring(valeur or "commun")))
    cle = ALIAS_RARETES[cle] or cle
    return RARETES[cle] and cle or "commun"
end
local function Rarete(it)
    return RARETES[NormaliserRarete(it.rarete or it.rarity)]
end

-- "defaut" = placement d'origine de l'objet (bouton Réinitialiser de l'éditeur)
-- "classe" = classe de l'arme (épées) donnée au joueur quand elle est équipée
local CHAMPS = { "item", "image", "type", "sousType", "modelPath", "boneName", "posOffset", "angOffset", "scale", "defaut", "classe", "rarete", "rarity" }

local function Vider(i)
    Inventaire[i] = { quantite = 0 }
end

local function Copie(src)
    local t = {}
    for _, k in ipairs(CHAMPS) do t[k] = src[k] end
    return t
end

for i = 1, NB_CASES do Vider(i) end

local frame -- fenêtre ouverte

local function RafraichirUI()
    if IsValid(frame) and frame.Reconstruire then frame.Reconstruire() end
end

function AjouterItem(slot, nomItem, quantite, imagePath, itemType, sousType, modelPath, boneName, posOffset, angOffset, scale, rarete)
    if slot < 1 or slot > NB_CASES then return end
    Inventaire[slot] = {
        item = nomItem, quantite = quantite or 1, image = imagePath,
        type = itemType, sousType = sousType, modelPath = modelPath, rarete = NormaliserRarete(rarete),
        boneName = boneName, posOffset = posOffset, angOffset = angOffset, scale = scale,
        defaut = {
            pos = posOffset and Vector(posOffset) or Vector(0, 0, 0),
            ang = angOffset and Angle(angOffset) or Angle(0, 0, 0),
            scale = scale or 1,
        },
    }
    RafraichirUI()
end

-- API pour attribuer une rareté à un objet déjà présent.
function DefinirRareteItem(slot, rarete)
    local it = Inventaire[slot]
    if not it or not it.item then return false end
    it.rarete = NormaliserRarete(rarete)
    RafraichirUI()
    return true
end

----------------------------------------------------------
-- Placement des accessoires : mémorisé par modèle
-- (garrysmod/data/naruto_accessoires.txt), réappliqué à chaque équipement.
----------------------------------------------------------
local FICHIER_PLACEMENTS = "naruto_accessoires.txt"
local Placements = util.JSONToTable(file.Read(FICHIER_PLACEMENTS, "DATA") or "") or {}

local function SauverPlacement(it)
    if not it.modelPath then return end
    local p, a = it.posOffset or Vector(0, 0, 0), it.angOffset or Angle(0, 0, 0)
    Placements[it.modelPath] = {
        x = p.x, y = p.y, z = p.z,
        p = a.p, ya = a.y, r = a.r,
        s = it.scale or 1,
    }
    file.Write(FICHIER_PLACEMENTS, util.TableToJSON(Placements, true))
end

local function OublierPlacement(it)
    if not it.modelPath or not Placements[it.modelPath] then return end
    Placements[it.modelPath] = nil
    file.Write(FICHIER_PLACEMENTS, util.TableToJSON(Placements, true))
end

-- Remplace le placement d'origine par celui réglé dans l'éditeur, s'il existe
local function AppliquerPlacement(it)
    local pl = it.modelPath and Placements[it.modelPath]
    if not pl then return end
    it.posOffset = Vector(pl.x or 0, pl.y or 0, pl.z or 0)
    it.angOffset = Angle(pl.p or 0, pl.ya or 0, pl.r or 0)
    it.scale = pl.s or 1
end

function RetirerItem(slot)
    if slot < 1 or slot > NB_CASES then return end
    Vider(slot)
    RafraichirUI()
end

----------------------------------------------------------
-- Équiper / retirer
----------------------------------------------------------
local function CaseLibre()
    for i = 1, NB_CASES do
        if not Inventaire[i].item then return i end
    end
end

-- Emplacement d'équipement visé par un objet (nil = ne s'équipe pas)
local function Cible(it)
    if it.type == "armure" then return "armure" end
    if it.type == "arme" then return "arme" end
    if it.type == "accessoire" then return it.sousType == "masque" and "masque" or "accessoire" end
end

----------------------------------------------------------
-- Placement des épées dans le dos : mémorisé par épée
-- (garrysmod/data/naruto_epees_dos.txt), renvoyé au serveur à chaque équipement.
----------------------------------------------------------
local FICHIER_DOS = "naruto_epees_dos.txt"
local PlacementsDos = util.JSONToTable(file.Read(FICHIER_DOS, "DATA") or "") or {}

local function EnvoyerDosEpee(classe)
    local p = PlacementsDos[classe]
    net.Start("NA_EpeeDos")
        net.WriteString(classe)
        net.WriteBool(p == nil)
        if p then
            net.WriteVector(Vector(p.x, p.y, p.z))
            net.WriteAngle(Angle(p.p, p.ya, p.r))
            net.WriteFloat(p.s)
        end
    net.SendToServer()
end

local function SauverDosEpee(classe, pos, ang, echelle)
    PlacementsDos[classe] = { x = pos.x, y = pos.y, z = pos.z, p = ang.p, ya = ang.y, r = ang.r, s = echelle }
    file.Write(FICHIER_DOS, util.TableToJSON(PlacementsDos, true))
end

local function OublierDosEpee(classe)
    PlacementsDos[classe] = nil
    file.Write(FICHIER_DOS, util.TableToJSON(PlacementsDos, true))
end

local function EnvoyerEquipement(slot, it)
    if slot == "armure" and it.modelPath then
        net.Start("NA_EquipArmure")
            net.WriteString(it.modelPath)
        net.SendToServer()
    elseif (slot == "masque" or slot == "accessoire") and it.modelPath then
        net.Start("Accessory_Set")
            net.WriteString(slot)
            net.WriteString(it.modelPath)
            net.WriteString(it.boneName or "ValveBiped.Bip01_Head1")
            net.WriteVector(it.posOffset or Vector(0, 0, 0))
            net.WriteAngle(it.angOffset or Angle(0, 0, 0))
            net.WriteFloat(it.scale or 1)
        net.SendToServer()
    elseif slot == "arme" and it.classe then
        net.Start("NA_EquiperEpee")
            net.WriteString(it.classe)
        net.SendToServer()
        -- son placement dans le dos, s'il a été réglé
        timer.Simple(0.3, function() EnvoyerDosEpee(it.classe) end)
    end
end

local function EnvoyerRetrait(slot)
    if slot == "armure" then
        net.Start("NA_UnequipArmure")
        net.SendToServer()
    elseif slot == "masque" or slot == "accessoire" then
        net.Start("Accessory_Remove")
            net.WriteString(slot)
        net.SendToServer()
    elseif slot == "arme" then
        net.Start("NA_RetirerEpee")
        net.SendToServer()
    end
end

local function Refus(message)
    notification.AddLegacy(message, NOTIFY_ERROR, 3)
    surface.PlaySound("buttons/button10.wav")
end

local function Desequiper(slot)
    local it = SlotsEquipement[slot]
    if not it then return end

    local libre = CaseLibre()
    if not libre then return Refus("Inventaire plein : impossible de retirer cet objet.") end

    Inventaire[libre] = Copie(it)
    Inventaire[libre].quantite = 1
    SlotsEquipement[slot] = nil

    EnvoyerRetrait(slot)
    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft2.wav")
    RafraichirUI()
end

local function Equiper(i)
    local it = Inventaire[i]
    if not it.item then return end

    local cible = Cible(it)
    if not cible then return Refus(it.item .. " ne s'équipe pas.") end

    -- l'objet déjà équipé retourne dans l'inventaire : il faut une place
    -- (la case libérée par le nouvel objet suffit s'il n'y en avait qu'un)
    local ancien = SlotsEquipement[cible]
    if ancien and it.quantite > 1 and not CaseLibre() then
        return Refus("Inventaire plein : impossible d'échanger ces objets.")
    end

    local nouveau = Copie(it)
    it.quantite = it.quantite - 1
    if it.quantite <= 0 then Vider(i) end

    if ancien then
        local libre = CaseLibre()
        Inventaire[libre] = Copie(ancien)
        Inventaire[libre].quantite = 1
    end

    -- accessoire / masque : on reprend le placement réglé dans l'éditeur
    if cible == "masque" or cible == "accessoire" then
        AppliquerPlacement(nouveau)
    end

    SlotsEquipement[cible] = nouveau
    EnvoyerEquipement(cible, nouveau)
    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")
    RafraichirUI()
end

----------------------------------------------------------
-- Épées : ajoutées à l'inventaire par leur nom
--   ajouter_epee            -> liste des épées disponibles
--   ajouter_epee zabuza     -> ajoute l'épée (nom de classe ou nom affiché, même partiel)
----------------------------------------------------------
local function EpeesDisponibles()
    local liste = {}
    for _, w in ipairs(weapons.GetList()) do
        local classe = w.ClassName
        local def = classe and weapons.Get(classe)
        if def and def.NA_Arme and def.Spawnable and classe ~= "naruto_poings" then
            liste[#liste + 1] = { classe = classe, nom = def.PrintName or classe, modele = def.WorldModel, rarete = def.Rarete or def.Rarity }
        end
    end
    table.sort(liste, function(a, b) return a.nom < b.nom end)
    return liste
end

local function TrouverEpee(recherche)
    recherche = string.lower(recherche)
    local trouvees = {}
    for _, e in ipairs(EpeesDisponibles()) do
        local classe, nom = string.lower(e.classe), string.lower(e.nom)
        if classe == recherche or nom == recherche then return { e } end   -- nom exact
        if string.find(classe, recherche, 1, true) or string.find(nom, recherche, 1, true) then
            trouvees[#trouvees + 1] = e
        end
    end
    return trouvees
end

-- L'épée est-elle déjà dans l'inventaire ou équipée ?
local function DejaPossedee(classe)
    if SlotsEquipement.arme and SlotsEquipement.arme.classe == classe then return true end
    for i = 1, NB_CASES do
        if Inventaire[i].classe == classe then return true end
    end
    return false
end

function AjouterEpee(recherche)
    local trouvees = TrouverEpee(recherche or "")
    if #trouvees == 0 then
        return Refus("Aucune épée ne correspond à « " .. tostring(recherche) .. " ».")
    elseif #trouvees > 1 then
        local noms = {}
        for _, e in ipairs(trouvees) do noms[#noms + 1] = e.classe end
        return Refus("Plusieurs épées correspondent : " .. table.concat(noms, ", "))
    end

    local e = trouvees[1]
    if DejaPossedee(e.classe) then return Refus(e.nom .. " est déjà dans ton inventaire.") end

    local libre = CaseLibre()
    if not libre then return Refus("Inventaire plein.") end

    AjouterItem(libre, e.nom, 1, nil, "arme", nil, e.modele, nil, nil, nil, nil, e.rarete)
    Inventaire[libre].classe = e.classe
    notification.AddLegacy(e.nom .. " ajoutée à l'inventaire (F4 pour l'équiper).", NOTIFY_GENERIC, 3)
    surface.PlaySound("physics/cardboard/cardboard_box_impact_soft1.wav")
end

concommand.Add("ajouter_epee", function(_, _, args)
    if not args[1] then
        print("[Naruto] Épées disponibles (ajouter_epee <nom>) :")
        for _, e in ipairs(EpeesDisponibles()) do print("   " .. e.classe .. "   (" .. e.nom .. ")") end
        return
    end
    AjouterEpee(table.concat(args, " "))
end, function(cmd, texte)
    local rep = {}
    local debut = string.lower(string.Trim(texte or ""))
    for _, e in ipairs(EpeesDisponibles()) do
        if debut == "" or string.StartWith(e.classe, debut) then rep[#rep + 1] = cmd .. " " .. e.classe end
    end
    return rep
end, "Ajoute une épée à l'inventaire F4 : ajouter_epee <nom>")

----------------------------------------------------------
-- Tête, cheveux... du joueur
-- Ce sont des modèles séparés, fusionnés à son squelette (sv_playerskin.lua).
-- On les recopie sur les rendus 3D du menu pour que les tenues aient une tête.
----------------------------------------------------------

-- Éléments fusionnés à ne PAS recopier sur les icônes de tenue
local EXCLURE_ICONE = {
    ["models/clan/ame/kami/wings.mdl"] = true,   -- ailes de papier (ancien modèle)
    ["models/clan/ame/kami/ailekami.mdl"] = true,   -- ailes de papier
    ["models/clan/ame/kami/fauxkami.mdl"] = true,   -- faux de papier (main droite, pendant le vol)
}

-- Liste des modèles fusionnés au joueur : { modele, skin, couleur }
local function ElementsDuJoueur(exclure)
    local ply = LocalPlayer()
    local liste = {}
    if not IsValid(ply) then return liste end

    for _, enfant in ipairs(ply:GetChildren()) do
        -- (la tête et les cheveux sont cachés chez nous quand cl_perso.lua les dessine reculés : on les garde)
        local tenue = enfant == ply:GetNW2Entity("NA_TeteEnt") or enfant == ply:GetNW2Entity("NA_CheveuxEnt")
        if IsValid(enfant) and enfant:IsEffectActive(EF_BONEMERGE) and (tenue or not enfant:GetNoDraw()) then
            local mdl = enfant:GetModel()
            if mdl and mdl ~= "" and not (exclure and exclure[string.lower(mdl)]) then
                -- tête et cheveux : reconnus pour recevoir leurs matériaux (visage, couleurs...)
                local role = (enfant == ply:GetNW2Entity("NA_TeteEnt") and "tete")
                    or (enfant == ply:GetNW2Entity("NA_CheveuxEnt") and "cheveux") or nil
                liste[#liste + 1] = { modele = mdl, skin = enfant:GetSkin(), couleur = enfant:GetColor(), role = role }
            end
        end
    end
    return liste
end

-- Recopie ces éléments sur l'entité d'un DModelPanel
local function Fusionner(ent, elements)
    local extras = {}
    local ply = LocalPlayer()
    local choix = IsValid(ply) and NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", "")) or NA_PERSO.DEFAUT
    NA_PeauCorps(ent, choix)   -- peau du corps teintée (la tenue ne l'est pas), cl_perso.lua
    for _, e in ipairs(elements) do
        local cs = ClientsideModel(e.modele, RENDERGROUP_OPAQUE)
        if IsValid(cs) then
            cs:SetNoDraw(true)
            if e.role and choix.visage > 0 and choix.recul > 0 then
                cs.Recul = choix.recul   -- tête et cheveux reculés, non fusionnés (NA_DessinerRecul, cl_perso.lua)
            else
                cs:SetParent(ent)
                cs:AddEffects(EF_BONEMERGE)
            end
            cs:SetSkin(e.skin or 0)
            cs.Couleur = e.couleur
            if e.role == "tete" then NA_MateriauxTete(cs, ply)              -- visage, yeux, sourcils, barbe (cl_playerskin.lua)
            elseif e.role == "cheveux" then NA_TeinterCheveux(cs, choix) end -- couleur, bandeau, logo, coupe (cl_perso.lua)
            extras[#extras + 1] = cs
        end
    end
    return extras
end

local function DessinerExtras(extras, ent)
    for _, cs in ipairs(extras or {}) do
        if IsValid(cs) then
            if cs.NA_Forme then NA_PoserFormes(cs, 0) end   -- bouche, yeux, nez du visage : reposés à chaque image
            if cs.Recul then
                NA_DessinerRecul(cs, ent, cs.Recul)
            else
                local c = cs.Couleur or color_white
                render.SetColorModulation(c.r / 255, c.g / 255, c.b / 255)
                cs:DrawModel()
            end
        end
    end
    render.SetColorModulation(1, 1, 1)
end

local function SupprimerExtras(extras)
    for _, cs in ipairs(extras or {}) do
        if IsValid(cs) then cs:Remove() end
    end
end

----------------------------------------------------------
-- Icône d'une tenue : rendu 3D de la tenue AVEC la tête et les cheveux du joueur
----------------------------------------------------------
local function CreerIconeTenue(parent, it, marge, taille)
    local ply = LocalPlayer()

    local mp = vgui.Create("DModelPanel", parent)
    mp:SetPos(marge, marge)
    mp:SetSize(taille - marge * 2, taille - marge * 2)
    mp:SetMouseInputEnabled(false)
    mp:SetModel(it.modelPath)
    mp:SetFOV(36)
    mp:SetColor(IsValid(ply) and ply:GetColor() or color_white)
    mp:SetDirectionalLight(BOX_TOP, Color(255, 245, 230))
    mp:SetAmbientLight(Color(90, 80, 70))

    local ent = mp:GetEntity()
    if not IsValid(ent) then return mp end

    local seq = ent:LookupSequence("idle_all_01")
    if seq and seq >= 0 then ent:ResetSequence(seq) end

    mp.Extras = Fusionner(ent, ElementsDuJoueur(EXCLURE_ICONE))

    -- Cadre propre à chaque tenue, calculé une seule fois à la création.
    -- Inclure la tête et les cheveux dans les limites du personnage composé.
    ent:SetAngles(angle_zero)
    ent:SetCycle(0)
    ent:SetupBones()
    local mini, maxi = ent:GetRenderBounds()
    mini, maxi = Vector(mini), Vector(maxi)
    for _, extra in ipairs(mp.Extras) do
        if IsValid(extra) then
            extra:SetupBones()
            local bas, haut = extra:GetRenderBounds()
            mini.x, mini.y, mini.z = math.min(mini.x, bas.x), math.min(mini.y, bas.y), math.min(mini.z, bas.z)
            maxi.x, maxi.y, maxi.z = math.max(maxi.x, haut.x), math.max(maxi.y, haut.y), math.max(maxi.z, haut.z)
        end
    end
    local centre = (mini + maxi) * 0.5
    local direction = Vector(1, 0.18, 0.04):GetNormalized()
    local vue = (-direction):Angle()
    local droite, haut = vue:Right(), vue:Up()
    local tangente = math.tan(math.rad(mp:GetFOV() * 0.5))
    local distance = 1
    -- Projeter les huit coins : pieds et cheveux gardent une marge de 10 %.
    for x = 0, 1 do
        for y = 0, 1 do
            for z = 0, 1 do
                local coin = Vector(x == 0 and mini.x or maxi.x, y == 0 and mini.y or maxi.y, z == 0 and mini.z or maxi.z) - centre
                local largeur = math.max(math.abs(coin:Dot(droite)), math.abs(coin:Dot(haut)))
                distance = math.max(distance, coin:Dot(direction) + largeur / (tangente * 1.15))
            end
        end
    end
    mp:SetLookAt(centre)
    mp:SetCamPos(centre + direction * distance)

    function mp:LayoutEntity(e)
        -- Miniature stable ; le grand aperçu conserve son animation.
        e:SetAngles(angle_zero)
        e:SetCycle(0)
    end
    function mp:PostDrawModel()
        DessinerExtras(self.Extras, self:GetEntity())
    end
    local supprimerModele = mp.OnRemove
    function mp:OnRemove()
        SupprimerExtras(self.Extras)
        if supprimerModele then supprimerModele(self) end
    end

    return mp
end

----------------------------------------------------------
-- Icône d'un objet : image si elle existe, sinon icône du modèle 3D
----------------------------------------------------------
local function CreerIcone(parent, it, taille)
    -- Réserver une marge autour du modèle dans le fond coloré.
    local marge = math.ceil(taille * 0.21)

    -- tenue : rendu 3D avec la tête et les cheveux du joueur
    if it.type == "armure" and it.modelPath and not it.image then
        return CreerIconeTenue(parent, it, marge, taille)
    end

    if it.image then
        local img = vgui.Create("DImage", parent)
        img:SetPos(marge, marge)
        img:SetSize(taille - marge * 2, taille - marge * 2)
        img:SetImage(it.image)
        img:SetMouseInputEnabled(false)
        return img
    elseif it.modelPath then
        -- icône générée une fois par le jeu puis gardée en cache
        -- (l'ancienne version créait un aperçu 3D complet par case)
        local img = vgui.Create("ModelImage", parent)
        img:SetPos(marge, marge)
        img:SetSize(taille - marge * 2, taille - marge * 2)
        img:SetModel(it.modelPath)
        img:SetMouseInputEnabled(false)
        return img
    end
end

----------------------------------------------------------
-- Aperçu 3D du personnage
----------------------------------------------------------
local function DessinerAccessoire(ent, csm, it)
    local boneID = ent:LookupBone(it.boneName or "ValveBiped.Bip01_Head1")
        or ent:LookupBone("ValveBiped.Bip01_Head1")
    if not boneID then return end

    local m = ent:GetBoneMatrix(boneID)
    if not m then return end

    -- même calcul que la classe Accessory (accessory_class.lua)
    local pos, ang = m:GetTranslation(), m:GetAngles()
    local ao = it.angOffset or Angle(0, 0, 0)
    local po = it.posOffset or Vector(0, 0, 0)
    ang:RotateAroundAxis(ang:Right(), ao.p)
    ang:RotateAroundAxis(ang:Up(), ao.y)
    ang:RotateAroundAxis(ang:Forward(), ao.r)
    pos = pos + ang:Forward() * po.x + ang:Right() * po.y + ang:Up() * po.z

    csm:SetPos(pos)
    csm:SetAngles(ang)
    csm:SetModelScale(it.scale or 1, 0)
    csm:DrawModel()
end

-- Épée rangée dans le dos : même placement que dans le jeu (naruto_arme_base.lua, DessinerDos) :
-- celui réglé par le joueur (PlacementsDos), sinon celui de l'arme (SWEP.Dos)
local function DessinerEpeeDos(ent, csm, classe, cfg)
    local liste = istable(cfg.os) and cfg.os or { cfg.os or "ValveBiped.Bip01_Spine4" }
    local os
    for _, nom in ipairs(liste) do
        os = ent:LookupBone(nom)
        if os then break end
    end
    local mat = os and ent:GetBoneMatrix(os)
    if not mat then return end

    local perso = PlacementsDos[classe]
    local d = perso and Vector(perso.x, perso.y, perso.z) or cfg.pos or vector_origin
    local r = perso and Angle(perso.p, perso.ya, perso.r) or cfg.ang or angle_zero

    local pos, ang = mat:GetTranslation(), mat:GetAngles()
    if cfg.mode == "local" then
        pos, ang = LocalToWorld(d, r, pos, ang)
    else
        ang = Angle(ang)
        ang:RotateAroundAxis(ang:Right(), r.p)
        ang:RotateAroundAxis(ang:Up(), r.y)
        ang:RotateAroundAxis(ang:Forward(), r.r)
        pos = pos + ang:Forward() * d.x + ang:Right() * d.y + ang:Up() * d.z
    end

    csm:SetPos(pos)
    csm:SetAngles(ang)
    csm:SetModelScale((perso and perso.s) or cfg.echelle or 1, 0)
    csm:DrawModel()
end

local function CreerApercu(parent)
    local ply = LocalPlayer()
    local modele = (SlotsEquipement.armure and SlotsEquipement.armure.modelPath) or ply:GetModel()

    local ap = vgui.Create("DModelPanel", parent)
    ap:SetModel(modele)
    ap:SetFOV(38)
    ap:SetCamPos(Vector(118, 0, 41))   -- corps entier, cheveux compris (hauteur visible ~0 à 81)
    ap:SetLookAt(Vector(0, 0, 40.5))
    ap:SetColor(ply:GetColor())
    ap:SetDirectionalLight(BOX_TOP, Color(255, 245, 230))
    ap:SetAmbientLight(Color(150, 140, 130))

    -- Cadrer le corps sur toute la hauteur du panneau (le FOV est horizontal)
    function ap:PerformLayout(w, h)
        local dist = 76 / (2 * math.tan(math.rad(self:GetFOV() * 0.5)) * math.max(h / math.max(w, 1), 0.5))
        self:SetCamPos(Vector(dist, 0, 41))
    end

    local ent = ap:GetEntity()
    if not IsValid(ent) then return ap end

    ent:SetSkin(ply:GetSkin())
    for b = 0, ply:GetNumBodyGroups() - 1 do
        ent:SetBodygroup(b, ply:GetBodygroup(b))
    end
    local seq = ent:LookupSequence("idle_all_01")
    if seq and seq >= 0 then ent:ResetSequence(seq) end

    -- tête, cheveux, ailes... : tout ce qui est fusionné au squelette du joueur
    ap.Extras = Fusionner(ent, ElementsDuJoueur())

    -- épée équipée : montrée dans le dos, comme en jeu
    local arme = SlotsEquipement.arme
    local defArme = arme and arme.classe and weapons.Get(arme.classe)
    if defArme and defArme.Dos and defArme.Dos.modele then
        local cs = ClientsideModel(defArme.Dos.modele, RENDERGROUP_OPAQUE)
        if IsValid(cs) then
            cs:SetNoDraw(true)
            ap.Epee = { cs = cs, classe = arme.classe, cfg = defArme.Dos }
        end
    end

    -- masque et accessoire équipés
    ap.Accessoires = {}
    for _, slot in ipairs({ "masque", "accessoire" }) do
        local it = SlotsEquipement[slot]
        if it and it.modelPath then
            local cs = ClientsideModel(it.modelPath, RENDERGROUP_OPAQUE)
            if IsValid(cs) then
                cs:SetNoDraw(true)
                ap.Accessoires[#ap.Accessoires + 1] = { cs = cs, it = it }
            end
        end
    end

    -- rotation à la souris
    ap.Lacet = 25
    function ap:LayoutEntity(e)
        if self.Glisse then
            if not input.IsMouseDown(MOUSE_LEFT) then
                self.Glisse = false
            else
                local x = gui.MouseX()
                self.Lacet = self.Lacet + (x - (self.DernierX or x)) * 0.6
                self.DernierX = x
            end
        end
        e:SetAngles(Angle(0, self.Lacet, 0))
        self:RunAnimation()
    end

    function ap:OnMousePressed(code)
        if code == MOUSE_LEFT then
            self.Glisse = true
            self.DernierX = gui.MouseX()
        end
    end

    function ap:PostDrawModel(e)
        DessinerExtras(self.Extras, e)

        e:SetupBones()
        for _, a in ipairs(self.Accessoires) do
            if IsValid(a.cs) then DessinerAccessoire(e, a.cs, a.it) end
        end
        local epee = self.Epee
        if epee and IsValid(epee.cs) then DessinerEpeeDos(e, epee.cs, epee.classe, epee.cfg) end
    end

    local supprimerModele = ap.OnRemove
    function ap:OnRemove()
        SupprimerExtras(self.Extras)
        for _, a in ipairs(self.Accessoires or {}) do if IsValid(a.cs) then a.cs:Remove() end end
        if self.Epee and IsValid(self.Epee.cs) then self.Epee.cs:Remove() end
        if supprimerModele then supprimerModele(self) end
    end

    return ap
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local function FermerMenu()
    if IsValid(frame) then frame:Remove() end
    frame = nil
end

-- un seul menu ouvert à la fois (F2, F4, F6) : voir _na_registre.lua
if NA_EnregistrerMenu then NA_EnregistrerMenu("inventaire", FermerMenu) end

----------------------------------------------------------
-- Éditeur de placement d'un accessoire / masque équipé, ou de l'épée
-- équipée quand elle est rangée dans le dos
--   curseurs X / Y / Z, rotation, taille ; aperçu en direct sur le personnage,
--   caméra centrée sur l'accessoire. "Valider" l'envoie au serveur (les autres
--   le voient) et le mémorise pour ce modèle.
----------------------------------------------------------
local editeur
NA_EditeurCameraActive = false   -- lu par thirdpersonne.lua
local vueEditeur = { os = "ValveBiped.Bip01_Head1", angle = 0, distance = 40 }

hook.Add("CalcView", "NA_EditeurAccessoire_Vue", function(ply, pos, ang, fov)
    if not NA_EditeurCameraActive then return end

    local bone = ply:LookupBone(vueEditeur.os) or ply:LookupBone("ValveBiped.Bip01_Head1")
    local centre = bone and ply:GetBonePosition(bone) or ply:EyePos()

    -- caméra face au joueur, tournable avec le curseur "Vue"
    local lacet = ply:GetAngles().y + vueEditeur.angle
    local origine = centre + Angle(0, lacet, 0):Forward() * vueEditeur.distance + Vector(0, 0, 3)

    return {
        origin = origine,
        angles = (centre - origine):Angle(),
        fov = 50,
        drawviewer = true,
    }
end)

local function FermerEditeur()
    if IsValid(editeur) then editeur:Remove() end
end

local function OuvrirEditeur(slot)
    local it = SlotsEquipement[slot]
    if not it or not it.modelPath then return end

    -- épée : on règle sa position dans le dos (réglages par défaut = ceux de l'arme)
    local estEpee = slot == "arme"
    local dosArme
    if estEpee then
        local def = it.classe and weapons.Get(it.classe)
        dosArme = def and def.Dos
        if not dosArme then return Refus("Cette arme ne se range pas dans le dos.") end
    end

    FermerMenu()
    FermerEditeur()

    local ply = LocalPlayer()
    local depart, defaut
    if estEpee then
        defaut = {
            pos = Vector(dosArme.pos or Vector(0, 0, 0)),
            ang = Angle(dosArme.ang or Angle(0, 0, 0)),
            scale = dosArme.echelle or 1,
        }
        local p = PlacementsDos[it.classe]
        depart = p and { pos = Vector(p.x, p.y, p.z), ang = Angle(p.p, p.ya, p.r), scale = p.s } or defaut

        local os = dosArme.os or "ValveBiped.Bip01_Spine4"
        vueEditeur.os = istable(os) and os[#os] or os
        vueEditeur.angle = 180          -- vue de dos
        vueEditeur.distance = 70
    else
        depart = {
            pos = Vector(it.posOffset or Vector(0, 0, 0)),
            ang = Angle(it.angOffset or Angle(0, 0, 0)),
            scale = it.scale or 1,
        }
        defaut = it.defaut or depart

        vueEditeur.os = it.boneName or "ValveBiped.Bip01_Head1"
        vueEditeur.angle = 0
        vueEditeur.distance = 40
    end
    NA_EditeurCameraActive = true

    local W, H = 360, 560
    editeur = vgui.Create("DFrame")
    editeur:SetSize(W, H)
    editeur:SetPos(ScrW() - W - 30, ScrH() / 2 - H / 2)
    editeur:SetTitle("")
    editeur:ShowCloseButton(false)
    editeur:SetDraggable(true)
    editeur:MakePopup()

    editeur.Paint = function(pan, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(90, 60, 45, 255))
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, Color(236, 222, 190, 250))
        draw.SimpleText("Placer : " .. (it.item or slot), "NA.Inv.Texte", 16, 20, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(C_ROUGE)
        surface.DrawRect(16, 36, w - 32, 2)
    end

    editeur.OnRemove = function()
        NA_EditeurCameraActive = false
        editeur = nil
        -- on laisse au serveur le temps de renvoyer le placement validé avant de couper l'aperçu
        timer.Simple(0.5, function() if not IsValid(editeur) then NA_DosEdition = nil end end)
    end

    local corps = vgui.Create("DPanel", editeur)
    corps:Dock(FILL)
    corps:DockMargin(8, 34, 8, 8)
    corps.Paint = function() end

    local curseurs = {}

    -- Applique les curseurs à l'objet ET à l'accessoire affiché (aperçu instantané)
    local function Appliquer()
        if not (curseurs.x and curseurs.y and curseurs.z and curseurs.p and curseurs.ya and curseurs.r and curseurs.s) then return end
        local pos = Vector(curseurs.x:GetValue(), curseurs.y:GetValue(), curseurs.z:GetValue())
        local ang = Angle(curseurs.p:GetValue(), curseurs.ya:GetValue(), curseurs.r:GetValue())
        local echelle = curseurs.s:GetValue()

        if estEpee then
            -- aperçu en direct sur le personnage (naruto_arme_base.lua)
            NA_DosEdition = { classe = it.classe, pos = pos, ang = ang, echelle = echelle }
            return
        end

        it.posOffset = pos
        it.angOffset = ang
        it.scale = echelle

        local inst = NA_AccessoireInstance and NA_AccessoireInstance(ply, slot)
        if inst then
            inst.PosOffset = it.posOffset
            inst.AngOffset = it.angOffset
            inst.Scale = it.scale
        end
    end

    local function Titre(texte)
        local l = vgui.Create("DLabel", corps)
        l:Dock(TOP)
        l:DockMargin(4, 8, 0, 0)
        l:SetFont("NA.Inv.Petit")
        l:SetTextColor(C_ROUGE)
        l:SetText(texte)
        l:SizeToContents()
    end

    local function Curseur(cle, texte, mini, maxi, decimales, valeur, surChange)
        local c = vgui.Create("NA_NumSlider", corps)
        c:Dock(TOP)
        c:DockMargin(4, 0, 4, 0)
        c:SetTall(26)
        c:SetText(texte)
        c:SetMinMax(mini, maxi)
        c:SetDecimals(decimales)
        c:SetValue(valeur)
        c.Label:SetTextColor(C_TEXTE)
        c.Label:SetFont("NA.Inv.Petit")
        c.OnValueChanged = surChange or Appliquer
        if cle then curseurs[cle] = c end
        return c
    end

    local portee = estEpee and 50 or 30
    Titre("POSITION (unités)")
    Curseur("x", "X  avant / arrière", -portee, portee, 1, depart.pos.x)
    Curseur("y", "Y  droite / gauche", -portee, portee, 1, depart.pos.y)
    Curseur("z", "Z  haut / bas", -portee, portee, 1, depart.pos.z)

    Titre("ROTATION (degrés)")
    Curseur("p", "Tangage", -180, 180, 0, depart.ang.p)
    Curseur("ya", "Lacet", -180, 180, 0, depart.ang.y)
    Curseur("r", "Roulis", -180, 180, 0, depart.ang.r)

    Titre("TAILLE")
    Curseur("s", "Échelle", 0.1, 3, 2, depart.scale)

    Titre("CAMÉRA")
    Curseur(nil, "Vue (tourner)", -180, 180, 0, math.NormalizeAngle(vueEditeur.angle), function(_, v) vueEditeur.angle = v end)
    Curseur(nil, "Zoom", 15, 120, 0, vueEditeur.distance, function(_, v) vueEditeur.distance = v end)
    Appliquer()

    local function Bouton(texte, couleur, action)
        local b = vgui.Create("DButton", editeur)
        b:SetText("")
        b.Paint = function(pan, w, h)
            draw.RoundedBox(6, 0, 0, w, h, pan:IsHovered() and couleur or Color(couleur.r, couleur.g, couleur.b, 200))
            draw.SimpleText(texte, "NA.Inv.Petit", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = action
        return b
    end

    local function Remettre(p, a, s)
        curseurs.x:SetValue(p.x) curseurs.y:SetValue(p.y) curseurs.z:SetValue(p.z)
        curseurs.p:SetValue(a.p) curseurs.ya:SetValue(a.y) curseurs.r:SetValue(a.r)
        curseurs.s:SetValue(s)
        Appliquer()
    end

    local function RetourInventaire()
        FermerEditeur()
        timer.Simple(0, function() RunConsoleCommand("mon_menu") end)
    end

    local bas = vgui.Create("DPanel", editeur)
    bas:Dock(BOTTOM)
    bas:DockMargin(12, 0, 12, 12)
    bas:SetTall(34)
    bas.Paint = function() end
    bas:MoveToFront()

    local bw = (W - 24 - 16) / 3
    local b1 = Bouton("Réinitialiser", Color(120, 100, 80), function()
        Remettre(defaut.pos, defaut.ang, defaut.scale)
        if estEpee then OublierDosEpee(it.classe) else OublierPlacement(it) end
    end)
    b1:SetParent(bas) b1:SetPos(0, 0) b1:SetSize(bw, 34)

    local b2 = Bouton("Annuler", Color(150, 60, 50), function()
        Remettre(depart.pos, depart.ang, depart.scale)
        RetourInventaire()
    end)
    b2:SetParent(bas) b2:SetPos(bw + 8, 0) b2:SetSize(bw, 34)

    local b3 = Bouton("Valider", Color(70, 130, 70), function()
        Appliquer()
        if estEpee then
            SauverDosEpee(it.classe, NA_DosEdition.pos, NA_DosEdition.ang, NA_DosEdition.echelle)
            EnvoyerDosEpee(it.classe)     -- les autres joueurs voient le nouveau placement
        else
            SauverPlacement(it)
            EnvoyerEquipement(slot, it)   -- les autres joueurs voient le nouveau placement
        end
        surface.PlaySound("buttons/button14.wav")
        RetourInventaire()
    end)
    b3:SetParent(bas) b3:SetPos((bw + 8) * 2, 0) b3:SetSize(bw, 34)
end

concommand.Add("ajuster_accessoire", function(_, _, args)
    local slot = args[1] == "masque" and "masque" or "accessoire"
    if not SlotsEquipement[slot] then
        Refus("Aucun " .. slot .. " équipé.")
        return
    end
    OuvrirEditeur(slot)
end)

local function OuvrirMenu()
    if NA_FermerAutresMenus then NA_FermerAutresMenus("inventaire") end
    local W, H = ScrW(), ScrH()
    local S = math.min(W / 1920, H / 1080)
    CreerPolices(math.Clamp(S, 0.7, 1.5))
    local blanc, doux = Color(239, 236, 230), Color(155, 155, 163)
    local ornement = Color(235, 180, 88)
    local chemin = "ui/newUi/optimized/"
    local function Texture(nom, x, y, w, h, alpha)
        surface.SetMaterial(M(chemin .. nom .. ".png"))
        surface.SetDrawColor(255, 255, 255, alpha or 255)
        surface.DrawTexturedRect(x, y, w, h)
    end
    local reflet = Color(255, 255, 255, 20)
    local chargements, prochainChargement = {}, 1
    local premiereImage
    local function ChargerEnsuite(parent, action)
        chargements[#chargements + 1] = { parent = parent, action = action }
    end
    local function IconeProgressive(parent, it, taille, zone)
        parent.Think = function(p)
            if zone then
                local _, y = p:LocalToScreen(0, 0)
                local _, haut = zone:LocalToScreen(0, 0)
                if y + p:GetTall() <= haut or y >= haut + zone:GetTall() then return end
            end
            p.Think = nil
            ChargerEnsuite(p, function() CreerIcone(p, it, taille) end)
        end
    end
    local function DessinerCase(w, h, it, survol, choisi, equipement)
        local rarete = it and it.item and Rarete(it)
        if rarete and not M(chemin .. rarete.texture .. ".png"):IsError() then
            local cadre = CADRES_RARETE[rarete.texture]
            -- Bordure de caseEmpty : x=34, y=36, 188 x 176.
            local tw, th = w * 188 / cadre[3], h * 176 / cadre[4]
            local tx = w * 34 / 256 - tw * cadre[1] / 256
            local ty = h * 36 / 256 - th * cadre[2] / 256
            Texture(rarete.texture, tx, ty, tw, th)
        else
            Texture(equipement and "equipecase" or "caseEmpty", 0, 0, w, h)
        end
        -- Garder les ornements visibles lors du survol et de la sélection.
        local x, y = w * 0.20, h * 0.20
        local cw, ch = w * 0.60, h * 0.60
        if survol or choisi then draw.RoundedBox(4, x, y, cw, ch, reflet) end
    end
    frame = vgui.Create("DPanel")
    frame:SetSize(W, H)
    frame:SetPos(0, 0)
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(_, w, h)
        premiereImage = premiereImage or FrameNumber()
        -- Cover preserves the background proportions on ultrawide displays.
        local scale = math.max(w / 1672, h / 941)
        Texture("fond_v2", (w - 1672 * scale) / 2, (h - 941 * scale) / 2, 1672 * scale, 941 * scale)
        draw.SimpleText("INVENTAIRE", "NA.Inv.Titre", W * 0.075, H * 0.065, blanc)
        draw.SimpleText("F4 / ÉCHAP  ·  Fermer", "NA.Inv.Petit", W * 0.925, H * 0.075, doux, TEXT_ALIGN_RIGHT)
    end
    frame.Think = function()
        if input.IsKeyDown(KEY_ESCAPE) then FermerMenu() gui.HideGameUI() return end
        -- Afficher le cadre avant les modèles ; au plus une création par image.
        if not premiereImage or FrameNumber() <= premiereImage then return end
        while prochainChargement <= #chargements do
            local travail = chargements[prochainChargement]
            prochainChargement = prochainChargement + 1
            if IsValid(travail.parent) then travail.action() break end
        end
        if prochainChargement > #chargements then
            chargements, prochainChargement = {}, 1
        end
    end
    local function Bouton(parent, texte, x, y, w, h, action)
        local b = vgui.Create("DButton", parent)
        b:SetText("") b:SetPos(x, y) b:SetSize(w, h)
        b.Paint = function(p, bw, bh)
            draw.SimpleText(texte, "NA.Inv.Onglet", bw / 2, bh / 2, p:IsHovered() and ornement or blanc, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = action
        return b
    end
    local fermer = vgui.Create("DButton", frame)
    fermer:SetText("")
    fermer:SetSize(78 * S, 78 * S)
    fermer:SetPos(W - 94 * S, 16 * S)
    fermer:SetTooltip("Fermer")
    fermer.Paint = function(pan, w, h)
        local m = pan:IsHovered() and 0 or 4 * S
        surface.SetMaterial(M("ui/main_menu/btn_base_close.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(m, m, w - m * 2, h - m * 2)
    end
    fermer.DoClick = function()
        surface.PlaySound("ui/buttonclick.wav")
        FermerMenu()
    end
    local gauche = vgui.Create("DPanel", frame)
    gauche:SetPos(W * 0.075, H * 0.14)
    gauche:SetSize(W * 0.405, H * 0.78)
    gauche.Paint = function() end
    local gw, gh = gauche:GetWide(), gauche:GetTall()
    local recherche, categorie, famille, tri = "", "tous", "objets", false
    local selection, selectionSlot, selectionEquip
    local ConstruireGrille, ConstruireEquipement, ActualiserDetails
    local function Filtrer()
        selection, selectionSlot, selectionEquip = nil, nil, nil
        ConstruireGrille()
        ActualiserDetails()
    end
    local tabs = { { "TOUT", "tous" }, { "MATÉRIAUX", "materiaux" }, { "ÉQUIPEMENTS", "equipements" } }
    for n, t in ipairs(tabs) do
        local b = Bouton(gauche, t[1], (n - 1) * gw / 3, 0, gw / 3, 42 * S, function() categorie = t[2] Filtrer() end)
        b.Paint = function(p, w, h)
            draw.SimpleText(t[1], "NA.Inv.Onglet", w / 2, h / 2, categorie == t[2] and blanc or doux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if categorie == t[2] then
                surface.SetDrawColor(ornement) surface.DrawRect(w * 0.15, h - 2, w * 0.7, 2)
            end
        end
    end
    local champ = vgui.Create("DTextEntry", gauche)
    champ:SetPos(0, 56 * S) champ:SetSize(gw * 0.55, 32 * S)
    champ:SetFont("NA.Inv.Petit") champ:SetUpdateOnType(true) champ:SetTextInset(10, 0)
    champ.Paint = function(p, w, h)
        draw.RoundedBox(3, 0, 0, w, h, Color(24, 30, 39, 210))
        p:DrawTextEntryText(blanc, ornement, blanc)
        if p:GetValue() == "" and not p:HasFocus() then draw.SimpleText("Rechercher un objet…", "NA.Inv.Petit", 10, h / 2, doux, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
    end
    champ.OnGetFocus = function(p) frame:SetKeyboardInputEnabled(true) hook.Run("OnTextEntryGetFocus", p) end
    champ.OnLoseFocus = function(p)
        if IsValid(frame) then frame:SetKeyboardInputEnabled(false) end
        hook.Run("OnTextEntryLoseFocus", p) p:UpdateConvarValue()
    end
    champ.OnEnter = function(p) p:KillFocus() end
    champ.OnValueChange = function(_, v) recherche = string.lower(v or "") Filtrer() end
    local trier = Bouton(gauche, "", gw * 0.58, 56 * S, gw * 0.42, 32 * S, function() tri = not tri ConstruireGrille() end)
    trier.Paint = function(_, w, h)
        draw.SimpleText((tri and "☑" or "□") .. " Trier par rareté", "NA.Inv.Petit", w, h / 2, tri and ornement or doux, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local capacite = vgui.Create("DPanel", gauche)
    capacite:SetPos(0, 100 * S) capacite:SetSize(gw, 30 * S)
    capacite.Paint = function(_, w, h)
        local nb = 0
        for _, it in ipairs(Inventaire) do if it.item then nb = nb + 1 end end
        draw.RoundedBox(2, 0, 0, w, h, Color(29, 33, 41, 240))
        surface.SetDrawColor(47, 64, 84, 210) surface.DrawRect(0, 0, w * nb / NB_CASES, h)
        draw.SimpleText("Emplacements occupés", "NA.Inv.Petit", 10, h / 2, blanc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(nb .. " / " .. NB_CASES, "NA.Inv.Petit", w - 10, h / 2, blanc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local defil = vgui.Create("DScrollPanel", gauche)
    defil:SetPos(0, 152 * S) defil:SetSize(gw, gh - 208 * S)
    local vbar = defil:GetVBar()
    vbar:SetWide(5 * S) vbar:SetHideButtons(true)
    vbar.Paint = function() end
    vbar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(2, 0, 0, w, h, Color(120, 102, 76, 180)) end
    local ecart = 4 * S
    local colonnes = 4
    local taille = math.floor((gw - 10 * S - ecart * (colonnes - 1)) / colonnes)
    local grille = defil:Add("DPanel")
    grille:Dock(TOP)
    grille.Paint = function() end
    local casesGrille = {}
    ConstruireGrille = function()
        local visibles = {}
        local positionDefilement = vbar:GetScroll()
        local liste = {}
        for i, it in ipairs(Inventaire) do
            local cosmetique = it.type == "accessoire"
            local ok = not it.item or ((famille == "cosmetiques") == cosmetique)
            if categorie == "materiaux" then ok = ok and not Cible(it) end
            if categorie == "equipements" then ok = ok and Cible(it) ~= nil end
            if recherche ~= "" then ok = ok and it.item and string.find(string.lower(it.item), recherche, 1, true) end
            if ok then liste[#liste + 1] = i end
        end
        if tri then table.sort(liste, function(a, b)
            local ia, ib = Inventaire[a], Inventaire[b]
            local ra, rb = ia.item and Rarete(ia).rang or 0, ib.item and Rarete(ib).rang or 0
            if ra == rb then return a < b end
            return ra > rb
        end) end
        for ordre, i in ipairs(liste) do
            local it = Inventaire[i]
            visibles[i] = true
            local existante = casesGrille[i]
            if IsValid(existante) and existante.Item == it then
                existante:SetZPos(ordre)
                if it.item then existante:SetTooltip(it.item .. " · " .. Rarete(it).nom) end
            else
            if IsValid(existante) then existante:Remove() end
            local b = grille:Add("DButton") b:SetText("") b:SetSize(taille, taille)
            casesGrille[i] = b
            b.Item = it
            b:SetZPos(ordre)
            b.Paint = function(p, w, h)
                DessinerCase(w, h, it, p:IsHovered(), selectionSlot == i)
            end
            b.PaintOver = function(_, w, h)
                if it.item and (it.quantite or 0) > 1 then draw.SimpleText("x" .. it.quantite, "NA.Inv.Qte", w * 0.83, h * 0.13, blanc, TEXT_ALIGN_RIGHT) end
            end
            if it.item then IconeProgressive(b, it, taille, defil) b:SetTooltip(it.item .. " · " .. Rarete(it).nom) end
            b.DoClick = function() selection, selectionSlot, selectionEquip = it.item and it or nil, i, nil ActualiserDetails() end
            b.DoRightClick = function() if it.item then Equiper(i) end end
            b.DoDoubleClick = b.DoRightClick
            end
            casesGrille[i]:SetPos(((ordre - 1) % colonnes) * (taille + ecart), math.floor((ordre - 1) / colonnes) * (taille + ecart))
        end
        for i, b in pairs(casesGrille) do
            if not visibles[i] then
                if IsValid(b) then b:Remove() end
                casesGrille[i] = nil
            end
        end
        grille:SetTall(math.max(0, math.ceil(#liste / colonnes) * (taille + ecart) - ecart))
        defil:InvalidateLayout(true)
        vbar:SetScroll(positionDefilement)
    end
    for n, t in ipairs({ { "OBJETS", "objets" }, { "COSMÉTIQUES", "cosmetiques" } }) do
        local b = Bouton(gauche, t[1], (n - 1) * gw / 2, gh - 44 * S, gw / 2, 42 * S, function() famille = t[2] Filtrer() end)
        b.Paint = function(_, w, h) draw.SimpleText(t[1], "NA.Inv.Onglet", w / 2, h / 2, famille == t[2] and blanc or doux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
    end
    local droite = vgui.Create("DPanel", frame)
    droite:SetPos(W * 0.54, H * 0.13) droite:SetSize(W * 0.40, H * 0.77)
    droite.Paint = function() end
    local dw, dh = droite:GetWide(), droite:GetTall()
    local equipSize = math.min(dw * 0.28, dh * 0.28)
    local support, apercuEquipement
    local casesEquipement = {}
    ConstruireEquipement = function()
        if not IsValid(support) then
        support = vgui.Create("DPanel", droite)
        support:SetPos(dw * 0.19, 0) support:SetSize(dw * 0.62, dh)
        support.Paint = function(_, w, h)
            draw.SimpleText("Chargement du personnage…", "NA.Inv.Petit", w / 2, h / 2, doux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        ChargerEnsuite(support, function()
            local ap = CreerApercu(support)
            ap:Dock(FILL)
            apercuEquipement = ap
            support.Paint = function() end
        end)
        elseif IsValid(apercuEquipement) then
            -- Remplacer l'aperçu dans la même image, sans écran de chargement.
            local ancien = apercuEquipement
            apercuEquipement = CreerApercu(support)
            apercuEquipement.Lacet = ancien.Lacet
            apercuEquipement:Dock(FILL)
            ancien:Remove()
        end
        local rang = { gauche = 0, droite = 0 }
        for _, e in ipairs(EMPLACEMENTS) do
            local n = rang[e.cote] rang[e.cote] = n + 1
            local x = e.cote == "gauche" and 0 or dw - equipSize
            local y = dh * 0.13 + n * dh * 0.43
            local it = SlotsEquipement[e.id]
            local existante = casesEquipement[e.id]
            if not IsValid(existante) or existante.Item ~= it then
            if IsValid(existante) then existante:Remove() end
            local groupe = vgui.Create("DPanel", droite)
            groupe:SetPos(x, y - 25 * S)
            groupe:SetSize(equipSize, equipSize + 53 * S)
            groupe.Paint = function() end
            groupe.Item = it
            casesEquipement[e.id] = groupe
            local nom = vgui.Create("DLabel", groupe)
            nom:SetFont("NA.Inv.Petit") nom:SetTextColor(doux) nom:SetText(e.nom) nom:SizeToContents()
            nom:SetPos((equipSize - nom:GetWide()) / 2, 0)
            local b = Bouton(groupe, "", 0, 25 * S, equipSize, equipSize, function()
                selection, selectionSlot, selectionEquip = it, nil, e.id ActualiserDetails()
            end)
            b.Paint = function(p, w, h)
                DessinerCase(w, h, it, p:IsHovered(), selectionEquip == e.id, true)
                if not it then
                    surface.SetMaterial(M(e.icone)) surface.SetDrawColor(180, 185, 194, 65)
                    surface.DrawTexturedRect(w * 0.27, h * 0.27, w * 0.46, h * 0.46)
                end
            end
            if it then IconeProgressive(b, it, equipSize) b:SetTooltip(it.item .. " · " .. Rarete(it).nom) end
            b.DoRightClick = function() Desequiper(e.id) end b.DoDoubleClick = b.DoRightClick
            if it and (e.id == "masque" or e.id == "accessoire" or (e.id == "arme" and it.classe)) then
                local ajuster = Bouton(groupe, "Ajuster", 0, 25 * S + equipSize, equipSize, 28 * S, function() OuvrirEditeur(e.id) end)
                ajuster:SetFont("NA.Inv.Petit")
                b.DoMiddleClick = ajuster.DoClick
            end
            end
        end
    end
    local details = vgui.Create("DPanel", frame)
    details:SetPos(W * 0.635, H * 0.76) details:SetSize(W * 0.21, H * 0.18)
    details:SetVisible(false)
    details.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(10, 14, 20, 238))
    end
    ActualiserDetails = function()
        details:Clear() details:SetVisible(selection ~= nil)
        if not selection then return end
        local titre = vgui.Create("DLabel", details)
        titre:SetPos(12 * S, 8 * S) titre:SetSize(details:GetWide() - 24 * S, 48 * S)
        titre:SetFont("NA.Inv.Texte") titre:SetTextColor(blanc) titre:SetWrap(true) titre:SetText(selection.item)
        local typeObjet = TYPES[selection.type or "objet"] or TYPES.objet
        local label = vgui.Create("DLabel", details)
        label:SetPos(12 * S, 58 * S) label:SetSize(details:GetWide() - 24 * S, 24 * S)
        local rarete = Rarete(selection)
        label:SetFont("NA.Inv.Petit") label:SetTextColor(rarete.couleur)
        label:SetText(typeObjet.nom .. " · " .. rarete.nom)
        local actif = selectionEquip ~= nil or Cible(selection) ~= nil
        local texte = selectionEquip and "RETIRER" or (actif and "ÉQUIPER" or "Aucune action disponible")
        local b = Bouton(details, texte, 8 * S, 88 * S, details:GetWide() - 16 * S, 55 * S, function()
            if selectionEquip then Desequiper(selectionEquip) elseif selectionSlot and actif then Equiper(selectionSlot) end
        end)
        b:SetEnabled(actif)
        b.Paint = function(p, w, h)
            Texture("utiliser", 0, 0, w, h, actif and (p:IsHovered() and 255 or 205) or 65)
            draw.SimpleText(texte, "NA.Inv.Petit", w / 2, h / 2, actif and blanc or doux, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    frame.Reconstruire = function()
        selection, selectionSlot, selectionEquip = nil, nil, nil
        ConstruireGrille() ConstruireEquipement() ActualiserDetails()
    end
    frame.Reconstruire()
end

local function ToggleMenu()
    if IsValid(frame) then
        FermerMenu()
    else
        OuvrirMenu()
    end
end

concommand.Add("mon_menu", ToggleMenu)

-- F4 : ouvre / ferme (sauf en écrivant dans le chat ou un champ de texte)
local toucheAvant = false
hook.Add("Think", "UI_F4_Toggle", function()
    local bas = input.IsKeyDown(TOUCHE)
    if bas and not toucheAvant then
        local focus = vgui.GetKeyboardFocus()
        local ecrit = IsValid(focus) and focus:GetClassName() == "TextEntry"
        local ply = LocalPlayer()
        if not ecrit and not (IsValid(ply) and ply:IsTyping()) then
            ToggleMenu()
        end
    end
    toucheAvant = bas
end)

----------------------------------------------------------
-- TEST : "test_items" dans la console remplit l'inventaire d'exemples
----------------------------------------------------------
concommand.Add("test_items", function()
    AjouterItem(1, "Potion de Vie", 5, "ui/inventory/fer_etoiles.png", "objet")
    AjouterItem(2, "Katana Légendaire", 1, "ui/inventory/fer_etoiles.png", "arme")

    AjouterItem(3, "Tenue Senju", 1, nil, "armure", nil, "models/tenue/senju/senju_a.mdl")
    AjouterItem(4, "Tenue Fuma", 1, nil, "armure", nil, "models/tenue/m_fuma_tkj.mdl")
    AjouterItem(5, "Tenue Salamandre Chef", 1, nil, "armure", nil, "models/salamandre/eclypse_salamandre_chef.mdl")
    AjouterItem(14, "Tenue salamandre chunin", 1, nil, "armure", nil, "models/salamandre/m_chunin1_salamandre.mdl")
    AjouterItem(15, "Tenue salamandre chunin", 1, nil, "armure", nil, "models/salamandre/m_chunin2_salamandre.mdl")
    AjouterItem(16, "Tenue salamandre", 1, nil, "armure", nil, "models/salamandre/goro_salamandre_m.mdl")

    AjouterItem(6, "Masque ANBU", 1, nil, "accessoire", "masque",
        "models/accessory/mask_hanzou.mdl", "ValveBiped.Bip01_Head1", Vector(1.7, 0, 2), Angle(-90, -90, 0), 1)
    AjouterItem(10, "Anneau de Chakra", 1, nil, "accessoire", nil,
        "models/accessory/ring_model.mdl", "ValveBiped.Bip01_R_Hand", Vector(0, 0, 0), Angle(0, 0, 0), 0.8)

    AjouterItem(7, "Bois ancestral", 12, "ui/inventory/bois_ancestral.png", "objet")
    AjouterItem(8, "Soie céleste", 4, "ui/inventory/soie_celeste.png", "objet")
    AjouterItem(9, "Minerai de fer brut", 20, "ui/inventory/minerai_fer_brut.png", "objet")

    -- Exemples explicites ; aucun niveau n'est déduit du nom de l'objet.
    for slot, rarete in pairs({ [2] = "legendaire", [3] = "rare", [5] = "epique", [6] = "rare", [7] = "rare", [8] = "epique", [10] = "epique" }) do
        DefinirRareteItem(slot, rarete)
    end

    print("[Inventaire] Objets de test ajoutés - F4 pour ouvrir")
end)
