--========================================================
-- Inventaire et équipement (CLIENT)
-- Ouvre avec F4, ou la commande console : mon_menu
--
--   Gauche : onglets (Inventaire, Boutique, Hôtel de vente)
--   Centre : les objets, avec recherche
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
local FOND      = "ui/inventory/back_ame.png"   -- ou back_konoah.png / back_suna.png
local NB_CASES  = 40
local COLONNES  = 8
local TOUCHE    = KEY_F4

-- Taille à l'écran
local LARGEUR_ECRAN = 0.80   -- part de la largeur de l'écran occupée par le menu
local HAUTEUR_MAX   = 0.75   -- hauteur maximale (part de la hauteur de l'écran)
local ETIREMENT_MAX = 1.30   -- étirement vertical permis du fond (1 = proportions d'origine)
--========================================================

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
local function CreerPolices(f)
    f = math.max(f or 1, 0.7)
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

----------------------------------------------------------
-- Données
----------------------------------------------------------
local Inventaire = {}
local SlotsEquipement = {}

-- "defaut" = placement d'origine de l'objet (bouton Réinitialiser de l'éditeur)
-- "classe" = classe de l'arme (épées) donnée au joueur quand elle est équipée
local CHAMPS = { "item", "image", "type", "sousType", "modelPath", "boneName", "posOffset", "angOffset", "scale", "defaut", "classe" }

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

function AjouterItem(slot, nomItem, quantite, imagePath, itemType, sousType, modelPath, boneName, posOffset, angOffset, scale)
    if slot < 1 or slot > NB_CASES then return end
    Inventaire[slot] = {
        item = nomItem, quantite = quantite or 1, image = imagePath,
        type = itemType, sousType = sousType, modelPath = modelPath,
        boneName = boneName, posOffset = posOffset, angOffset = angOffset, scale = scale,
        defaut = {
            pos = posOffset and Vector(posOffset) or Vector(0, 0, 0),
            ang = angOffset and Angle(angOffset) or Angle(0, 0, 0),
            scale = scale or 1,
        },
    }
    RafraichirUI()
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
            liste[#liste + 1] = { classe = classe, nom = def.PrintName or classe, modele = def.WorldModel }
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

    AjouterItem(libre, e.nom, 1, nil, "arme", nil, e.modele)
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
    mp:SetFOV(48)
    mp:SetCamPos(Vector(86, 30, 46))   -- assez loin et haut pour que les cheveux ne soient pas coupés
    mp:SetLookAt(Vector(0, 0, 40))
    mp:SetColor(IsValid(ply) and ply:GetColor() or color_white)
    mp:SetDirectionalLight(BOX_TOP, Color(255, 245, 230))
    mp:SetAmbientLight(Color(90, 80, 70))

    local ent = mp:GetEntity()
    if not IsValid(ent) then return mp end

    local seq = ent:LookupSequence("idle_all_01")
    if seq and seq >= 0 then ent:ResetSequence(seq) end

    mp.Extras = Fusionner(ent, ElementsDuJoueur(EXCLURE_ICONE))

    function mp:LayoutEntity(e)
        e:SetAngles(Angle(0, 0, 0))
        self:RunAnimation()
    end
    function mp:PostDrawModel()
        DessinerExtras(self.Extras, self:GetEntity())
    end
    function mp:OnRemove()
        SupprimerExtras(self.Extras)
    end

    return mp
end

----------------------------------------------------------
-- Icône d'un objet : image si elle existe, sinon icône du modèle 3D
----------------------------------------------------------
local function CreerIcone(parent, it, taille)
    local marge = math.floor(taille * 0.12)

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
    ap:SetAmbientLight(Color(90, 80, 70))

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

    function ap:OnRemove()
        SupprimerExtras(self.Extras)
        for _, a in ipairs(self.Accessoires or {}) do if IsValid(a.cs) then a.cs:Remove() end end
        if self.Epee and IsValid(self.Epee.cs) then self.Epee.cs:Remove() end
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
        local c = vgui.Create("DNumSlider", corps)
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
    if NA_FermerAutresMenus then NA_FermerAutresMenus("inventaire") end   -- un seul menu à la fois

    -- Taille : presque toute la largeur de l'écran. L'image de fond (1578 x 573)
    -- est très allongée : on l'étire un peu en hauteur (ETIREMENT_MAX) pour que
    -- le menu ne soit pas un simple bandeau, sans dépasser HAUTEUR_MAX de l'écran.
    local W = ScrW() * LARGEUR_ECRAN
    local H = math.min(W * 573 / 1578 * ETIREMENT_MAX, ScrH() * HAUTEUR_MAX)
    local SX, SY = W / 1578, H / 573
    local S = SX

    -- textes à la taille du menu
    CreerPolices(H / 566)

    -- position des 3 panneaux, mesurée dans l'image de fond
    local function Zone(x1, y1, x2, y2)
        return x1 * SX, y1 * SY, (x2 - x1) * SX, (y2 - y1) * SY
    end
    local gX, gY, gW, gH = Zone(12, 46, 321, 525)     -- panneau gauche
    local cX, cY, cW, cH = Zone(325, 46, 1081, 525)   -- panneau central
    local dX, dY, dW, dH = Zone(1085, 46, 1565, 525)  -- panneau droit

    frame = vgui.Create("DPanel")
    frame:SetSize(W, H)
    frame:Center()
    frame:MakePopup()
    -- le clavier reste au jeu : on peut bouger (ZQSD, saut...) avec le menu ouvert.
    -- Il n'est repris que pendant qu'on écrit dans la recherche.
    frame:SetKeyboardInputEnabled(false)

    frame.Paint = function(pan, w, h)
        surface.SetMaterial(M(FOND))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
    end

    -- Échap ferme (sans ouvrir le menu du jeu) ; F4 est déjà géré par le Think
    -- en bas du fichier (le gérer ici aussi fermait puis rouvrait le menu)
    frame.Think = function()
        if input.IsKeyDown(KEY_ESCAPE) then
            FermerMenu()
            gui.HideGameUI()
        end
    end

    -- fermer
    local fermer = vgui.Create("DButton", frame)
    fermer:SetText("")
    fermer:SetSize(34 * S * 1.4, 34 * S * 1.4)
    fermer:SetPos(W - fermer:GetWide() - 8, 4)
    fermer.Paint = function(pan, w, h)
        draw.SimpleText("X", "NA.Inv.Onglet", w / 2, h / 2,
            pan:IsHovered() and Color(255, 220, 200) or Color(235, 215, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    fermer.DoClick = FermerMenu

    ------------------------------------------------------
    -- Panneau gauche : onglets
    ------------------------------------------------------
    local gauche = vgui.Create("DPanel", frame)
    gauche:SetPos(gX, gY)
    gauche:SetSize(gW, gH)
    gauche.Paint = function(pan, w, h)
        draw.SimpleText("Inventaire", "NA.Inv.Titre", w * 0.12, h * 0.07, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetMaterial(M("ui/inventory/left_vector.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(w * 0.06, h * 0.13, w * 0.88, 2)
    end

    local function Onglet(y, icone, texte, actif)
        local b = vgui.Create("DButton", gauche)
        b:SetText("")
        b:SetPos(gW * 0.08, gH * y)
        b:SetSize(gW * 0.84, gH * 0.22)
        b.Paint = function(pan, w, h)
            local a = actif and 255 or 120
            local t = h * 0.72
            surface.SetMaterial(M(icone))
            surface.SetDrawColor(255, 255, 255, a)
            surface.DrawTexturedRect(w / 2 - t * 0.55, 0, t * 1.1, t)
            draw.SimpleText(texte, "NA.Inv.Onglet", w / 2, h * 0.86,
                Color(C_TEXTE.r, C_TEXTE.g, C_TEXTE.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            if actif then
                surface.SetDrawColor(C_ROUGE)
                surface.DrawRect(w * 0.2, h - 2, w * 0.6, 2)
            end
        end
        if not actif then
            b:SetTooltip("Bientôt disponible")
            b.DoClick = function() surface.PlaySound("buttons/button10.wav") end
        end
        return b
    end

    -- l'inventaire est l'onglet actif ; boutique et hôtel de vente arrivent plus tard
    local ongletInv = vgui.Create("DButton", gauche)
    ongletInv:SetText("")
    ongletInv:SetPos(gW * 0.08, gH * 0.17)
    ongletInv:SetSize(gW * 0.84, gH * 0.09)
    ongletInv.Paint = function(pan, w, h)
        surface.SetMaterial(M("ui/inventory/btn_inventory.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
        draw.SimpleText("Mes objets", "NA.Inv.Onglet", w / 2, h / 2, C_ROUGE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    Onglet(0.32, "ui/inventory/icon_boutique.png", "BOUTIQUE", false)
    Onglet(0.58, "ui/inventory/icon_hdv.png", "HÔTEL DE VENTE", false)

    ------------------------------------------------------
    -- Panneau central : recherche + grille d'objets
    ------------------------------------------------------
    local centre = vgui.Create("DPanel", frame)
    centre:SetPos(cX, cY)
    centre:SetSize(cW, cH)
    centre.Paint = function() end

    local pad = cW * 0.03
    local recherche = ""

    local barre = vgui.Create("DPanel", centre)
    barre:SetPos(pad, pad * 0.8)
    barre:SetSize(cW - pad * 2, 36 * math.max(SY, 0.8))
    barre.Paint = function(pan, w, h)
        local nb = 0
        for i = 1, NB_CASES do if Inventaire[i].item then nb = nb + 1 end end
        draw.SimpleText(nb .. " / " .. NB_CASES .. " objets", "NA.Inv.Texte", w, h / 2, C_TEXTE_DOUX, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local champ = vgui.Create("DTextEntry", barre)
    champ:SetSize(barre:GetWide() * 0.5, barre:GetTall())
    champ:SetPos(0, 0)
    champ:SetFont("NA.Inv.Texte")
    champ:SetPlaceholderText("Rechercher un objet...")
    champ:SetUpdateOnType(true)
    champ:SetTextColor(C_TEXTE)
    champ.Paint = function(pan, w, h)
        surface.SetMaterial(M("ui/inventory/search.png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(0, 0, w, h)
        pan:DrawTextEntryText(C_TEXTE, C_ROUGE, C_TEXTE)
        if pan:GetValue() == "" and not pan:HasFocus() then
            draw.SimpleText("Rechercher un objet...", "NA.Inv.Texte", 12, h / 2, C_TEXTE_DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    champ:SetTextInset(12, 0)

    -- clavier pris seulement pendant la saisie, rendu au jeu ensuite (Entrée ou clic ailleurs)
    champ.OnGetFocus = function(pan)
        if IsValid(frame) then frame:SetKeyboardInputEnabled(true) end
        hook.Run("OnTextEntryGetFocus", pan)
    end
    champ.OnLoseFocus = function(pan)
        if IsValid(frame) then frame:SetKeyboardInputEnabled(false) end
        hook.Run("OnTextEntryLoseFocus", pan)
        pan:UpdateConvarValue()
    end
    champ.OnEnter = function(pan) pan:KillFocus() end

    local defil = vgui.Create("DScrollPanel", centre)
    local haut = pad * 0.8 + barre:GetTall() + pad * 0.6
    defil:SetPos(pad, haut)
    defil:SetSize(cW - pad * 2, cH - haut - pad * 0.6)

    local vbar = defil:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function() end
    vbar.btnUp.Paint = function() end
    vbar.btnDown.Paint = function() end
    vbar.btnGrip.Paint = function(pan, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(120, 90, 70, 160)) end

    local ecart = math.max(4, math.floor(8 * S))
    local tailleCase = math.floor((defil:GetWide() - 10 - ecart * (COLONNES - 1)) / COLONNES)

    local grille = defil:Add("DIconLayout")   -- dans la zone qui défile
    grille:Dock(FILL)
    grille:SetSpaceX(ecart)
    grille:SetSpaceY(ecart)

    local survol -- objet sous la souris (pour l'infobulle)

    local function ConstruireGrille()
        grille:Clear()
        local filtre = string.lower(recherche)

        for i = 1, NB_CASES do
            local it = Inventaire[i]
            local correspond = filtre == "" or (it.item and string.find(string.lower(it.item), filtre, 1, true))
            if filtre ~= "" and not correspond then continue end

            local case = grille:Add("DButton")
            case:SetText("")
            case:SetSize(tailleCase, tailleCase)

            case.Paint = function(pan, w, h)
                surface.SetMaterial(M("ui/inventory/case/case.png"))
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(0, 0, w, h)

                if it.item then
                    -- liseré de couleur selon le type d'objet
                    local t = TYPES[it.type or "objet"] or TYPES.objet
                    surface.SetDrawColor(t.couleur.r, t.couleur.g, t.couleur.b, 150)
                    surface.DrawRect(4, h - 5, w - 8, 2)
                end
                if pan:IsHovered() then
                    draw.RoundedBox(6, 2, 2, w - 4, h - 4, C_SURVOL)
                end
            end

            case.PaintOver = function(pan, w, h)
                if it.item and (it.quantite or 0) > 1 then
                    draw.SimpleText("x" .. it.quantite, "NA.Inv.Qte", w - 6, h - 6, C_TEXTE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
                end
            end

            if it.item then CreerIcone(case, it, tailleCase) end

            case.OnCursorEntered = function() survol = it.item and it or nil end
            case.OnCursorExited = function() if survol == it then survol = nil end end
            case.DoRightClick = function() if it.item then Equiper(i) end end
            case.DoDoubleClick = function() if it.item then Equiper(i) end end
        end
    end

    champ.OnValueChange = function(pan, val)
        recherche = val or ""
        ConstruireGrille()
    end

    ------------------------------------------------------
    -- Panneau droit : équipement + aperçu du personnage
    ------------------------------------------------------
    local droite = vgui.Create("DPanel", frame)
    droite:SetPos(dX, dY)
    droite:SetSize(dW, dH)
    droite.Paint = function(pan, w, h)
        draw.SimpleText(LocalPlayer():Nick(), "NA.Inv.Texte", w / 2, h * 0.05, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local tailleEquip = math.floor(tailleCase * 1.1)

    local function ConstruireEquipement()
        droite:Clear()

        -- aperçu au centre
        local apW = dW * 0.5
        local ap = CreerApercu(droite)
        ap:SetPos(dW / 2 - apW / 2, dH * 0.09)
        ap:SetSize(apW, dH * 0.9)

        -- emplacements de part et d'autre
        local rang = { gauche = 0, droite = 0 }
        for _, e in ipairs(EMPLACEMENTS) do
            local n = rang[e.cote]
            rang[e.cote] = n + 1

            local x = (e.cote == "gauche") and (dW * 0.25 - tailleEquip / 2 - dW * 0.06) or (dW * 0.75 - tailleEquip / 2 + dW * 0.06)
            local y = dH * 0.18 + n * (tailleEquip + dH * 0.1)

            local slot = vgui.Create("DButton", droite)
            slot:SetText("")
            slot:SetPos(x, y)
            slot:SetSize(tailleEquip, tailleEquip)

            local it = SlotsEquipement[e.id]

            slot.Paint = function(pan, w, h)
                surface.SetMaterial(M("ui/inventory/case/case.png"))
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(0, 0, w, h)

                if not it then
                    -- silhouette de l'emplacement vide
                    local t = w * 0.62
                    surface.SetMaterial(M(e.icone))
                    surface.SetDrawColor(255, 255, 255, 90)
                    surface.DrawTexturedRect(w / 2 - t / 2, h / 2 - t / 2, t, t)
                end
                if pan:IsHovered() then
                    draw.RoundedBox(6, 2, 2, w - 4, h - 4, C_SURVOL)
                end
            end

            -- nom de l'emplacement sous la case (un panneau ne peut pas dessiner
            -- hors de ses bords : il faut un libellé à part)
            local nom = vgui.Create("DLabel", droite)
            nom:SetFont("NA.Inv.Petit")
            nom:SetTextColor(C_TEXTE_DOUX)
            nom:SetText(e.nom)
            nom:SizeToContents()
            nom:SetPos(x + tailleEquip / 2 - nom:GetWide() / 2, y + tailleEquip + 3)

            -- masque / accessoire équipé : bouton pour régler son placement
            if it and (e.id == "masque" or e.id == "accessoire" or (e.id == "arme" and it.classe)) then
                local aj = vgui.Create("DButton", droite)
                aj:SetText("")
                aj:SetSize(tailleEquip, 22)
                aj:SetPos(x, y + tailleEquip + 3 + nom:GetTall() + 2)
                aj.Paint = function(pan, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, pan:IsHovered() and C_ROUGE or Color(C_ROUGE.r, C_ROUGE.g, C_ROUGE.b, 190))
                    draw.SimpleText("Ajuster", "NA.Inv.Petit", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                aj.DoClick = function() OuvrirEditeur(e.id) end
                slot.DoMiddleClick = function() OuvrirEditeur(e.id) end
            end

            if it then CreerIcone(slot, it, tailleEquip) end

            slot.OnCursorEntered = function() survol = it and it or nil end
            slot.OnCursorExited = function() if survol == it then survol = nil end end
            slot.DoRightClick = function() Desequiper(e.id) end
            slot.DoDoubleClick = function() Desequiper(e.id) end
        end
    end

    ------------------------------------------------------
    -- Infobulle
    ------------------------------------------------------
    frame.PaintOver = function(pan, w, h)
        if not survol or not survol.item then return end

        local mx, my = pan:CursorPos()
        local t = TYPES[survol.type or "objet"] or TYPES.objet
        local equipe = false
        for _, v in pairs(SlotsEquipement) do if v == survol then equipe = true end end

        local ligne1 = survol.item
        local ligne2 = t.nom .. (survol.sousType and (" · " .. survol.sousType) or "")
        local ligne3 = equipe and "Clic droit : retirer" or (Cible(survol) and "Clic droit : équiper" or "")
        if equipe and survol.type == "accessoire" then
            ligne3 = "Clic droit : retirer  •  molette : ajuster"
        end

        surface.SetFont("NA.Inv.Texte")
        local w1 = surface.GetTextSize(ligne1)
        surface.SetFont("NA.Inv.Petit")
        local w2 = surface.GetTextSize(ligne2)
        local w3 = surface.GetTextSize(ligne3)
        local bw = math.max(w1, w2, w3) + 24
        local bh = ligne3 ~= "" and 72 or 52

        local bx = math.min(mx + 16, w - bw - 4)
        local by = math.max(my - bh - 6, 4)

        draw.RoundedBox(6, bx, by, bw, bh, Color(90, 60, 45, 255))
        draw.RoundedBox(6, bx + 1, by + 1, bw - 2, bh - 2, C_INFOBULLE)
        surface.SetDrawColor(t.couleur)
        surface.DrawRect(bx + 1, by + 6, 3, bh - 12)

        draw.SimpleText(ligne1, "NA.Inv.Texte", bx + 12, by + 8, C_TEXTE)
        draw.SimpleText(ligne2, "NA.Inv.Petit", bx + 12, by + 30, t.couleur)
        if ligne3 ~= "" then
            draw.SimpleText(ligne3, "NA.Inv.Petit", bx + 12, by + 50, C_TEXTE_DOUX)
        end
    end

    frame.Reconstruire = function()
        survol = nil
        ConstruireGrille()
        ConstruireEquipement()
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

    print("[Inventaire] Objets de test ajoutés - F4 pour ouvrir")
end)
