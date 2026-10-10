--========================================================
-- Barre de techniques (CLIENT)
--
-- 6 emplacements en bas de l'écran : les touches 1 à 6 SÉLECTIONNENT la
-- technique, le clic droit la lance.
-- On y équipe les techniques depuis le menu F2 (cl_techniques_ui.lua).
-- L'équipement est enregistré dans garrysmod/data/naruto_skillbar.txt.
--
-- Le lancement passe par NA_Lancer(id) (autorun/_na_registre.lua) : c'est
-- exactement la même fonction que la touche d'origine de la technique, et le
-- serveur vérifie toujours tout (recharge, chakra...).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local NB_EMPLACEMENTS = 6
local NB_BARRES       = 2
local TOUCHE_BARRE    = KEY_M  -- change de barre
local TAILLE_BASE      = 86     -- taille d'un emplacement (px à 1080p, mise à l'échelle selon l'écran)
local ECART_BASE      = 14     -- espace entre deux emplacements
local MARGE_BAS_BASE  = 18     -- distance depuis le bas de l'écran
local GAUCHE_MIN_BASE = 640    -- bord gauche libre à droite du HUD de vie (texte des barres compris), px à 1080p
local TAILLE, ECART, MARGE_BAS = TAILLE_BASE, ECART_BASE, MARGE_BAS_BASE
local FICHIER         = "naruto_skillbar.txt"

-- Taille de l'icône par rapport au cadre. Mesuré dans les images :
--   case_skills.png : disque sombre jusqu'à 38,8 % du cadre, anneau doré de 40,6 à 41,9 %
--   icônes (90x90)  : le cercle occupe 98 % de l'image
-- 0.83 -> le bord de l'icône arrive pile contre l'anneau doré (plus de liseré sombre).
-- Plus grand : l'icône mord sur l'anneau ; plus petit : le fond sombre réapparaît.
local ICONE_RATIO     = 0.83

-- Équipement par défaut (premier lancement)
local PAR_DEFAUT = { "kami_circle", "kami_shuriken", "kami_bouclier", "kami_ailes", "katon_boule", "salamandre_poison" }
--========================================================

local MAT_CASE = Material("ui/hud/fight/case_skills.png", "smooth mips")
local MAT_BIND = Material("ui/hud/fight/case_bind.png", "smooth mips")
local MAT_DECK = Material("ui/hud/fight/deck_skills_rework.png", "smooth mips")   -- losange 52 x 42 : indique la barre active (1 ou 2)
local DECK_L, DECK_H = 52, 42
-- Centre du losange dans l'image (mesuré pixel par pixel : x = 26 / 52, y = 20,5 / 42) et correction du chiffre (px à l'écran,
-- positif = vers la droite / le bas) : à ajuster si le numéro n'est pas pile au milieu.
local DECK_CX, DECK_CY = 26 / 52, 20.5 / 42
local DECK_NUM_DX, DECK_NUM_DY = 0, 0

-- Tout est proportionnel à la hauteur de l'écran (référence 1080p) ; polices refaites si la résolution change
local function MettreALEchelle()
    local k = math.Clamp(ScrH() / 1080, 0.5, 2.5)
    TAILLE, ECART, MARGE_BAS = math.Round(TAILLE_BASE * k), math.Round(ECART_BASE * k), math.Round(MARGE_BAS_BASE * k)
    surface.CreateFont("NA.Skill.Nom",   { font = "Roboto", size = math.Round(TAILLE * 0.2), weight = 700 })
    surface.CreateFont("NA.Skill.Touche", { font = "Roboto", size = math.Round(TAILLE * 0.2), weight = 800 })
    surface.CreateFont("NA.Skill.Vide",  { font = "Roboto", size = math.Round(TAILLE * 0.36), weight = 500 })
    surface.CreateFont("NA.Skill.Deck", { font = "Roboto", size = math.Round(TAILLE * 0.3), weight = 800 })
    surface.CreateFont("NA.Skill.CD",    { font = "Roboto", size = math.Round(TAILLE * 0.3), weight = 800 })
end
MettreALEchelle()
hook.Add("OnScreenSizeChanged", "NA_SkillBar_Echelle", MettreALEchelle)

-- Couleur par famille de technique
local COULEURS = {
    Katon      = Color(255, 110, 40),
    Suiton     = Color(60, 150, 255),
    Futon      = Color(150, 230, 210),
    Raiton     = Color(120, 170, 255),
    Doton      = Color(190, 140, 80),
    Mokuton    = Color(120, 200, 90),
    Salamandre = Color(150, 220, 60),
    Fuma       = Color(180, 180, 200),
    Kami       = Color(235, 235, 245),
}
local COULEUR_DEFAUT = Color(255, 128, 32)

NA_SkillBar = NA_SkillBar or {}
local Bar = NA_SkillBar

Bar.Barres = Bar.Barres or {}
Bar.Active = Bar.Active or 1
Bar.Slots = Bar.Slots or {}   -- = la barre active (Bar.Barres[Bar.Active])
Bar.NB = NB_EMPLACEMENTS

----------------------------------------------------------
-- Infos d'une technique (liste du menu F2, cl_techniques_ui.lua)
----------------------------------------------------------
function Bar.Info(id)
    if not id then return nil end
    if NA_TechniqueParId then return NA_TechniqueParId(id) end
    return nil
end

function Bar.Couleur(id)
    local info = Bar.Info(id)
    return info and COULEURS[info.cat] or COULEUR_DEFAUT
end

-- Icône de la technique (champ "icone" de la liste, chemin relatif à materials/).
-- Mise en cache ; renvoie nil si pas d'icône ou si l'image est introuvable.
local cacheIcones = {}
function Bar.Icone(id)
    local info = Bar.Info(id)
    local chemin = info and info.icone
    if not chemin or chemin == "" then return nil end

    local mat = cacheIcones[chemin]
    if mat == nil then
        mat = Material(chemin, "smooth mips")
        if mat:IsError() then
            MsgC(Color(255, 170, 60), "[Techniques] icône introuvable : materials/" .. chemin .. "\n")
            mat = false
        end
        cacheIcones[chemin] = mat
    end
    return mat or nil
end

-- Nom court affiché dans l'emplacement
function Bar.NomCourt(id)
    local info = Bar.Info(id)
    if not info then return id end
    if info.court then return info.court end
    return info.name
end

----------------------------------------------------------
-- Équipement + sauvegarde
----------------------------------------------------------
local function Sauver()
    file.Write(FICHIER, util.TableToJSON({ barres = Bar.Barres }))
end

local function Charger()
    local brut = file.Read(FICHIER, "DATA")
    local data = brut and util.JSONToTable(brut)

    -- ancien format : tableau plat = barre 1 seulement
    local src = data and (data.barres or { data }) or { PAR_DEFAUT }
    Bar.Barres = {}
    for b = 1, NB_BARRES do
        Bar.Barres[b] = {}
        for i = 1, NB_EMPLACEMENTS do
            local v = src[b] and (src[b][i] or src[b][tostring(i)])
            if v == false or v == "" then v = nil end
            Bar.Barres[b][i] = v
        end
    end
    Bar.Slots = Bar.Barres[Bar.Active]
end

function Bar.Equiper(slot, id)
    if slot < 1 or slot > NB_EMPLACEMENTS then return end
    if id and not NA_Cast[id] then return end
    if id and NA_Debloquee and not NA_Debloquee(LocalPlayer(), id) then
        notification.AddLegacy("Technique verrouillée : débloque-la dans la bibliothèque (F6).", NOTIFY_ERROR, 3)
        return
    end

    -- une technique n'occupe qu'un seul emplacement PAR BARRE (elle peut être dans les deux)
    if id then
        for i = 1, NB_EMPLACEMENTS do
            if Bar.Slots[i] == id then Bar.Slots[i] = nil end
        end
    end

    Bar.Slots[slot] = id
    Sauver()
end

function Bar.Vider(slot)
    Bar.Equiper(slot, nil)
end

function Bar.Get(slot)
    return Bar.Slots[slot]
end

Charger()

----------------------------------------------------------
-- Sélection (touches 1 à 6) puis lancement (clic droit)
-- On passe par les commandes "slot1"..."slot6" déjà liées à 1..6 :
-- un emplacement occupé est SÉLECTIONNÉ (et bloque le changement d'arme),
-- un emplacement vide laisse la touche faire son travail habituel.
-- Rappuyer sur la touche de la technique sélectionnée la désélectionne :
-- le clic droit redevient celui de l'arme.
----------------------------------------------------------
Bar.Selection = Bar.Selection or nil

local DELAI_BARRE = 0.2   -- secondes minimum entre deux changements de barre
local dernierChange = 0

function Bar.Changer()
    if CurTime() - dernierChange < DELAI_BARRE then return end
    dernierChange = CurTime()
    Bar.Active = Bar.Active % NB_BARRES + 1
    Bar.Slots = Bar.Barres[Bar.Active]
    Bar.Selection = nil
end

-- M : passe à l'autre barre
local mDown = false
hook.Add("Think", "NA_SkillBar_Change", function()
    local d = (NA_ToucheBas and NA_ToucheBas("barre") or input.IsKeyDown(TOUCHE_BARRE)) and not vgui.GetKeyboardFocus() and not gui.IsGameUIVisible()
    if d and not mDown then
        Bar.Changer()
    end
    mDown = d
end)

function Bar.Utiliser(slot)
    local id = Bar.Slots[slot]
    if not id then return false end

    Bar.Selection = (Bar.Selection ~= slot) and slot or nil
    return true
end

-- touches réattribuées (F1) : on lit directement la touche
hook.Add("PlayerButtonDown", "NA_SkillBar_Touches", function(ply, key)
    if not IsFirstTimePredicted() or not NA_Touche or vgui.GetKeyboardFocus() or ply:IsTyping() then return end
    for n = 1, NB_EMPLACEMENTS do
        if key ~= _G["KEY_" .. n] and key == NA_Touche("slot" .. n) then Bar.Utiliser(n) return end
    end
end)

hook.Add("PlayerBindPress", "NA_SkillBar_Binds", function(ply, bind, pressed)
    if not pressed then return end

    -- clic droit : lance la technique sélectionnée
    if string.find(bind, "+attack2", 1, true) then
        local id = Bar.Selection and Bar.Slots[Bar.Selection]
        if not id then Bar.Selection = nil return end
        if NA_SelecteurOuvert and NA_SelecteurOuvert() then return end   -- le clic droit annule le menu d'armes

        -- NA_Lancer refuse d'elle-même une technique en recharge (son + voile rouge)
        NA_Lancer(id)
        return true   -- le clic droit ne fait pas aussi l'attaque spéciale de l'arme
    end

    local n = string.match(bind, "^slot(%d)$")
    n = tonumber(n)
    if not n or n < 1 or n > NB_EMPLACEMENTS then return end
    -- emplacement réattribué à une autre touche (F1) : la touche 1-6 reprend son rôle normal
    if NA_Touche and NA_Touche("slot" .. n) ~= _G["KEY_" .. n] then return end

    if Bar.Utiliser(n) then return true end
end)

----------------------------------------------------------
-- Dessin
----------------------------------------------------------

-- secteur circulaire plein (pour le temps de recharge)
local secteurPoints = {}
for i = 1, 34 do secteurPoints[i] = { x = 0, y = 0 } end
local function Secteur(cx, cy, r, frac)
    if frac <= 0 then return end
    local pts = secteurPoints
    pts[1].x, pts[1].y = cx, cy
    local seg = 32
    local fin = frac * 360
    for i = 0, seg do
        local a = math.rad(-90 + fin * (i / seg))
        pts[i + 2].x, pts[i + 2].y = cx + math.cos(a) * r, cy + math.sin(a) * r
    end
    draw.NoTexture()
    surface.DrawPoly(pts)
end

local function DessinerEmplacement(x, y, taille, slot, id, alpha)
    alpha = alpha or 255
    local cx, cy = x + taille / 2, y + taille / 2

    -- éclat bref à l'utilisation
    local dernier = id and NA_DernierLancer and NA_DernierLancer[id]
    local eclat = dernier and math.Clamp(1 - (CurTime() - dernier) / 0.35, 0, 1) or 0

    -- éclat rouge quand on essaie de lancer une technique pas prête
    local refus = id and NA_DernierRefus and NA_DernierRefus[id]
    local rouge = refus and math.Clamp(1 - (CurTime() - refus) / 0.4, 0, 1) or 0

    -- recharge : la vraie valeur du serveur (NA_ResteRecharge, _na_registre.lua)
    local reste = (id and NA_ResteRecharge) and NA_ResteRecharge(id) or 0
    local enRecharge = reste > 0

    -- technique pas encore débloquée (équipée par défaut) : grisée comme en recharge
    local verrouillee = id and NA_Debloquee and not NA_Debloquee(LocalPlayer(), id)

    local icone = id and Bar.Icone(id)

    -- rayon utile à l'intérieur de l'anneau doré : le flash et le voile de recharge
    -- s'arrêtent exactement au bord de l'icône (98 % de son image est le cercle)
    local rayon = icone and (taille * ICONE_RATIO / 2 * 0.98) or (taille * 0.40)

    -- fond coloré de la famille (seulement sans icône : l'icône a son propre fond)
    if id and not icone then
        local col = Bar.Couleur(id)
        surface.SetDrawColor(col.r, col.g, col.b, (40 + eclat * 120) * alpha / 255)
        Secteur(cx, cy, rayon, 1)
    end

    -- cadre
    surface.SetMaterial(MAT_CASE)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(x, y, taille, taille)

    -- technique sélectionnée (clic droit pour la lancer) : anneau doré qui pulse
    if id and Bar.Selection == slot then
        local pulse = 0.7 + 0.3 * math.sin(CurTime() * 5)
        for e = 0, 2 do
            surface.DrawCircle(cx, cy, taille * 0.45 + e, 255, 215, 120, 255 * pulse * alpha / 255)
        end
    end

    if id then
        local col = Bar.Couleur(id)

        if icone then
            -- l'icône est déjà ronde : on la pose dans l'anneau doré du cadre.
            -- En recharge, elle est grisée : elle n'est pas utilisable.
            local t = taille * ICONE_RATIO
            local lum = (enRecharge or verrouillee) and 110 or 255
            surface.SetMaterial(icone)
            surface.SetDrawColor(lum, lum, lum, alpha)
            surface.DrawTexturedRect(cx - t / 2, cy - t / 2, t, t)

            -- éclat bref à l'utilisation, par-dessus l'icône
            if eclat > 0 then
                surface.SetDrawColor(255, 255, 255, eclat * 110 * alpha / 255)
                Secteur(cx, cy, rayon, 1)
            end
        end

        -- technique à bascule active (Ketsuryugan...) : anneau rouge qui pulse,
        -- rappuyer la coupe (NA_BASCULES, _na_registre.lua)
        if NA_TechniqueActive and NA_TechniqueActive(id) then
            local pulse = 0.6 + 0.4 * math.sin(CurTime() * 5)
            surface.SetDrawColor(230, 30, 40, 200 * pulse * alpha / 255)
            for e = 0, 2 do
                surface.DrawCircle(cx, cy, rayon + 1 + e, 230, 30, 40, 200 * pulse * alpha / 255)
            end
        end

        if enRecharge then
            -- voile qui se vide au fil de la recharge + secondes restantes
            local total = NA_DureeRecharge and NA_DureeRecharge(id) or reste
            if total <= 0 then total = reste end

            surface.SetDrawColor(0, 0, 0, 170 * alpha / 255)
            Secteur(cx, cy, rayon, math.Clamp(reste / total, 0, 1))
            draw.SimpleText(string.format(reste >= 1 and "%d" or "%.1f", reste), "NA.Skill.CD",
                cx, cy, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        elseif not icone then
            -- pas d'icône : le nom court remplace l'image
            draw.SimpleText(Bar.NomCourt(id), "NA.Skill.Nom", cx, cy,
                Color(col.r, col.g, col.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else
        draw.SimpleText("+", "NA.Skill.Vide", cx, cy, Color(255, 255, 255, 60 * alpha / 255),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- refus (touche pressée pendant la recharge) : bref voile rouge
    if rouge > 0 then
        surface.SetDrawColor(220, 40, 40, rouge * 130 * alpha / 255)
        Secteur(cx, cy, rayon, 1)
    end

    -- touche
    local b = taille * 0.34
    surface.SetMaterial(MAT_BIND)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect(x + taille - b + 2, y + taille - b + 2, b, b)
    draw.SimpleText(NA_NomTouche and NA_NomTouche("slot" .. slot) or tostring(slot), "NA.Skill.Touche", x + taille - b / 2 + 2, y + taille - b / 2 + 2,
        Color(255, 215, 120, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end
Bar.DessinerEmplacement = DessinerEmplacement

hook.Add("HUDPaint", "NA_SkillBar_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local total = NB_EMPLACEMENTS * TAILLE + (NB_EMPLACEMENTS - 1) * ECART
    local h = math.Round(TAILLE * 0.5)
    local l = math.Round(h * DECK_L / DECK_H)
    -- centrée, mais jamais sur le HUD de vie : le losange (à gauche des cases) reste à droite de ses barres
    local x = math.max(ScrW() / 2 - total / 2, math.Round(GAUCHE_MIN_BASE * ScrH() / 1080) + l + ECART)
    local y = ScrH() - TAILLE - MARGE_BAS

    for i = 1, NB_EMPLACEMENTS do
        DessinerEmplacement(x + (i - 1) * (TAILLE + ECART), y, TAILLE, i, Bar.Slots[i])
    end
    -- losange à GAUCHE des cases, centré sur leur hauteur : le numéro de la barre ACTIVE est écrit dedans
    local dx, dy = x - ECART - l, y + TAILLE / 2 - h / 2
    surface.SetMaterial(MAT_DECK)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(dx, dy, l, h)
    -- le chiffre est centré sur le centre RÉEL du losange (pas celui de l'image entière), à la hauteur de ses chiffres
    surface.SetFont("NA.Skill.Deck")
    local tw, th = surface.GetTextSize(tostring(Bar.Active))
    surface.SetTextColor(70, 48, 26, 255)
    surface.SetTextPos(math.Round(dx + l * DECK_CX - tw / 2 + DECK_NUM_DX), math.Round(dy + h * DECK_CY - th / 2 + DECK_NUM_DY))
    surface.DrawText(tostring(Bar.Active))
end)

-- Hauteur occupée par la barre (pour placer les autres éléments du HUD au-dessus)
function Bar.HauteurOccupee()
    return TAILLE + MARGE_BAS
end
