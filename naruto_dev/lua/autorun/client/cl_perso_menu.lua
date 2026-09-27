--========================================================
-- Personnalisation du personnage (CLIENT) : menu
-- Ouvre avec la commande console "perso" ou le chat !perso
--
--   Gauche : aperçu 3D du personnage (clic gauche maintenu : tourner, molette : zoom)
--   Droite : onglets Visage, Cheveux, Détails (yeux, nez, sourcils, barbe), Couleurs
--   "Enregistrer" envoie le choix au serveur (sv_perso.lua), qui le valide et le garde.
--
-- Données et validation : _na_perso.lua. Matériaux des visages : cl_perso.lua.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local LARGEUR, HAUTEUR = 1000, 660
local LARGEUR_APERCU   = 360
local COLONNES, LIGNES = 4, 3          -- vignettes par page (Visage, Cheveux)
local VIGNETTE_L, VIGNETTE_H = 142, 146
local ESPACE = 6

-- Couleurs proposées (on peut aussi en choisir une librement dans le sélecteur)
local PALETTES = {
    peau = { {255,232,215}, {255,210,180}, {240,190,150}, {220,165,125}, {190,130,95}, {150,100,70}, {110,75,55}, {75,50,38} },
    cheveux = { {0,0,0}, {40,28,22}, {85,55,35}, {140,95,55}, {210,170,90}, {240,225,160}, {255,255,255}, {170,170,175},
                {190,45,35}, {240,120,150}, {70,110,200}, {60,150,90} },
    yeux = { {70,45,30}, {30,30,30}, {60,110,190}, {80,150,90}, {140,140,150}, {190,40,40}, {150,60,170}, {230,190,60} },
}
PALETTES.sourcils = PALETTES.cheveux
PALETTES.bandeau = { {255,255,255}, {20,20,20}, {190,45,35}, {70,110,200}, {60,150,90}, {230,140,40}, {150,60,170}, {130,130,140},
                     {240,225,160}, {240,120,150}, {110,70,40}, {40,60,120} }
--========================================================

local P = NA_PERSO

local C_FOND    = Color(28, 24, 22, 250)
local C_PANNEAU = Color(44, 38, 34)
local C_BOUTON  = Color(66, 56, 50)
local C_SURVOL  = Color(96, 80, 70)
local C_ACCENT  = Color(165, 45, 40)
local C_TEXTE   = Color(240, 230, 215)
local C_DOUX    = Color(170, 155, 140)

surface.CreateFont("NA.Perso.Titre", { font = "Roboto", size = 22, weight = 800 })
surface.CreateFont("NA.Perso.Texte", { font = "Roboto", size = 16, weight = 600 })
surface.CreateFont("NA.Perso.Petit", { font = "Roboto", size = 14, weight = 600 })

local YEUX_ORIGINE = "models/naruto_dev/yeux/normal"   -- yeux de la tête d'origine (sv_yeux.lua)

local fenetre, apercu, contenu, brouillon

local function Col(c) return Color(c[1], c[2], c[3]) end

----------------------------------------------------------
-- Aperçu 3D : corps du joueur + tête + cheveux (même principe que le menu F4)
----------------------------------------------------------
local function NettoyerPieces(mp)
    for _, cs in ipairs({ mp.Tete, mp.Cheveux }) do
        if IsValid(cs) then cs:Remove() end
    end
    mp.Tete, mp.Cheveux, mp.CleModeles = nil, nil, nil
end

-- recul > 0 : pièce non fusionnée, dessinée reculée (NA_DessinerRecul, cl_perso.lua)
local function Piece(ent, modele, recul)
    local cs = ClientsideModel(modele, RENDERGROUP_OPAQUE)
    if not IsValid(cs) then return end
    cs:SetNoDraw(true)
    cs.Couleur = color_white
    if recul and recul > 0 then
        cs.Recul = recul
    else
        cs:SetParent(ent)
        cs:AddEffects(EF_BONEMERGE)
    end
    return cs
end

-- Pose le choix p sur l'aperçu mp. Les modèles ne sont recréés que s'ils changent.
local function Poser(mp, p)
    local ent = mp:GetEntity()
    if not IsValid(ent) then return end

    local recul = p.visage > 0 and p.recul or 0   -- visages numérotés : tête et cheveux reculés
    local cle = P.ModeleTete(p) .. "|" .. P.ModeleCheveux(p) .. "|" .. (recul > 0 and "recul" or "fusion")
    if mp.CleModeles ~= cle then
        NettoyerPieces(mp)
        mp.CleModeles = cle
        if mp.AvecTete then mp.Tete = Piece(ent, P.ModeleTete(p), recul) end
        if mp.AvecCheveux then mp.Cheveux = Piece(ent, P.ModeleCheveux(p), recul) end
    end
    for _, cs in ipairs({ mp.Tete or false, mp.Cheveux or false }) do
        if cs and cs.Recul then cs.Recul = recul end   -- le curseur change la valeur sans tout recréer
    end

    if IsValid(mp.Tete) then
        if p.visage > 0 then
            NA_HabillerVisage(mp.Tete, p, LocalPlayer():GetNW2String("NA_Yeux", ""))
        else   -- tête d'origine : sa peau et ses yeux sont dans des matériaux à part
            mp.Tete:SetSubMaterial(0, "models/naruto_dev/tete/visage")
            mp.Tete:SetSubMaterial(3, YEUX_ORIGINE)
            mp.Tete:SetSubMaterial(4, YEUX_ORIGINE)
        end
    end
    NA_TeinterCheveux(mp.Cheveux, p)

    NA_PeauCorps(ent, p)   -- peau du corps (la tenue n'est pas teintée)
end

-- Panneau 3D. opts : tete, cheveux (afficher ces pièces), dist (distance de la caméra)
local function CreerApercu(parent, opts)
    local mp = vgui.Create("DModelPanel", parent)
    mp:SetModel(LocalPlayer():GetModel())
    mp:SetFOV(30)
    mp:SetAmbientLight(Color(110, 105, 100))
    mp:SetDirectionalLight(BOX_FRONT, Color(255, 245, 235))
    mp:SetDirectionalLight(BOX_TOP, Color(200, 200, 200))
    mp.AvecTete, mp.AvecCheveux = opts.tete, opts.cheveux
    mp.Dist, mp.Haut, mp.Yaw = opts.dist, opts.haut or 0, 0

    local ent = mp:GetEntity()
    if IsValid(ent) then
        local seq = ent:LookupSequence("idle_all_01")
        if seq and seq >= 0 then ent:ResetSequence(seq) end
    end

    function mp:LayoutEntity(e)
        e:SetAngles(Angle(0, self.Yaw, 0))
        self:RunAnimation()

        local os = e:LookupBone("ValveBiped.Bip01_Head1")
        local tete = os and e:GetBonePosition(os)
        if not tete or tete == e:GetPos() then tete = e:GetPos() + Vector(0, 0, 64) end

        local vise = tete + Vector(0, 0, self.Haut)
        self:SetLookAt(vise)
        self:SetCamPos(vise + Vector(self.Dist, 0, 1))   -- le modèle regarde vers +X
    end

    function mp:PostDrawModel()
        for _, cs in ipairs({ self.Tete, self.Cheveux }) do
            if IsValid(cs) then
                if cs.NA_Forme then NA_PoserFormes(cs, 0) end   -- bouche, yeux, nez : reposés à chaque image
                if cs.Recul then
                    NA_DessinerRecul(cs, self:GetEntity(), cs.Recul)
                else
                    local c = cs.Couleur
                    render.SetColorModulation(c.r / 255, c.g / 255, c.b / 255)
                    cs:DrawModel()
                end
            end
        end
        render.SetColorModulation(1, 1, 1)
    end

    local ancien = mp.OnRemove
    function mp:OnRemove()
        NettoyerPieces(self)
        if ancien then ancien(self) end
    end
    return mp
end

-- Met à jour l'aperçu principal, au plus 10 fois par seconde (les curseurs de couleur
-- envoient des dizaines de valeurs : chacune crée un matériau, voir cl_perso.lua)
local function Rafraichir()
    if timer.Exists("NA_Perso_Maj") then return end
    timer.Create("NA_Perso_Maj", 0.1, 1, function()
        if IsValid(apercu) then Poser(apercu, brouillon) end
    end)
end

----------------------------------------------------------
-- Éléments d'interface
----------------------------------------------------------
local function Bouton(parent, texte, clic)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.Texte = texte
    function b:Paint(w, h)
        local actif = self.EstActif and self.EstActif()
        draw.RoundedBox(4, 0, 0, w, h, actif and C_ACCENT or (self:IsHovered() and C_SURVOL or C_BOUTON))
        draw.SimpleText(self.Texte, "NA.Perso.Texte", w / 2, h / 2, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = clic
    return b
end

local function Vide(p) p.Paint = function() end return p end

-- Rappel affiché quand le visage d'origine est choisi : lui n'a pas ces réglages
local function Astuce(parent)
    local a = Vide(vgui.Create("DPanel", parent))
    a:Dock(TOP)
    a:SetTall(24)
    a.Paint = function(_, w, h)
        if brouillon.visage == 0 then
            draw.SimpleText("Ce réglage demande un visage numéroté (onglet Visage).", "NA.Perso.Petit", 0, h / 2, C_ACCENT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    return a
end

----------------------------------------------------------
-- Onglets Visage et Cheveux : vignettes 3D, pagination
----------------------------------------------------------
local function Vignette(parent, x, y, champ, id)
    local p = table.Copy(brouillon)
    p[champ] = id
    if champ == "cheveux" and not P.EstClassique(id) and p.visage == 0 then p.visage = 1 end   -- coiffure : sur un visage numéroté

    local mp = CreerApercu(parent, { tete = true, cheveux = champ == "cheveux", dist = champ == "cheveux" and 46 or 34 })
    mp:SetPos(x, y)
    mp:SetSize(VIGNETTE_L, VIGNETTE_H)
    Poser(mp, p)

    mp.DoClick = function()
        brouillon[champ] = id
        -- les coiffures numérotées vont avec un visage numéroté, la classique avec la tête d'origine
        if champ == "cheveux" and not P.EstClassique(id) and brouillon.visage == 0 then brouillon.visage = 1 end
        if champ == "visage" and id == 0 then brouillon.cheveux = 0 end
        Rafraichir()
    end
    function mp:PaintOver(w, h)
        local choisi = brouillon[champ] == id
        surface.SetDrawColor(choisi and C_ACCENT or (self:IsHovered() and C_SURVOL or C_BOUTON))
        surface.DrawOutlinedRect(0, 0, w, h, choisi and 3 or 1)
        local nom = id == 0 and "Classique" or "N° " .. id
        if champ == "cheveux" then   -- coupes du modèle d'origine : nom de la coupe
            nom = P.NOMS_COUPES[(id == 0 and 0 or P.COUPES[id] or -1) + 1] and string.gsub(P.NOMS_COUPES[(id == 0 and 0 or P.COUPES[id]) + 1], "_", " ") or nom
        end
        draw.SimpleText(nom, "NA.Perso.Petit", 6, h - 5, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
    end
    return mp
end

local function CreerPages(parent, champ, nb)
    local pan = Vide(vgui.Create("DPanel", parent))
    pan:Dock(FILL)

    local ids = {}
    for i = 0, nb do ids[#ids + 1] = i end   -- 0 = aspect d'origine

    local parPage = COLONNES * LIGNES
    local nbPages = math.ceil(#ids / parPage)
    pan.Page = 0

    local nav = Vide(vgui.Create("DPanel", pan))
    nav:Dock(BOTTOM)
    nav:SetTall(32)
    local zone = Vide(vgui.Create("DPanel", pan))
    zone:Dock(FILL)

    function pan:Construire()
        zone:Clear()
        for k = 1, parPage do
            local id = ids[self.Page * parPage + k]
            if id == nil then break end
            local i = k - 1
            Vignette(zone, (i % COLONNES) * (VIGNETTE_L + ESPACE), math.floor(i / COLONNES) * (VIGNETTE_H + ESPACE), champ, id)
        end
    end

    local function Aller(delta)
        pan.Page = (pan.Page + delta) % nbPages
        pan:Construire()
    end
    local prec = Bouton(nav, "<  Précédent", function() Aller(-1) end)
    prec:Dock(LEFT) prec:SetWide(120)
    local suiv = Bouton(nav, "Suivant  >", function() Aller(1) end)
    suiv:Dock(RIGHT) suiv:SetWide(120)
    nav.Paint = function(_, w, h)
        draw.SimpleText("Page " .. (pan.Page + 1) .. " / " .. nbPages, "NA.Perso.Texte", w / 2, h / 2, C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ouvre la page du choix actuel
    function pan:Afficher()
        for n, id in ipairs(ids) do
            if id == brouillon[champ] then self.Page = math.floor((n - 1) / parPage) break end
        end
        self:Construire()
    end
    return pan
end

----------------------------------------------------------
-- Onglet Détails : yeux, nez, sourcils, barbe
----------------------------------------------------------
local materiauxSourcils = {}
local function MatSourcils(n)   -- aperçu à plat d'un sourcil (interface)
    if not materiauxSourcils[n] then
        materiauxSourcils[n] = CreateMaterial("na_perso_ui_sourcils_" .. n, "UnlitGeneric", {
            ["$basetexture"] = "atg/eyebrows/eyebrows_" .. n,
            ["$translucent"] = 1, ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
        })
    end
    return materiauxSourcils[n]
end

-- Range des boutons dans une grille (colonnes de largeur l), rend la hauteur utilisée
local function Grille(parent, y, elements, colonnes, l, h)
    for i, b in ipairs(elements) do
        b:SetParent(parent)
        b:SetPos(((i - 1) % colonnes) * (l + ESPACE), y + math.floor((i - 1) / colonnes) * (h + ESPACE))
        b:SetSize(l, h)
    end
    return math.ceil(#elements / colonnes) * (h + ESPACE)
end

local function CreerDetails(parent)
    local pan = Vide(vgui.Create("DPanel", parent))
    pan:Dock(FILL)
    Astuce(pan)

    local scroll = vgui.Create("DScrollPanel", pan)
    scroll:Dock(FILL)
    local toile = scroll:GetCanvas()
    local y = 0
    local function Section(texte)
        local t = Vide(vgui.Create("DPanel", toile))
        t:SetPos(0, y) t:SetSize(560, 28)
        t.Paint = function(_, w, h) draw.SimpleText(texte, "NA.Perso.Titre", 0, h - 4, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM) end
        y = y + 32
    end
    local function Choix(champ, valeur, texte)
        local b = Bouton(toile, texte, function() brouillon[champ] = valeur Rafraichir() end)
        b.EstActif = function() return brouillon[champ] == valeur end
        return b
    end

    Section("Logo du village (bandeau)")
    local logos = { Choix("logo", 0, "Par défaut") }
    for i, l in ipairs(P.LOGOS) do logos[#logos + 1] = Choix("logo", i, l[1]) end
    y = y + Grille(toile, y, logos, 4, 136, 28)

    Section("Forme des yeux")
    local yeux = {}
    for i, nom in ipairs(P.YEUX) do yeux[i] = Choix("yeux", i, nom) end
    y = y + Grille(toile, y, yeux, 4, 136, 28)

    Section("Nez")
    local nez = { Choix("nez", 0, "Normal") }
    for i, nom in ipairs(P.NEZ) do nez[#nez + 1] = Choix("nez", i, nom) end
    y = y + Grille(toile, y, nez, 4, 136, 28)

    Section("Bouche")
    y = y + Grille(toile, y, { Choix("bouche", 1, "Celle du visage"), Choix("bouche", 0, "Neutre") }, 4, 136, 28)

    Section("Recul du visage")
    local recul = vgui.Create("DNumSlider", toile)
    recul:SetPos(0, y)
    recul:SetSize(560, 28)
    recul:SetText("Recul (masque, col de la tenue)")
    recul:SetDark(false)
    recul:SetMin(0)
    recul:SetMax(4)
    recul:SetDecimals(1)
    recul:SetValue(brouillon.recul / 10)
    function recul:OnValueChanged(v)
        brouillon.recul = math.Round(v * 10)
        Rafraichir()
    end
    y = y + 40
    function pan:Afficher() recul:SetValue(brouillon.recul / 10) end   -- remis à jour (Aléatoire, Aspect d'origine...)

    Section("Barbe")
    local barbes = { Choix("barbe", 0, "Aucune") }
    for i = 1, P.NB_BARBES do barbes[#barbes + 1] = Choix("barbe", i, "Barbe " .. i) end
    y = y + Grille(toile, y, barbes, 4, 136, 28)

    Section("Sourcils")
    local sourcils = {}
    for i = 1, P.NB_SOURCILS do
        local b = Choix("sourcils", i, "")
        function b:Paint(w, h)
            local actif = brouillon.sourcils == i
            draw.RoundedBox(4, 0, 0, w, h, actif and C_ACCENT or (self:IsHovered() and C_SURVOL or C_BOUTON))
            local peau = brouillon.visage > 0 and brouillon.peau or P.DEFAUT.peau
            draw.RoundedBox(3, 3, 3, w - 6, h - 6, Col(peau))
            surface.SetMaterial(MatSourcils(i))
            surface.SetDrawColor(brouillon.sourcils_c[1], brouillon.sourcils_c[2], brouillon.sourcils_c[3], 255)
            surface.DrawTexturedRect(3, 3, w - 6, (w - 6) / 4)
        end
        sourcils[i] = b
    end
    y = y + Grille(toile, y, sourcils, 4, 136, 44)

    return pan
end

----------------------------------------------------------
-- Onglet Couleurs : peau, cheveux (et barbe), yeux, sourcils
----------------------------------------------------------
local CIBLES = {
    { champ = "peau",       cle = "peau",     nom = "Peau" },
    { champ = "cheveux_c",  cle = "cheveux",  nom = "Cheveux" },
    { champ = "yeux_c",     cle = "yeux",     nom = "Iris" },
    { champ = "sourcils_c", cle = "sourcils", nom = "Sourcils" },
    { champ = "bandeau_c",  cle = "bandeau",  nom = "Bandeau" },
}

local function CreerCouleurs(parent)
    local pan = Vide(vgui.Create("DPanel", parent))
    pan:Dock(FILL)
    Astuce(pan)

    -- (l'ordre de création est l'ordre d'empilement des panneaux "Dock")
    local barre = Vide(vgui.Create("DPanel", pan))   -- boutons : quelle couleur régler
    barre:Dock(TOP)
    barre:SetTall(36)
    local pastilles = Vide(vgui.Create("DPanel", pan))   -- couleurs proposées
    pastilles:Dock(TOP)
    pastilles:SetTall(90)
    pastilles:DockMargin(0, 10, 0, 10)
    local mixer = vgui.Create("DColorMixer", pan)   -- choix libre
    mixer:Dock(FILL)
    mixer:SetPalette(false)
    mixer:SetAlphaBar(false)
    mixer:SetWangs(true)

    local cible = CIBLES[2]
    local enCours = false   -- vrai pendant qu'on pose une couleur dans le sélecteur (pas de retour)

    local function Definir(c)
        brouillon[cible.champ] = { c[1], c[2], c[3] }
        Rafraichir()
    end
    function mixer:ValueChanged(c)
        if not enCours then Definir({ c.r, c.g, c.b }) end
    end

    local function Choisir(c)
        cible = c
        enCours = true
        mixer:SetColor(Col(brouillon[c.champ]))
        enCours = false
        pastilles:Clear()
        for i, couleur in ipairs(PALETTES[c.cle]) do
            local b = vgui.Create("DButton", pastilles)
            b:SetText("")
            b:SetPos((i - 1) % 12 * 44, math.floor((i - 1) / 12) * 44)
            b:SetSize(38, 38)
            function b:Paint(w, h)
                draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and color_white or C_BOUTON)
                draw.RoundedBox(3, 2, 2, w - 4, h - 4, Col(couleur))
            end
            b.DoClick = function()
                Definir(couleur)
                enCours = true
                mixer:SetColor(Col(couleur))
                enCours = false
            end
        end
    end
    for _, c in ipairs(CIBLES) do
        local b = Bouton(barre, c.nom, function() Choisir(c) end)
        b.EstActif = function() return cible == c end
        b:Dock(LEFT)
        b:SetWide(110)
        b:DockMargin(0, 0, 6, 0)
    end

    function pan:Afficher() Choisir(cible) end
    return pan
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local function Fermer()
    if IsValid(fenetre) then fenetre:Close() end
end

local function Aleatoire()
    local function Alea(liste) return table.Copy(liste[math.random(#liste)]) end
    brouillon = {
        visage = math.random(P.NB_VISAGES), cheveux = #P.CHEVEUX > 0 and math.random(#P.CHEVEUX) or 0,
        yeux = math.random(#P.YEUX), nez = math.random(0, #P.NEZ), sourcils = math.random(P.NB_SOURCILS),
        barbe = math.random() < 0.3 and math.random(P.NB_BARBES) or 0,
        peau = Alea(PALETTES.peau), cheveux_c = Alea(PALETTES.cheveux),
        yeux_c = Alea(PALETTES.yeux), sourcils_c = nil, bandeau_c = Alea(PALETTES.bandeau),
    }
    brouillon.sourcils_c = table.Copy(brouillon.cheveux_c)
    brouillon = P.Valider(brouillon)   -- complète les champs non tirés au hasard (bouche, réglages...)
end

local function Ouvrir()
    if IsValid(fenetre) then Fermer() return end

    brouillon = table.Copy(P.Decoder(LocalPlayer():GetNW2String("NA_Perso", "")))

    fenetre = vgui.Create("DFrame")
    fenetre:SetSize(LARGEUR, HAUTEUR)
    fenetre:Center()
    fenetre:SetTitle("")
    fenetre:MakePopup()
    fenetre:SetDraggable(false)
    function fenetre:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, C_FOND)
        draw.SimpleText("Personnalisation du personnage", "NA.Perso.Titre", 16, 20, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    -- aperçu à gauche
    apercu = CreerApercu(fenetre, { tete = true, cheveux = true, dist = 42, haut = -3 })
    apercu:SetPos(10, 44)
    apercu:SetSize(LARGEUR_APERCU, HAUTEUR - 44 - 60)
    apercu:SetMouseInputEnabled(true)
    function apercu:OnMousePressed(k)
        if k ~= MOUSE_LEFT then return end
        self.Glisse, self.DepartX = true, gui.MouseX()
        self:MouseCapture(true)
    end
    function apercu:OnMouseReleased()
        self.Glisse = false
        self:MouseCapture(false)
    end
    function apercu:OnCursorMoved()
        if not self.Glisse then return end
        self.Yaw = self.Yaw + (gui.MouseX() - self.DepartX) * 0.6
        self.DepartX = gui.MouseX()
    end
    function apercu:OnMouseWheeled(d) self.Dist = math.Clamp(self.Dist - d * 4, 28, 120) end
    function apercu:PaintOver(w, h)
        surface.SetDrawColor(C_BOUTON)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    Poser(apercu, brouillon)

    -- vues : gros plan (bouche, yeux, nez bien visibles), buste, corps entier
    local VUES = { { "Gros plan", 26, 0 }, { "Buste", 42, -3 }, { "Corps", 110, -28 } }
    local vue = 2
    local zoom = Bouton(apercu, "", function()
        vue = vue % #VUES + 1
        apercu.Dist, apercu.Haut = VUES[vue][2], VUES[vue][3]
    end)
    zoom:SetSize(110, 28)
    zoom:SetPos(LARGEUR_APERCU - 118, HAUTEUR - 44 - 60 - 36)
    function zoom:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and C_SURVOL or C_BOUTON)
        draw.SimpleText("Vue : " .. VUES[vue][1], "NA.Perso.Petit", w / 2, h / 2, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- onglets à droite
    local x0 = LARGEUR_APERCU + 22
    local largeurContenu = LARGEUR - x0 - 12
    local barre = Vide(vgui.Create("DPanel", fenetre))
    barre:SetPos(x0, 44)
    barre:SetSize(largeurContenu, 34)
    local zone = vgui.Create("DPanel", fenetre)
    zone:SetPos(x0, 88)
    zone:SetSize(largeurContenu, HAUTEUR - 88 - 60)
    zone.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, C_PANNEAU) end
    zone:DockPadding(10, 10, 10, 10)

    contenu = {
        visage   = CreerPages(zone, "visage", P.NB_VISAGES),
        cheveux  = CreerPages(zone, "cheveux", #P.CHEVEUX),
        details  = CreerDetails(zone),
        couleurs = CreerCouleurs(zone),
    }
    local actuel
    local function Montrer(id)
        actuel = id
        for nom, pan in pairs(contenu) do pan:SetVisible(nom == id) end
        if contenu[id].Afficher then contenu[id]:Afficher() end
    end
    for _, o in ipairs({ { "visage", "Visage" }, { "cheveux", "Cheveux" }, { "details", "Détails" }, { "couleurs", "Couleurs" } }) do
        local b = Bouton(barre, o[2], function() Montrer(o[1]) end)
        b.EstActif = function() return actuel == o[1] end
        b:Dock(LEFT)
        b:SetWide(120)
        b:DockMargin(0, 0, 6, 0)
    end
    Montrer("visage")

    -- boutons du bas
    local bas = Vide(vgui.Create("DPanel", fenetre))
    bas:SetPos(10, HAUTEUR - 50)
    bas:SetSize(LARGEUR - 20, 38)
    local function BoutonBas(texte, cote, clic)
        local b = Bouton(bas, texte, clic)
        b:Dock(cote)
        b:SetWide(150)
        b:DockMargin(cote == LEFT and 0 or 6, 0, cote == LEFT and 6 or 0, 0)
        return b
    end
    local ok = BoutonBas("Enregistrer", RIGHT, function()
        net.Start("NA_Perso_Envoi")
        net.WriteString(P.Encoder(brouillon))
        net.SendToServer()
        Fermer()
    end)
    ok.EstActif = function() return true end
    BoutonBas("Annuler", RIGHT, Fermer)
    BoutonBas("Aléatoire", LEFT, function()
        Aleatoire()
        Poser(apercu, brouillon)
        Montrer(actuel)
    end)
    BoutonBas("Aspect d'origine", LEFT, function()
        brouillon = table.Copy(P.DEFAUT)
        Poser(apercu, brouillon)
        Montrer(actuel)
    end)
end

concommand.Add("perso", Ouvrir)
net.Receive("NA_Perso_Ouvrir", Ouvrir)
