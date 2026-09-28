--========================================================
-- Senju : Ermite naturel (CLIENT)
--
-- Lancement depuis la barre de techniques, et AFFICHAGE de l'aura + du tatouage sur chaque
-- joueur qui l'a (NW2Bool "NA_SenjuErmite", sv_senju_ermite.lua) : tout le monde les voit.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "ermite_naturel_pat"   -- particles/patlick_atgparticules.pcf (avec ses variantes _add, _add2)

-- true = marque affichée sur le visage. false = aucune marque (aura seule) : ni la vraie texture de
-- peau ni les marques flottantes n'ont donné un résultat satisfaisant, désactivées en attendant une
-- meilleure piste (voir le commentaire plus bas, "PISTE ABANDONNÉE").
local AFFICHER_MARQUE = false
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.senju_ermite = function()
    net.Start("senju_ermite_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)

local actives = {}   -- joueur -> système de particules

local function Porte(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_SenjuErmite", false)
        and not ply:IsDormant() and not ply:GetNWBool("IsInvisible", false)
end

local function Arreter(ply)
    local ps = actives[ply]
    if ps and ps:IsValid() then ps:StopEmission() end   -- les dernières particules finissent leur vie
    actives[ply] = nil
end

hook.Add("Think", "NA_SenjuErmite_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local ps = actives[ply]
        if Porte(ply) then
            if not (ps and ps:IsValid()) then
                -- centrée sur le corps (et non sur les pieds)
                actives[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ply:OBBMaxs().z * 0.45))
            end
        elseif ps then
            Arreter(ply)
        end
    end

    for ply in pairs(actives) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)

----------------------------------------------------------
-- Marques d'ermite sur le visage (yeux + front), texture atg/tatoo/ermite_naturel du workshop
-- 3676634351. 3 petits quads PLATS (front, œil gauche, œil droit), posés et orientés séparément sur
-- le visage à chaque image, collés à l'attache "eyes" de la tête. Actuellement désactivés
-- (AFFICHER_MARQUE = false, tout en haut).
----------------------------------------------------------
local MARQUE = Material("naruto_dev/marques/ermite_naturel_visible")
local COULEUR = Color(0, 0, 0)   -- marque noire (la texture d'origine est blanche, la couleur la teinte)
local FONDU = 1   -- secondes pour que la marque apparaisse

-- Réglages de PLACEMENT : modifiables en jeu avec le menu "na_marque_menu" (ci-dessous), qui affiche
-- un aperçu en direct sur toi. Une fois satisfait, le bouton "Copier les valeurs" du menu met le
-- nouveau bloc REGL dans le presse-papiers : colle-le ici pour que ce soit le réglage par défaut.
local REGL = {
    ECHELLE = 0.0048877118644068,
    HAUT = -1.65,
    PAD = 0,

    -- FRONT
    FRONT_AVANT = -3.98,
    FRONT_ANGLE = 0,
    FRONT_INCLINAISON = 24.92,
    FRONT_ROULIS = 0,
    FRONT_DECALAGE_X = 0,
    FRONT_DECALAGE_Y = 2.12,
    FRONT_COURBURE = 0,   -- 0 = plat (comme avant), plus grand = le morceau se bombe vers l'avant

    OEIL_GAUCHE = {
        AVANT = -2.8,
        ANGLE = -23.9,
        INCLINAISON = 20.85,
        ROULIS = -144.92,
        DECALAGE_X = 0.38,
        DECALAGE_Y = 2.97,
        DECALAGE_AVANT = 0,
        COURBURE = 0,
    },

    OEIL_DROIT = {
        AVANT = -2.8,
        ANGLE = 23,
        INCLINAISON = 20,
        ROULIS = 144,
        DECALAGE_X = -0.4,
        DECALAGE_Y = 2.97,
        DECALAGE_AVANT = 0,
        COURBURE = 0,
    },
}

-- Zone de chaque morceau dans la texture 2048x2048 (mesurée sur ermite_naturel.png) :
--   px = { xmin, xmax, ymin, ymax }, cle = quel sous-réglage de REGL utiliser (nil = front, pas de rotation)
local MORCEAUX = {
    { px = { 335,  833,  836, 1605 }, cle = "OEIL_GAUCHE" },
    { px = { 1189, 1720, 813,  1600 }, cle = "OEIL_DROIT" },
    { px = { 865,  1154, 90,   609 } },   -- front
}

-- Repère (pixel) sur lequel toutes les positions sont calées : le milieu des deux marques d'yeux
local REF_X, REF_Y = 1019, 1213

local debuts = {}   -- joueur -> moment où l'ermite est devenu actif (pour le fondu)
local apercu = false   -- true tant que le menu de réglage est ouvert : la marque s'affiche sur toi sans avoir à lancer la technique

-- Axe (avant, droite, haut, ou leur opposé) du repère "ang" le plus proche de la direction "cible"
-- Quel axe (avant, droite, haut, ou leur opposé) de "ang" pointe le plus vers "cible" : renvoie
-- l'INDICE (1/2/3 = Forward/Right/Up) et le SIGNE, pas le vecteur, pour pouvoir le réutiliser sur un
-- autre angle plus tard (voir Visage() : c'est CE couple indice+signe qui reste vrai à toute pose ;
-- le vecteur, lui, change à chaque image).
local NOMS_AXES = { "Forward", "Right", "Up" }
local function MeilleurAxe(ang, cible)
    local meilleurI, meilleurS, score = 1, 1, -2
    for i, nom in ipairs(NOMS_AXES) do
        local axe = ang[nom](ang)
        for _, signe in ipairs({ 1, -1 }) do
            local d = (axe * signe):Dot(cible)
            if d > score then meilleurI, meilleurS, score = i, signe, d end
        end
    end
    return meilleurI, meilleurS
end
local function AppliqueAxe(ang, i, s) return ang[NOMS_AXES[i]](ang) * s end

-- Centre des yeux, direction du visage et haut de la tête, d'après l'attache "eyes" de la tête.
-- Quel axe de l'attache correspond à "avant" / "haut" du visage ne dépend QUE du modèle (fixe), pas
-- de la pose du moment : on le détermine une seule fois (MeilleurAxe, avec le regard du joueur comme
-- repère de départ) puis on le RÉUTILISE sur l'angle actuel de l'attache à chaque image
-- (AppliqueAxe). Avant, on recalculait "le plus proche" à chaque image à partir du regard : ça
-- marchait à l'arrêt mais décrochait dès qu'une animation (attaque, geste...) bougeait la tête
-- autrement, puisque le regard du joueur ne reflète pas cette rotation-là.
local function Visage(ply)
    local tete = ply:GetNW2Entity("NA_TeteEnt")
    if not IsValid(tete) then return end
    local att = tete:LookupAttachment("eyes")
    if not att or att <= 0 then return end
    local a = tete:GetAttachment(att)
    if not a then return end

    if not tete.NA_AxeFace then
        tete.NA_AxeFace = { MeilleurAxe(a.Ang, Angle(0, ply:EyeAngles().y, 0):Forward()) }
        tete.NA_AxeHaut = { MeilleurAxe(a.Ang, Vector(0, 0, 1)) }
    end

    local face = AppliqueAxe(a.Ang, tete.NA_AxeFace[1], tete.NA_AxeFace[2])
    local haut = AppliqueAxe(a.Ang, tete.NA_AxeHaut[1], tete.NA_AxeHaut[2])
    return a.Pos, face, haut
end

-- Rotation de "v" autour de l'axe unitaire "axe", de "deg" degrés (formule de Rodrigues)
local function TourneAutourDe(v, axe, deg)
    if deg == 0 then return v end
    local rad = math.rad(deg)
    local c, sn = math.cos(rad), math.sin(rad)
    return v * c + axe:Cross(v) * sn + axe * axe:Dot(v) * (1 - c)
end

-- Grille courbée (au lieu d'un plan plat) : le morceau se bombe vers l'avant (axe "n") au centre,
-- et revient à 0 sur les bords, comme une vraie surface qui suit la courbure du visage plutôt
-- qu'une plaque plate. "courbure" = 0 -> parfaitement plat (comme avant), plus grand = plus bombé.
local SUBDIV = 6   -- N x N : plus grand = plus lisse, plus lourd
local function DessinerCourbe(centre, dr, up, n, moitieL, moitieH, u0, u1, v0, v1, courbure, r, g, b, alpha)
    local function Point(fi, fj)
        local lx, ly = (fi - 0.5) * 2 * moitieL, (fj - 0.5) * 2 * moitieH
        local nx, ny = math.abs(fi - 0.5) * 2, math.abs(fj - 0.5) * 2
        local profondeur = (1 - nx * nx) * courbure * 0.6 + (1 - ny * ny) * courbure * 0.4
        local pos = centre + dr * lx + up * ly + n * profondeur
        return pos, u0 + (u1 - u0) * fi, v0 + (v1 - v0) * fj
    end

    mesh.Begin(MATERIAL_TRIANGLES, (SUBDIV - 1) * (SUBDIV - 1) * 2)
    for j = 0, SUBDIV - 2 do
        for i = 0, SUBDIV - 2 do
            local fi0, fi1 = i / (SUBDIV - 1), (i + 1) / (SUBDIV - 1)
            local fj0, fj1 = j / (SUBDIV - 1), (j + 1) / (SUBDIV - 1)
            local p00, tu00, tv00 = Point(fi0, fj0)
            local p10, tu10, tv10 = Point(fi1, fj0)
            local p11, tu11, tv11 = Point(fi1, fj1)
            local p01, tu01, tv01 = Point(fi0, fj1)

            for _, pt in ipairs({ { p00, tu00, tv00 }, { p10, tu10, tv10 }, { p11, tu11, tv11 },
                                   { p00, tu00, tv00 }, { p11, tu11, tv11 }, { p01, tu01, tv01 } }) do
                mesh.Position(pt[1]) mesh.TexCoord(0, pt[2], pt[3]) mesh.Color(r, g, b, alpha) mesh.AdvanceVertex()
            end
        end
    end
    mesh.End()
end

local function DessinerMarque(ply, alphaForce)
    if not alphaForce and not Porte(ply) then debuts[ply] = nil return end
    debuts[ply] = debuts[ply] or CurTime()

    local pos, face, haut = Visage(ply)
    if not pos then return end
    local droite = face:Cross(haut)
    local origine = pos + haut * REGL.HAUT

    local alpha = alphaForce or 255 * math.Clamp((CurTime() - debuts[ply]) / FONDU, 0, 1)

    -- effacée seulement vue de bien derrière (0 = pile de profil, -1 = de dos) : reste visible
    -- jusque assez loin sur le côté, disparaît seulement près du plein profil / dos
    local vue = (EyePos() - origine):GetNormalized()
    alpha = math.floor(alpha * math.Clamp((face:Dot(vue) + 0.1) / 0.25, 0, 1))
    if alpha <= 0 then return end
    local r, g, b = COULEUR.r, COULEUR.g, COULEUR.b

    render.SetMaterial(MARQUE)
    for _, m in ipairs(MORCEAUX) do
        local xmin, xmax, ymin, ymax = m.px[1] - REGL.PAD, m.px[2] + REGL.PAD, m.px[3] - REGL.PAD, m.px[4] + REGL.PAD
        local cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2

        local avant, roulis, x, y, courbure
        local n = face
        if not m.cle then   -- front : ses propres réglages, tourné puis incliné comme les yeux
            avant = REGL.FRONT_AVANT
            roulis = REGL.FRONT_ROULIS
            courbure = REGL.FRONT_COURBURE
            x = (REF_X - cx) * REGL.ECHELLE + REGL.FRONT_DECALAGE_X
            y = (REF_Y - cy) * REGL.ECHELLE + REGL.FRONT_DECALAGE_Y

            n = TourneAutourDe(face, haut, REGL.FRONT_ANGLE)
            local dr0 = n:Cross(haut)
            n = TourneAutourDe(n, dr0, REGL.FRONT_INCLINAISON)
        else   -- œil : ses propres réglages (indépendants de l'autre œil), tourné puis incliné
            local o = REGL[m.cle]
            avant = o.AVANT + o.DECALAGE_AVANT
            roulis = o.ROULIS
            courbure = o.COURBURE
            x = (REF_X - cx) * REGL.ECHELLE + o.DECALAGE_X
            y = (REF_Y - cy) * REGL.ECHELLE + o.DECALAGE_Y

            n = TourneAutourDe(face, haut, o.ANGLE)
            local dr0 = n:Cross(haut)
            n = TourneAutourDe(n, dr0, o.INCLINAISON)
        end

        local centre = origine + droite * x + haut * y + n * avant

        local dr = n:Cross(haut)
        local up = dr:Cross(n)
        if roulis ~= 0 then
            dr = TourneAutourDe(dr, n, roulis)
            up = TourneAutourDe(up, n, roulis)
        end

        local moitieL, moitieH = (xmax - xmin) / 2 * REGL.ECHELLE, (ymax - ymin) / 2 * REGL.ECHELLE
        local u0, u1, v0, v1 = xmin / 2048, xmax / 2048, ymin / 2048, ymax / 2048

        DessinerCourbe(centre, dr, up, n, moitieL, moitieH, u0, u1, v0, v1, courbure, r, g, b, alpha)
    end
end

-- Dessinée APRÈS tous les objets opaques : le test de profondeur cache la marque derrière le
-- visage (pas ailleurs, grâce à $ignorez du matériau qui l'empêche d'être coupée par le relief).
hook.Add("PostDrawTranslucentRenderables", "NA_SenjuErmite_Marque", function(profondeur, ciel)
    if not AFFICHER_MARQUE or profondeur or ciel then return end
    for _, ply in ipairs(player.GetAll()) do
        if Porte(ply) or debuts[ply] then DessinerMarque(ply) end
    end
    -- aperçu forcé sur toi (menu de réglage ouvert) même sans la technique active
    if apercu and IsValid(LocalPlayer()) and not Porte(LocalPlayer()) then DessinerMarque(LocalPlayer(), 255) end
end)

----------------------------------------------------------
-- Caméra tournante autour du joueur, pendant que le menu de réglage est ouvert : le clic gauche
-- maintenu fait tourner la caméra autour du corps, la molette rapproche / éloigne. Ça permet de
-- voir la marque sous tous les angles sans avoir à bouger le personnage.
----------------------------------------------------------
local orbite = false
local orbYaw, orbPitch, orbDist = 0, 10, 90

hook.Add("CalcView", "NA_SenjuErmite_Orbite", function(ply, pos, ang, fov)
    if not orbite or not IsValid(ply) or ply ~= LocalPlayer() or not ply:Alive() then return end

    local tete = ply:EyePos()
    local dir = Angle(orbPitch, orbYaw, 0):Forward()
    local camPos = tete + dir * orbDist

    local tr = util.TraceHull({
        start = tete, endpos = camPos, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then camPos = tr.HitPos end

    local view = {}
    view.origin = camPos
    view.angles = (tete - camPos):Angle()
    view.fov = fov
    view.drawviewer = true
    return view
end)

----------------------------------------------------------
-- Menu de réglage (na_marque_menu) : panneau à droite de l'écran, même style que le menu de
-- personnalisation (cl_perso_menu.lua). Sections Front / Yeux / Commun, curseurs en direct,
-- copie du résultat.
----------------------------------------------------------
local LARGEUR_PANNEAU = 360

local C_FOND    = Color(28, 24, 22, 250)
local C_PANNEAU = Color(44, 38, 34)
local C_BOUTON  = Color(66, 56, 50)
local C_SURVOL  = Color(96, 80, 70)
local C_TEXTE   = Color(240, 230, 215)
local C_DOUX    = Color(170, 155, 140)
local C_SECTION = Color(200, 160, 90)

surface.CreateFont("NA.Marque.Titre", { font = "Roboto", size = 20, weight = 800 })
surface.CreateFont("NA.Marque.Texte", { font = "Roboto", size = 15, weight = 600 })
surface.CreateFont("NA.Marque.Section", { font = "Roboto", size = 15, weight = 800 })

-- { section, chemin, nom, min, max, deci } : chemin = "CLE" (REGL.CLE) ou { "GROUPE", "SOUS_CLE" } (REGL.GROUPE.SOUS_CLE)
local CHAMPS = {
    { "Commun", "ECHELLE",    "Taille",              0.0005, 0.01, 4 },
    { "Commun", "HAUT",       "Hauteur (repère commun)", -15, 15, 2 },
    { "Commun", "PAD",        "Marge de la texture", 0, 80, 0 },

    { "Front", "FRONT_AVANT",       "Avant / arrière",     -10, 10, 2 },
    { "Front", "FRONT_ANGLE",       "Angle (côté)",        -60, 60, 0 },
    { "Front", "FRONT_INCLINAISON", "Angle (haut/bas)",    -60, 60, 0 },
    { "Front", "FRONT_ROULIS",      "Roulis",              -180, 180, 0 },
    { "Front", "FRONT_DECALAGE_X",  "Déplacer (côté)",     -3, 3, 2 },
    { "Front", "FRONT_DECALAGE_Y",  "Déplacer (haut/bas)", -10, 10, 2 },
    { "Front", "FRONT_COURBURE",    "Courbure",            0, 3, 2 },
}

-- les 2 yeux ont les mêmes 7 réglages, chacun dans son propre groupe (OEIL_GAUCHE / OEIL_DROIT)
for _, oeil in ipairs({ { "Œil gauche", "OEIL_GAUCHE" }, { "Œil droit", "OEIL_DROIT" } }) do
    local section, groupe = oeil[1], oeil[2]
    local champs = {
        { "AVANT",          "Avant / arrière",     -10, 10, 2 },
        { "ANGLE",          "Angle (côté)",         -60, 60, 0 },
        { "INCLINAISON",    "Angle (haut/bas)", -60, 60, 0 },
        { "ROULIS",         "Roulis",               -180, 180, 0 },
        { "DECALAGE_X",     "Déplacer (côté)",      -3, 3, 2 },
        { "DECALAGE_Y",     "Déplacer (haut/bas)",  -10, 10, 2 },
        { "DECALAGE_AVANT", "Déplacer (avant/arrière)", -10, 10, 2 },
        { "COURBURE",       "Courbure",                  0, 3, 2 },
    }
    for _, c in ipairs(champs) do
        CHAMPS[#CHAMPS + 1] = { section, { groupe, c[1] }, c[2], c[3], c[4], c[5] }
    end
end

local function LireValeur(chemin)
    if istable(chemin) then return REGL[chemin[1]][chemin[2]] end
    return REGL[chemin]
end
local function EcrireValeur(chemin, v)
    if istable(chemin) then REGL[chemin[1]][chemin[2]] = v else REGL[chemin] = v end
end

local function CopierValeurs()
    local lignes = { "local REGL = {", "    ECHELLE = " .. tostring(REGL.ECHELLE) .. ",",
        "    HAUT = " .. tostring(math.Round(REGL.HAUT, 2)) .. ",", "    PAD = " .. tostring(math.Round(REGL.PAD, 0)) .. "," }
    lignes[#lignes + 1] = ""
    lignes[#lignes + 1] = "    -- FRONT"
    for _, cle in ipairs({ "FRONT_AVANT", "FRONT_ANGLE", "FRONT_INCLINAISON", "FRONT_ROULIS", "FRONT_DECALAGE_X", "FRONT_DECALAGE_Y", "FRONT_COURBURE" }) do
        lignes[#lignes + 1] = string.format("    %s = %s,", cle, tostring(math.Round(REGL[cle], 2)))
    end
    for _, groupe in ipairs({ "OEIL_GAUCHE", "OEIL_DROIT" }) do
        lignes[#lignes + 1] = ""
        lignes[#lignes + 1] = "    " .. groupe .. " = {"
        for _, sous in ipairs({ "AVANT", "ANGLE", "INCLINAISON", "ROULIS", "DECALAGE_X", "DECALAGE_Y", "DECALAGE_AVANT", "COURBURE" }) do
            lignes[#lignes + 1] = string.format("        %s = %s,", sous, tostring(math.Round(REGL[groupe][sous], 2)))
        end
        lignes[#lignes + 1] = "    },"
    end
    lignes[#lignes + 1] = "}"
    local texte = table.concat(lignes, "\n")
    SetClipboardText(texte)
    MsgC(Color(255, 200, 0), "[Marque] ", color_white, "valeurs copiées dans le presse-papiers (à coller dans cl_senju_ermite.lua) :\n")
    print(texte)
end

local function Bouton(parent, texte, clic)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    function b:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and C_SURVOL or C_BOUTON)
        draw.SimpleText(texte, "NA.Marque.Texte", w / 2, h / 2, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = clic
    return b
end

local function Fermer()
    if IsValid(NA_MarqueMenu) then NA_MarqueMenu:Remove() end
    if IsValid(NA_MarqueCapture) then NA_MarqueCapture:Remove() end
    apercu, orbite = false, false
end

local function Ouvrir()
    if IsValid(NA_MarqueMenu) then Fermer() return end
    apercu, orbite = true, true
    orbYaw, orbPitch, orbDist = IsValid(LocalPlayer()) and LocalPlayer():EyeAngles().y or 0, 10, 90

    -- capture plein écran (SOUS le panneau) : glisser tourne la caméra, la molette zoome
    local capture = vgui.Create("DPanel")
    capture:SetPos(0, 0)
    capture:SetSize(ScrW(), ScrH())
    capture:SetMouseInputEnabled(true)
    capture.Paint = function() end
    function capture:OnMousePressed(k)
        if k ~= MOUSE_LEFT then return end
        self.Glisse = true
        self.DepartX, self.DepartY = gui.MouseX(), gui.MouseY()
        self:MouseCapture(true)
    end
    function capture:OnMouseReleased()
        self.Glisse = false
        self:MouseCapture(false)
    end
    function capture:OnCursorMoved()
        if not self.Glisse then return end
        local x, y = gui.MouseX(), gui.MouseY()
        orbYaw = orbYaw - (x - self.DepartX) * 0.5
        orbPitch = math.Clamp(orbPitch - (y - self.DepartY) * 0.5, -80, 80)
        self.DepartX, self.DepartY = x, y
    end
    function capture:OnMouseWheeled(d) orbDist = math.Clamp(orbDist - d * 6, 20, 250) end
    NA_MarqueCapture = capture

    local hauteur = math.min(math.floor(ScrH() * 0.85), 720)
    local f = vgui.Create("DFrame")
    f:SetSize(LARGEUR_PANNEAU, hauteur)
    f:SetPos(ScrW() - LARGEUR_PANNEAU - 20, (ScrH() - hauteur) / 2)
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetDraggable(false)
    f:MakePopup()
    f.OnClose = function() if IsValid(NA_MarqueCapture) then NA_MarqueCapture:Remove() end apercu, orbite = false, false end
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, C_FOND)
        draw.SimpleText("Marque d'ermite", "NA.Marque.Titre", 16, 18, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("clic gauche + glisser = tourner, molette = zoomer", "NA.Marque.Texte", 16, 42, C_DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    NA_MarqueMenu = f

    local zone = vgui.Create("DScrollPanel", f)
    zone:SetPos(10, 62)
    zone:SetSize(LARGEUR_PANNEAU - 20, hauteur - 62 - 80)
    zone.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, C_PANNEAU) end
    local toile = zone:GetCanvas()
    toile:DockPadding(10, 6, 10, 6)

    local dernier = nil
    for _, c in ipairs(CHAMPS) do
        local section, chemin, nom, mini, maxi, deci = c[1], c[2], c[3], c[4], c[5], c[6]
        if section ~= dernier then
            dernier = section
            local titre = vgui.Create("DPanel", toile)
            titre:Dock(TOP)
            titre:SetTall(28)
            titre:DockMargin(0, section == "Commun" and 0 or 10, 0, 0)
            titre.Paint = function(_, w, h) draw.SimpleText(section, "NA.Marque.Section", 0, h - 4, C_SECTION, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM) end
        end

        local s = vgui.Create("DNumSlider", toile)
        s:Dock(TOP)
        s:SetTall(44)
        s:SetText(nom)
        s:SetDark(false)
        s:SetMin(mini)
        s:SetMax(maxi)
        s:SetDecimals(deci)
        s:SetValue(LireValeur(chemin))
        s.OnValueChanged = function(_, v) EcrireValeur(chemin, v) end
    end

    local copier = Bouton(f, "Copier les valeurs", CopierValeurs)
    copier:SetPos(10, hauteur - 76)
    copier:SetSize(LARGEUR_PANNEAU - 20, 30)

    local fermer = Bouton(f, "Fermer", Fermer)
    fermer:SetPos(10, hauteur - 40)
    fermer:SetSize(LARGEUR_PANNEAU - 20, 30)
end

concommand.Add("na_marque_menu", Ouvrir, nil, "Ouvre un panneau pour régler en direct la position de la marque d'ermite sur le visage.")

----------------------------------------------------------
-- Vraie texture de peau tatouée : PISTE ABANDONNÉE (pour l'instant).
--
-- Diagnostiqué : SetSubMaterial, RenderOverride (render.MaterialOverrideByIndex) et un SetNoDraw
-- posé une seule fois sont tous les trois sans effet sur "tete" (l'entité prop_dynamic créée par le
-- serveur, fusionnée au squelette). Un SetNoDraw(true) reposé à CHAQUE image, lui, marche (comme
-- cl_perso.lua le fait pour sa copie "recul" : quelque chose d'autre remet NoDraw à false à chaque
-- tick, un seul appel se fait donc toujours écraser) -- ce qui permet de cacher "tete" et de dessiner
-- à la place une copie ClientsideModel (SetSubMaterial y marche très bien, confirmé via
-- cl_playerskin.lua qui l'utilise déjà pour le corps après la mort), habillée comme l'originale
-- (NA_HabillerVisage) avec en plus son sous-matériau "face" mélangé à la texture de tatouage via
-- $detail ($detailblendmode "2", en supposant son UV alignée sur atg/face/face car même famille de
-- modèles "atg"). Essayé en branchant ça sur la copie que cl_perso.lua dessine déjà (recul ≠ 0) via
-- un hook NA_TeteCopiePrete -- mais rien ne s'affiche : soit le detail blend mode n'est pas supporté
-- par VertexLitGeneric sur un modèle (probablement réservé à LightmappedGeneric), soit l'UV n'est
-- pas alignée comme supposé. Non concluant, et cl_perso.lua a été remis à l'identique.
----------------------------------------------------------
