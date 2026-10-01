--========================================================
-- Bibliothèque : amélioration des techniques (CLIENT)
-- Ouvre avec F6, ou la commande console : bibliotheque
--
--   Gauche : onglets (Natures, Kekkei Genkai, Classes, Arts Ninja, Clans, Suivis)
--   Centre : les emblèmes de l'onglet, puis l'arbre des techniques de l'emblème
--   Clic sur une technique : fiche avec ses valeurs actuelles -> niveau suivant,
--   et le bouton "Améliorer" (points de compétence).
--
-- Les niveaux, les points et leurs effets sont dans autorun/_na_niveaux.lua.
-- Les techniques (nom, icône, description, recharge) viennent de la liste du
-- menu F2 (cl_techniques_ui.lua).
--========================================================

local OPEN_KEY = KEY_F6
local DOSSIER = "ui/main_menu/"
local LIB = DOSSIER .. "library/"

--========================================================
-- ONGLETS
--   groupes = emblèmes de l'onglet ; "nom" = catégorie (cat) de la liste des techniques F2.
--   Un emblème sans technique améliorable est grisé ("Bientôt").
--   suivis = true : les techniques équipées dans la barre.
--========================================================
local ONGLETS = {
    { nom = "Natures", icone = "jutsu.png", groupes = {
        { nom = "Katon",  embleme = LIB .. "nature/katon.png" },
        { nom = "Suiton", embleme = LIB .. "nature/suiton.png" },
        { nom = "Doton",  embleme = LIB .. "nature/doton.png" },
        { nom = "Futon",  embleme = LIB .. "nature/futon.png" },
        { nom = "Raiton", embleme = LIB .. "nature/raiton.png" },
    } },
    { nom = "Kekkei Genkai", icone = "kekei.png", groupes = {
        { nom = "Mokuton",  embleme = LIB .. "mokuton.png" },
        { nom = "Jinton",   embleme = LIB .. "jinton.png" },
        { nom = "Kiminari", embleme = LIB .. "kiminari.png" },
        { nom = "Bakuton",  embleme = LIB .. "bakuton.png" },
        { nom = "Hyoton",   embleme = LIB .. "hyoton.png" },
        { nom = "Yoton",    embleme = LIB .. "yoton.png" },
        { nom = "Shakuton", embleme = LIB .. "shakuton.png" },
        { nom = "Futton",   embleme = LIB .. "futton.png" },
        { nom = "Jiton",    embleme = LIB .. "jiton.png" },
        { nom = "Shoton",   embleme = LIB .. "shoton.png" },
        { nom = "Meiton",   embleme = LIB .. "meiton.png" },
        { nom = "Inkuton",  embleme = LIB .. "inkuton.png" },
    } },
    { nom = "Classes", icone = "classe.png", groupes = {
        { nom = "Combattant", embleme = LIB .. "classe/combattant.png" },
        { nom = "Éclaireur",  embleme = LIB .. "classe/eclaireur.png" },
        { nom = "Médecin",    embleme = LIB .. "classe/medecin.png" },
        { nom = "Rempart",    embleme = LIB .. "classe/rempart.png" },
    } },
    { nom = "Arts Ninja", icone = "kenTai.png", groupes = {} },
    { nom = "Clans", icone = "icon_clan.png", groupes = {
        { nom = "Salamandre" }, { nom = "Fuma" }, { nom = "Kami" }, { nom = "Kaguya" }, { nom = "Chinoike" }, { nom = "Hyuga" }, { nom = "Senju" }, { nom = "Uchiha" },
    } },
    { nom = "Suivis", icone = "sub.png", suivis = true },
}

----------------------------------------------------------
-- Apparence
----------------------------------------------------------
local FOND = LIB .. "bibli.png"
local FOND_W, FOND_H = 1672, 941
local SCENE = { 103, 104, 1569, 848 }   -- intérieur du cadre de bibli.png
local MARGE_G = 190                     -- place à gauche pour les plaques (px de fond)

local C_OR       = Color(232, 196, 120)
local C_CREME    = Color(240, 226, 196)
local C_DOUX     = Color(160, 145, 125)
local C_CHAKRA   = Color(90, 170, 255)
local C_RECHARGE = Color(185, 110, 255)
local C_DEGATS   = Color(255, 120, 90)

-- recréées seulement si la taille du menu change (CreateFont coûte cher)
local taillePolices
local function CreerPolices(f)
    f = math.max(f, 0.6)
    if taillePolices and math.abs(taillePolices - f) < 0.01 then return end
    taillePolices = f
    local function P(nom, taille, poids)
        surface.CreateFont(nom, { font = "Roboto", size = math.Round(taille * f), weight = poids, extended = true })
    end
    P("NA.Bib.Titre",   58, 800)
    P("NA.Bib.Points",  36, 800)
    P("NA.Bib.Onglet",  19, 900)
    P("NA.Bib.Embleme", 22, 800)
    P("NA.Bib.Nom",     22, 800)
    P("NA.Bib.Texte",   16, 600)
    P("NA.Bib.Petit",   14, 700)
    P("NA.Bib.Bouton",  20, 800)
end

local mats = {}
local function M(chemin)
    local m = mats[chemin]
    if not m then
        m = Material(chemin, "smooth mips")
        mats[chemin] = m
    end
    return m
end

local function Image(chemin, x, y, w, h, a, lum)
    lum = lum or 255
    surface.SetMaterial(M(chemin))
    surface.SetDrawColor(lum, lum, lum, a or 255)
    surface.DrawTexturedRect(x, y, w, h)
end

local function Disque(cx, cy, r)
    local pts = {}
    for i = 0, 31 do
        local a = math.rad(i / 32 * 360)
        pts[#pts + 1] = { x = cx + math.cos(a) * r, y = cy + math.sin(a) * r }
    end
    draw.NoTexture()
    surface.DrawPoly(pts)
end

local function Couper(texte, police, largeur)
    surface.SetFont(police)
    local lignes, ligne = {}, ""
    for mot in string.gmatch(texte or "", "%S+") do
        local essai = ligne == "" and mot or (ligne .. " " .. mot)
        if ligne ~= "" and surface.GetTextSize(essai) > largeur then
            lignes[#lignes + 1] = ligne
            ligne = mot
        else
            ligne = essai
        end
    end
    if ligne ~= "" then lignes[#lignes + 1] = ligne end
    return lignes
end

-- Trait épais entre deux points
local function Trait(x1, y1, x2, y2, ep)
    local dx, dy = x2 - x1, y2 - y1
    local l = math.sqrt(dx * dx + dy * dy)
    if l <= 0 then return end
    local nx, ny = -dy / l * ep / 2, dx / l * ep / 2
    draw.NoTexture()
    surface.DrawPoly({
        { x = x1 + nx, y = y1 + ny }, { x = x2 + nx, y = y2 + ny },
        { x = x2 - nx, y = y2 - ny }, { x = x1 - nx, y = y1 - ny },
    })
end

----------------------------------------------------------
-- Données des techniques
----------------------------------------------------------
local function Ameliorable(t)
    return t.id ~= nil and NA_NIV ~= nil and NA_NIV.Existe(t.id)
end

-- Techniques améliorables d'une catégorie de la liste F2
local function TechniquesDe(cat)
    local liste = {}
    for _, t in ipairs(NA_TechniquesListe or {}) do
        if t.cat == cat and Ameliorable(t) then liste[#liste + 1] = t end
    end
    return liste
end

-- Techniques équipées dans la barre
local function TechniquesSuivies()
    local liste = {}
    if not NA_SkillBar then return liste end
    for i = 1, NA_SkillBar.NB do
        local id = NA_SkillBar.Get(i)
        local t = id and NA_TechniqueParId and NA_TechniqueParId(id)
        if t and Ameliorable(t) then liste[#liste + 1] = t end
    end
    return liste
end

local function Chakra(t)
    return tonumber(string.match(t.desc or "", "Coûte (%d+) de chakra")) or 0
end

-- Lignes de stats de la fiche : { genre, nom, suffixe, base, couleur, pourcent }
--   * les stats réglées niveau par niveau (_na_niveaux_techniques.lua) ;
--   * chakra / recharge / dégâts non réglés : pourcentage général (PAR_NIVEAU).
local function StatsAffichees(tech)
    local couleurs = { degats = C_DEGATS, chakra = C_CHAKRA, recharge = C_RECHARGE }
    local cooldown = NA_CooldownBase and NA_CooldownBase(tech) or tech.cd
    local bases = { chakra = Chakra(tech), recharge = cooldown or 0 }
    local liste, vues = {}, {}

    local function Ajouter(genre, nom, suffixe, pourcent)
        if vues[genre] then return end
        vues[genre] = true
        liste[#liste + 1] = {
            genre = genre, nom = nom, suffixe = suffixe or "", pourcent = pourcent,
            base = bases[genre] or 0, couleur = couleurs[genre] or C_CREME,
        }
    end

    -- stats réglées pour cette technique, dans l'ordre de NA_NIV.NOMS puis les autres.
    -- Le niveau 1 liste TOUS les réglages (_na_niveaux_techniques.lua) : on n'affiche
    -- que les stats principales et celles qui changent à un niveau suivant.
    local PRINCIPALES = { degats = true, soin = true, poison = true, chakra = true, recharge = true,
        duree = true, bonus_degats = true, bonus_vitesse = true, reduction = true, vol_vie = true }
    local reglees = {}
    for n, niveau in pairs(NA_NIV_TECH and NA_NIV_TECH[tech.id] or {}) do
        for genre in pairs(niveau) do
            if n >= 2 or PRINCIPALES[genre] then reglees[genre] = true end
        end
    end
    for _, n in ipairs(NA_NIV.NOMS or {}) do
        if reglees[n[1]] then Ajouter(n[1], n[2], n[3]) end
    end
    local autres = {}
    for genre in pairs(reglees) do
        if not vues[genre] then autres[#autres + 1] = genre end
    end
    table.sort(autres)
    for _, genre in ipairs(autres) do Ajouter(genre, string.upper(genre), "") end

    -- valeurs générales pour ce qui n'est pas réglé
    if bases.chakra > 0 then Ajouter("chakra", "CHAKRA", "") end
    if cooldown then Ajouter("recharge", "COOLDOWN", " S") end
    Ajouter("degats", "DÉGÂTS", "", true)

    return liste
end

local function IconeDe(t)
    return t and t.id and NA_SkillBar and NA_SkillBar.Icone(t.id)
end

-- Emblème d'un groupe : son image, sinon l'icône de sa première technique
local function EmblemeDe(g)
    if g.embleme then return M(g.embleme) end
    return IconeDe(TechniquesDe(g.nom)[1])
end

-- Dessine une image dans le carré (x, y, cote) SANS la déformer : elle garde
-- ses proportions et est centrée (ex. katon.png et futon.png font 512x446).
-- $realwidth / $realheight = vraie taille d'un PNG (Width/Height peuvent être arrondis).
local function DessinerDansCarre(mat, x, y, cote)
    local iw, ih = mat:GetInt("$realwidth") or 0, mat:GetInt("$realheight") or 0
    if iw <= 0 or ih <= 0 then iw, ih = mat:Width(), mat:Height() end
    if iw <= 0 or ih <= 0 then iw, ih = 1, 1 end

    local w, h = cote, cote
    if iw > ih then h = cote * ih / iw else w = cote * iw / ih end
    surface.DrawTexturedRect(x + (cote - w) / 2, y + (cote - h) / 2, w, h)
end

local function Arrondi(v)
    if math.abs(v - math.Round(v)) < 0.05 then return tostring(math.Round(v)) end
    return string.format("%.1f", v)
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local frame
local ongletActif = 1
local groupeActif      -- groupe ouvert (nil = grille des emblèmes)
local choisie          -- technique dont la fiche est ouverte

if NA_EnregistrerMenu then
    NA_EnregistrerMenu("bibliotheque", function() if IsValid(frame) then frame:Remove() end end)
end

local function Ouvrir()
    if IsValid(frame) then frame:Remove() return end
    if NA_FermerAutresMenus then NA_FermerAutresMenus("bibliotheque") end   -- un seul menu à la fois

    groupeActif, choisie = nil, nil

    -- Taille : fond + marge des plaques à gauche, proportions gardées
    local totalW = FOND_W + MARGE_G
    local W = math.min(ScrW() * 0.94, ScrH() * 0.92 * totalW / FOND_H)
    local S = W / totalW
    local H = FOND_H * S
    CreerPolices(H / FOND_H)

    local fX = MARGE_G * S                                   -- bord gauche du fond
    local sX, sY = fX + SCENE[1] * S, SCENE[2] * S           -- intérieur du cadre
    local sW, sH = (SCENE[3] - SCENE[1]) * S, (SCENE[4] - SCENE[2]) * S

    frame = vgui.Create("DPanel")
    frame:SetSize(W, H)
    frame:Center()
    frame:MakePopup()
    -- le clavier reste au jeu (pour que F2 / F4 changent de menu), mais le joueur
    -- est immobilisé tant que la bibliothèque est ouverte (hook CreateMove plus bas)
    frame:SetKeyboardInputEnabled(false)
    frame.Paint = function(pan, w, h)
        Image(FOND, fX, 0, FOND_W * S, h)
    end
    -- Échap ferme le menu (sans ouvrir le menu du jeu)
    frame.Think = function(pan)
        if input.IsKeyDown(KEY_ESCAPE) then
            pan:Remove()
            gui.HideGameUI()
        end
    end

    -- Croix de fermeture sur le bandeau supérieur, à gauche de la lanterne.
    local fermer = vgui.Create("DButton", frame)
    fermer:SetText("")
    fermer:SetSize(68 * S, 68 * S)
    fermer:SetPos(sX + sW - 10 * S, 44 * S)
    fermer:SetTooltip("Fermer")
    fermer.Paint = function(pan, w, h)
        local m = pan:IsHovered() and 0 or 3 * S
        Image(DOSSIER .. "btn_base_close.png", m, m, w - m * 2, h - m * 2)
    end
    fermer.DoClick = function()
        surface.PlaySound("ui/buttonclick.wav")
        frame:Remove()
    end

    ------------------------------------------------------
    -- Scène : emblèmes ou arbre des techniques
    ------------------------------------------------------
    local scene = vgui.Create("DPanel", frame)
    scene:SetPos(sX, sY)
    scene:SetSize(sW, sH)
    scene.Paint = function() end
    fermer:MoveToFront()

    local Construire

    local function Titre(pan, texte)
        local w = pan:GetWide()
        draw.SimpleTextOutlined(string.upper(texte), "NA.Bib.Titre", w / 2, sH * 0.12, C_CREME,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
        draw.SimpleTextOutlined(NA_Points(LocalPlayer()) .. " POINTS DE COMPÉTENCE", "NA.Bib.Points", w / 2, sH * 0.2,
            C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 200))
    end

    -- Grille des emblèmes de l'onglet
    local function VueEmblemes()
        local o = ONGLETS[ongletActif]
        scene.Paint = function(pan, w, h)
            Titre(pan, o.nom)
            if #o.groupes == 0 then
                draw.SimpleTextOutlined("BIENTÔT DISPONIBLE", "NA.Bib.Nom", w / 2, h * 0.55, C_DOUX,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
            end
        end

        local n = #o.groupes
        if n == 0 then return end
        local parLigne = math.min(n, 5)
        local lignes = math.ceil(n / parLigne)
        local t = math.min(sW * 0.14, sH * (lignes > 1 and 0.24 or 0.34))
        local ecart = t * 0.35
        local hauteurLigne = t + 40 * S
        local y0 = sH * 0.3 + (sH * 0.62 - lignes * hauteurLigne) / 2

        for i, g in ipairs(o.groupes) do
            local ligne = math.floor((i - 1) / parLigne)
            local dansLigne = math.min(parLigne, n - ligne * parLigne)
            local col = (i - 1) % parLigne
            local x = sW / 2 - (dansLigne * t + (dansLigne - 1) * ecart) / 2 + col * (t + ecart)
            local y = y0 + ligne * hauteurLigne

            local techs = TechniquesDe(g.nom)
            local actif = #techs > 0

            local b = vgui.Create("DButton", scene)
            b:SetText("")
            b:SetPos(x, y)
            b:SetSize(t, t + 34 * S)
            b.Paint = function(pan, w, h)
                local sur = actif and pan:IsHovered()
                local mat = EmblemeDe(g)
                local m = sur and 0 or w * 0.04
                if mat then
                    surface.SetMaterial(mat)
                    local lum = actif and 255 or 80
                    surface.SetDrawColor(lum, lum, lum, 255)
                    DessinerDansCarre(mat, m, m, w - m * 2)
                end
                draw.SimpleTextOutlined(string.upper(g.nom), "NA.Bib.Embleme", w / 2, w + 14 * S,
                    actif and (sur and C_OR or C_CREME) or C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
                if not actif then
                    draw.SimpleTextOutlined("BIENTÔT", "NA.Bib.Petit", w / 2, w / 2, C_DOUX,
                        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
                end
            end
            if actif then
                b.DoClick = function()
                    surface.PlaySound("ui/buttonclick.wav")
                    groupeActif = g
                    choisie = nil
                    Construire()
                end
            else
                b:SetTooltip("Bientôt disponible")
            end
        end
    end

    -- Arbre des techniques d'un groupe (ou des techniques suivies)
    local function VueArbre(titre, techs, retour)
        scene.Paint = function(pan, w, h) Titre(pan, titre) end

        if retour then
            local r = vgui.Create("DButton", scene)
            r:SetText("")
            r:SetSize(150 * S, 40 * S)
            r:SetPos(24 * S, 20 * S)
            r.Paint = function(pan, w, h)
                draw.RoundedBox(6, 0, 0, w, h, pan:IsHovered() and Color(60, 30, 25, 230) or Color(20, 12, 12, 200))
                surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, 150)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText("‹  RETOUR", "NA.Bib.Petit", w / 2, h / 2, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            r.DoClick = function()
                surface.PlaySound("ui/buttonclick.wav")
                groupeActif, choisie = nil, nil
                Construire()
            end
        end

        if #techs == 0 then
            scene.Paint = function(pan, w, h)
                Titre(pan, titre)
                draw.SimpleTextOutlined("AUCUNE TECHNIQUE ÉQUIPÉE", "NA.Bib.Nom", w / 2, h * 0.55, C_DOUX,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
            end
            return
        end

        -- positions : chaîne en zigzag centrée dans la scène
        local t = math.min(sW * 0.075, sH * 0.13)
        local pas = math.min(t * 1.9, (sW * 0.86) / math.max(#techs - 1, 1))
        local cy = sH * 0.58
        local pos = {}
        for i = 1, #techs do
            local x = sW / 2 + (i - (#techs + 1) / 2) * pas
            local y = cy + ((i % 2 == 0) and t * 0.75 or -t * 0.75)
            pos[i] = { x = x, y = y }
        end

        -- liens entre les techniques (dessinés sous les boutons)
        local liens = vgui.Create("DPanel", scene)
        liens:SetPos(0, 0)
        liens:SetSize(sW, sH)
        liens:SetMouseInputEnabled(false)
        -- petit trait fin qui s'arrête avant les cercles ; allumé si la technique
        -- suivante est débloquée, sinon grisé
        local ecart = t / 2 + 8 * S   -- rayon du cercle + espace
        liens.Paint = function()
            for i = 1, #pos - 1 do
                local a, b = pos[i], pos[i + 1]
                local dx, dy = b.x - a.x, b.y - a.y
                local l = math.sqrt(dx * dx + dy * dy)
                if l > ecart * 2 then
                    local ux, uy = dx / l, dy / l
                    if NA_Niveau(LocalPlayer(), techs[i + 1].id) > 0 then
                        surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, 200)
                    else
                        surface.SetDrawColor(C_DOUX.r, C_DOUX.g, C_DOUX.b, 110)
                    end
                    Trait(a.x + ux * ecart, a.y + uy * ecart, b.x - ux * ecart, b.y - uy * ecart, 1.5 * S)
                end
            end
        end

        local fiche -- fiche de la technique choisie

        -- clic en dehors de la fiche (et hors d'une technique) : elle se ferme
        local function FermerFiche()
            if not IsValid(fiche) then return end
            fiche:Remove()
            choisie = nil
            surface.PlaySound("ui/buttonclick.wav")
        end
        scene.OnMousePressed = function(_, code) if code == MOUSE_LEFT then FermerFiche() end end
        frame.OnMousePressed = scene.OnMousePressed

        local function OuvrirFiche(i)
            if IsValid(fiche) then fiche:Remove() end
            local tech = techs[i]
            choisie = tech

            local stats = StatsAffichees(tech)
            -- la fiche s'allonge quand la technique a plus de 3 stats
            surface.SetFont("NA.Bib.Texte")
            local _, hLigne = surface.GetTextSize("A")
            local fw, fh = 340 * S, 440 * S + math.max(0, #stats - 3) * (hLigne + 2)
            local fx = pos[i].x + t * 0.7
            if fx + fw > sW - 10 then fx = pos[i].x - t * 0.7 - fw end
            local fy = math.Clamp(pos[i].y - fh / 2, sH * 0.26, sH - fh - 10)

            fiche = vgui.Create("DPanel", scene)
            fiche:SetPos(fx, fy)
            fiche:SetSize(fw, fh)

            local pad = 16 * S
            local descLignes = Couper(string.upper(tech.desc or ""), "NA.Bib.Texte", fw - pad * 2)

            fiche.Paint = function(pan, w, h)
                draw.RoundedBox(8, 0, 0, w, h, Color(14, 10, 12, 235))
                surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, 120)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                local niv = NA_Niveau(LocalPlayer(), tech.id)
                local max = niv >= NA_NIV.MAX
                local verrou = niv == 0
                local sansSuite = max or verrou   -- pas de "actuel -> suivant"
                local suivant = math.min(niv + 1, NA_NIV.MAX)

                local y = pad
                draw.SimpleText(string.upper(tech.name), "NA.Bib.Nom", pad, y, C_CREME)
                draw.SimpleText(verrou and "VERROUILLÉE" or ("NIV. " .. niv), "NA.Bib.Petit", w - pad, y + 4 * S,
                    verrou and C_DEGATS or C_OR, TEXT_ALIGN_RIGHT)
                y = y + 34 * S


                draw.SimpleText("DESCRIPTION :", "NA.Bib.Petit", pad, y, C_DOUX)
                y = y + 20 * S
                surface.SetFont("NA.Bib.Texte")
                local _, hl = surface.GetTextSize("A")
                for k, l in ipairs(descLignes) do
                    if k > 6 then break end   -- description tronquée si très longue
                    draw.SimpleText(l, "NA.Bib.Texte", pad, y, C_CREME)
                    y = y + hl
                end
                y = y + 10 * S

                draw.SimpleText("STATISTIQUES :", "NA.Bib.Petit", pad, y, C_DOUX)
                y = y + 20 * S

                -- valeur actuelle -> valeur au niveau suivant
                for _, s in ipairs(stats) do
                    local txt
                    if s.pourcent then
                        -- dégâts sans réglage par niveau : en pourcentage (base dans la description)
                        local function P(n) return math.Round((NA_NIV.Multiplicateur(s.genre, n) - 1) * 100) end
                        txt = s.nom .. " : +" .. P(niv) .. " %"
                        if not sansSuite then txt = txt .. "  ->  +" .. P(suivant) .. " %" end
                    else
                        local a = NA_NIV.Valeur(tech.id, s.genre, niv, s.base)
                        txt = s.nom .. " : " .. Arrondi(a) .. s.suffixe
                        if not sansSuite then
                            local b = NA_NIV.Valeur(tech.id, s.genre, suivant, s.base)
                            txt = txt .. "  ->  " .. Arrondi(b) .. s.suffixe
                        end
                    end
                    draw.SimpleText(txt, "NA.Bib.Texte", pad, y, s.couleur)
                    y = y + hl + 2
                end

                -- niveaux 1 à 5
                local c = 26 * S
                local e = 10 * S
                local total = NA_NIV.MAX * c + (NA_NIV.MAX - 1) * e
                local nx = w / 2 - total / 2
                local ny = h - 100 * S
                for k = 1, NA_NIV.MAX do
                    local x = nx + (k - 1) * (c + e)
                    local atteint = k <= niv
                    draw.RoundedBox(5, x, ny, c, c, atteint and C_CREME or Color(60, 55, 55, 230))
                    draw.SimpleText(k, "NA.Bib.Petit", x + c / 2, ny + c / 2,
                        atteint and Color(30, 20, 20) or C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            -- bouton Améliorer
            local b = vgui.Create("DButton", fiche)
            b:SetText("")
            b:SetSize(fw - pad * 2, 44 * S)
            b:SetPos(pad, fh - pad - b:GetTall())
            -- technique d'avant à débloquer d'abord (nil = rien ne bloque)
            local function Manque()
                if NA_Niveau(LocalPlayer(), tech.id) > 0 then return nil end
                local ok, prec = NA_NIV.DeblocagePossible(LocalPlayer(), tech.id)
                if ok then return nil end
                local t = NA_TechniqueParId and NA_TechniqueParId(prec)
                return t and t.name or prec
            end

            b.Paint = function(pan, w, h)
                local niv = NA_Niveau(LocalPlayer(), tech.id)
                local cout = NA_NIV.Cout(niv)
                local manque = Manque()
                local possible = cout and not manque and NA_Points(LocalPlayer()) >= cout
                local lum = (possible and pan:IsHovered()) and 255 or (possible and 225 or 120)
                Image(DOSSIER .. "btn_base_long.png", 0, 0, w, h, 255, lum)

                local txt, col
                if not cout then
                    txt, col = "NIVEAU MAX", Color(60, 45, 30)
                elseif manque then
                    txt, col = "DÉBLOQUE D'ABORD : " .. string.upper(manque), Color(60, 45, 30)
                elseif possible then
                    txt, col = (niv == 0 and "DÉBLOQUER : " or "AMÉLIORER : ") .. cout, Color(30, 20, 20)
                else
                    txt, col = (niv == 0 and "DÉBLOQUER : " or "AMÉLIORER : ") .. cout .. " (POINTS INSUFFISANTS)", Color(150, 40, 35)
                end
                draw.SimpleText(txt, cout and possible and "NA.Bib.Bouton" or "NA.Bib.Petit", w / 2, h / 2, col,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                local niv = NA_Niveau(LocalPlayer(), tech.id)
                local cout = NA_NIV.Cout(niv)
                if not cout or Manque() or NA_Points(LocalPlayer()) < cout then
                    surface.PlaySound("buttons/button10.wav")
                    return
                end
                net.Start("NA_Ameliorer")
                    net.WriteString(tech.id)
                net.SendToServer()
                surface.PlaySound("ui/buttonclick.wav")
            end
        end

        for i, tech in ipairs(techs) do
            local nb = vgui.Create("DButton", scene)
            nb:SetText("")
            nb:SetSize(t, t + 18 * S)
            nb:SetPos(pos[i].x - t / 2, pos[i].y - t / 2)
            nb:SetTooltip(tech.name)

            nb.Paint = function(pan, w, h)
                local sel = choisie == tech
                local sur = pan:IsHovered()
                local cx, cy = w / 2, t / 2

                -- halo
                if sel or sur then
                    surface.SetDrawColor(C_OR.r, C_OR.g, C_OR.b, sel and 200 or 110)
                    Disque(cx, cy, t / 2 + 4 * S)
                end
                surface.SetDrawColor(10, 8, 8, 255)
                Disque(cx, cy, t / 2)

                -- verrouillée : icône assombrie
                local lumN = NA_Niveau(LocalPlayer(), tech.id) == 0 and 80 or 255
                local icone = IconeDe(tech)
                local ti = t * 0.94
                if icone then
                    surface.SetMaterial(icone)
                    surface.SetDrawColor(lumN, lumN, lumN, 255)
                    surface.DrawTexturedRect(cx - ti / 2, cy - ti / 2, ti, ti)
                else
                    draw.SimpleText(tech.court or tech.name, "NA.Bib.Petit", cx, cy, C_CREME, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                -- rang (C, B, A, S) en bas à droite de l'icône
                if NA_DessinerRang then
                    local haut = t * 0.4
                    NA_DessinerRang(tech, cx + t / 2, t - haut, haut, 1)
                end

                -- niveau : 5 points sous l'icône
                local niv = NA_Niveau(LocalPlayer(), tech.id)
                local r = 4 * S
                local e = 11 * S
                local x0 = cx - (NA_NIV.MAX - 1) * e / 2
                for k = 1, NA_NIV.MAX do
                    surface.SetDrawColor(k <= niv and C_OR or Color(70, 60, 55, 230))
                    Disque(x0 + (k - 1) * e, t + 10 * S, r)
                end
            end
            nb.DoClick = function()
                surface.PlaySound("ui/buttonclick.wav")
                OuvrirFiche(i)
            end

            if choisie == tech then OuvrirFiche(i) end
        end
    end

    Construire = function()
        scene:Clear()
        scene.OnMousePressed, frame.OnMousePressed = nil, nil
        local o = ONGLETS[ongletActif]
        if o.suivis then
            VueArbre(o.nom, TechniquesSuivies(), false)
        elseif groupeActif then
            VueArbre(groupeActif.nom, TechniquesDe(groupeActif.nom), true)
        else
            VueEmblemes()
        end
    end

    ------------------------------------------------------
    -- Plaques des onglets, à cheval sur le bord gauche du cadre
    ------------------------------------------------------
    -- grandes plaques, bien espacées ; le losange déborde de la plaque
    local bW = 300 * S
    local bH = bW * 76 / 258
    local marge = 14 * S                      -- place pour l'ombre et le décalage au survol
    local pas = math.min(bH * 1.22, (sH * 0.9 - bH) / (#ONGLETS - 1))
    local y0 = sY + sH * 0.05

    for i, o in ipairs(ONGLETS) do
        local b = vgui.Create("DButton", frame)
        b:SetText("")
        b:SetPos(0, y0 + (i - 1) * pas - marge / 2)
        b:SetSize(bW + marge * 2, bH + marge)
        b.Decalage = 0
        b.Paint = function(pan, w, h)
            local choisi = ongletActif == i
            local sur = pan:IsHovered()

            -- l'onglet choisi ou survolé glisse un peu vers la droite
            local cible = (choisi and marge or 0) + (sur and marge * 0.5 or 0)
            pan.Decalage = Lerp(FrameTime() * 12, pan.Decalage, cible)
            local x, y = 4 * S + pan.Decalage, marge / 2

            -- ombre portée : détache la plaque du cadre sombre
            Image(DOSSIER .. "btn_base_refont.png", x + 4 * S, y + 5 * S, bW, bH, 170, 0)

            local plaque = (choisi or sur) and "btn_base_refont_hover.png" or "btn_base_refont.png"
            Image(DOSSIER .. plaque, x, y, bW, bH)

            local t = bH * 1.25
            Image(DOSSIER .. o.icone, x + bH / 2 - t / 2, y + bH / 2 - t / 2, t, t)

            -- texte : gros, contouré pour rester lisible sur la plaque
            local tx = x + bH + (bW * 0.8 - bH) / 2
            if choisi then
                draw.SimpleTextOutlined(string.upper(o.nom), "NA.Bib.Onglet", tx, y + bH / 2,
                    Color(70, 30, 15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(255, 235, 170, 120))
            else
                draw.SimpleTextOutlined(string.upper(o.nom), "NA.Bib.Onglet", tx, y + bH / 2,
                    sur and C_OR or Color(255, 245, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(20, 10, 5, 230))
            end
        end
        b.DoClick = function()
            if ongletActif == i and not groupeActif then return end
            surface.PlaySound("ui/buttonclick.wav")
            ongletActif = i
            groupeActif, choisie = nil, nil
            Construire()
        end
    end

    Construire()
end

----------------------------------------------------------
-- Préchargement : les emblèmes et le fond sont de grandes images ; on les
-- charge une par une après l'arrivée en jeu, pour que la première ouverture
-- du menu ne fige pas le jeu.
----------------------------------------------------------
hook.Add("InitPostEntity", "NA_Bibliotheque_Precharger", function()
    local liste = { FOND, DOSSIER .. "btn_base_long.png", DOSSIER .. "btn_base_close.png",
        DOSSIER .. "btn_base_refont.png", DOSSIER .. "btn_base_refont_hover.png" }
    for _, o in ipairs(ONGLETS) do
        liste[#liste + 1] = DOSSIER .. o.icone
        for _, g in ipairs(o.groupes or {}) do
            if g.embleme then liste[#liste + 1] = g.embleme end
        end
    end

    local i = 0
    timer.Create("NA_Bibliotheque_Precharger", 0.25, #liste, function()
        i = i + 1
        M(liste[i])
    end)
end)

-- Bibliothèque ouverte : le joueur ne bouge pas (ni déplacement, ni saut, ni attaque)
hook.Add("CreateMove", "NA_Bibliotheque_Immobile", function(cmd)
    if not IsValid(frame) then return end
    cmd:ClearMovement()
    cmd:ClearButtons()
end)

concommand.Add("bibliotheque", Ouvrir)

----------------------------------------------------------
-- Touche d'ouverture (F6)
----------------------------------------------------------
local avant = false
hook.Add("Think", "NA_Bibliotheque_Touche", function()
    if (vgui.GetKeyboardFocus() and not IsValid(frame)) or gui.IsGameUIVisible() then
        avant = false
        return
    end
    local bas = input.IsKeyDown(OPEN_KEY)
    if bas and not avant then
        local ply = LocalPlayer()
        if not (IsValid(ply) and ply:IsTyping()) then Ouvrir() end
    end
    avant = bas
end)
