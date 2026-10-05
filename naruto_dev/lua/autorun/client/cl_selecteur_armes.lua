--========================================================
-- Sélecteur d'armes à la molette (CLIENT)
--
-- Un arc sur le bord de l'écran (à droite par défaut) : la molette fait glisser les éléments le long
-- de l'arc, celui du milieu est sélectionné. Clic gauche pour l'équiper
-- (sv_selecteur_armes.lua), clic droit pour annuler.
-- Images : materials/ui/hud/weapon_selector/
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local DOSSIER = "ui/hud/weapon_selector/"

-- Éléments, dans l'ordre de la molette.
--   id      : ce que le serveur doit équiper (voir sv_selecteur_armes.lua)
--   visible : fonction optionnelle, l'élément n'apparaît que si elle renvoie true
local ELEMENTS = {
    { id = "camera", nom = "Caméra",  icone = "camera.png" },   -- ne fait rien pour l'instant
    { id = "mains",  nom = "Mains",   icone = "empty.png" },
    { id = "poings", nom = "Poings",  icone = "poing.png" },
    { id = "epee",   nom = "Épée",    icone = "sword.png", visible = function(ply) return NA_EpeeDuJoueur(ply) ~= nil end },
}

local COTE            = "droite" -- "droite" ou "gauche" de l'écran
local ARC_INVERSE     = true   -- à droite : true = arc bombé vers le centre de l'écran, icônes côté bord
                               --            false = arc bombé vers le bord, icônes côté centre
local MARGE_BORD      = 24     -- distance entre le bord de l'écran et le menu (à 1080p)
local HAUTEUR_ARC     = 470    -- hauteur de l'arc (à 1080p)
local ESPACEMENT      = 30     -- degrés entre deux éléments sur l'arc
local ANGLE_MAX       = 75     -- au-delà, les éléments sont invisibles
local TAILLE_CHOISI   = 128    -- taille de l'icône sélectionnée (à 1080p)
local TAILLE_AUTRE    = 70     -- taille des autres icônes
local TAILLE_PASTILLE = 22     -- pastille posée sur l'arc

local DUREE_AFFICHAGE  = 4     -- secondes sans molette avant que le menu se ferme (sans rien changer)
local TOUJOURS_VISIBLE = false -- true = le menu reste affiché (en transparence) en permanence
local VITESSE_ANIM     = 12    -- vitesse de glissement des éléments

-- Dans le gamemode Naruto RP, la molette sert déjà à autre chose
local ACTIF_DANS_NARUTORP = false
--========================================================

-- Épée équipée dans l'emplacement "Arme" du menu F4 (classe, ou nil)
function NA_EpeeDuJoueur(ply)
    if not IsValid(ply) then return end
    local classe = ply:GetNW2String("NA_Epee", "")
    if classe ~= "" then return classe end
end

local function Actif()
    return ACTIF_DANS_NARUTORP or engine.ActiveGamemode() ~= "narutorp"
end

----------------------------------------------------------
-- Mode caméra : choisi dans le menu, il dure tant que l'arme en main ne change pas
----------------------------------------------------------
local cameraArme   -- classe de l'arme en main au moment où la caméra a été choisie

function NA_ModeCamera()
    if not cameraArme then return false end
    local wep = LocalPlayer():GetActiveWeapon()
    if (IsValid(wep) and wep:GetClass() or "") ~= cameraArme then
        cameraArme = nil      -- l'arme a changé : on n'est plus en mode caméra
        return false
    end
    return true
end

-- Pas de jutsu avec les mains vides ni en mode caméra (vérifié par NA_Lancer, _na_registre.lua)
function NA_JutsuBloque(ply)
    if NA_ModeCamera() then return true end
    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == "hand"
end

local mats = {}
local function Mat(nom)
    if not mats[nom] then mats[nom] = Material(DOSSIER .. nom, "smooth mips") end
    return mats[nom]
end

-- Préchargement : sans ça, les images (1254 x 1254) et le son se chargent au
-- premier cran de molette, ce qui fait un petit freeze. On les charge à la connexion,
-- puis on les dessine une fois de façon invisible pour qu'elles soient envoyées à la carte graphique.
local IMAGES = { "demi_cercle_wp.png", "cercle_wp.png" }
for _, e in ipairs(ELEMENTS) do IMAGES[#IMAGES + 1] = e.icone end

local prechauffe = false
hook.Add("InitPostEntity", "NA_Selecteur_Precharger", function()
    for _, nom in ipairs(IMAGES) do Mat(nom) end
    util.PrecacheSound("solve_naruto_base/ui/menu_selection_v2.wav")
    util.PrecacheSound("naruto_sound/menu_select.mp3")
end)

hook.Add("HUDPaint", "NA_Selecteur_Prechauffer", function()
    if prechauffe then return end
    prechauffe = true
    for _, nom in ipairs(IMAGES) do
        surface.SetMaterial(Mat(nom))
        surface.SetDrawColor(255, 255, 255, 1)
        surface.DrawTexturedRect(-4, -4, 2, 2)   -- hors de l'écran
    end
    hook.Remove("HUDPaint", "NA_Selecteur_Prechauffer")
end)

local function CreerPolices()
    local k = ScrH() / 1080
    surface.CreateFont("NA.Selecteur.Nom",  { font = "Roboto", size = math.Round(30 * k), weight = 800 })
    surface.CreateFont("NA.Selecteur.Info", { font = "Roboto", size = math.Round(17 * k), weight = 500 })
end
CreerPolices()
hook.Add("OnScreenSizeChanged", "NA_Selecteur_Polices", CreerPolices)

----------------------------------------------------------
-- État
----------------------------------------------------------
local selAbs      = 0      -- élément sélectionné (0 = premier)
local affiche     = 0      -- position animée (suit selAbs en douceur)
local derniereMolette = -100
local alpha       = 0
local impulsion   = 0      -- petit rebond de la pastille à chaque cran

local function Visibles(ply)
    local liste = {}
    for _, e in ipairs(ELEMENTS) do
        if not e.visible or e.visible(ply) then liste[#liste + 1] = e end
    end
    return liste
end

-- Élément qui correspond à l'arme en main
local function IndexActuel(ply, liste)
    local wep = ply:GetActiveWeapon()
    local classe = IsValid(wep) and wep:GetClass() or ""
    for i, e in ipairs(liste) do
        if e.id == "camera" and NA_ModeCamera() then return i end
    end
    for i, e in ipairs(liste) do
        if (e.id == "mains" and classe == "hand")
            or (e.id == "poings" and classe == "naruto_poings")
            or (e.id == "epee" and classe ~= "" and classe == NA_EpeeDuJoueur(ply)) then
            return i
        end
    end
end

local function Ouvert()
    return CurTime() - derniereMolette < DUREE_AFFICHAGE
end
NA_SelecteurOuvert = Ouvert   -- le clic droit ferme ce menu : la barre de techniques ne le prend pas (cl_skillbar.lua)

----------------------------------------------------------
-- Molette
----------------------------------------------------------
local function Fermer()
    derniereMolette = -100
end

-- Équipe l'élément sélectionné
local function Valider(ply)
    local liste = Visibles(ply)
    if #liste == 0 then return end

    local e = liste[math.Clamp(selAbs, 0, #liste - 1) + 1]

    -- mode caméra : retenu côté client (le serveur n'a rien à équiper pour l'instant)
    if e.id == "camera" then
        local wep = ply:GetActiveWeapon()
        cameraArme = IsValid(wep) and wep:GetClass() or ""
    else
        cameraArme = nil
    end

    net.Start("NA_Selecteur_Choisir")
        net.WriteString(e.id)
    net.SendToServer()
    ply:EmitSound("naruto_sound/menu_select.mp3", 0, 100, 0.5)
    Fermer()
end

hook.Add("PlayerBindPress", "NA_Selecteur_Molette", function(ply, bind, pressed)
    if not pressed or not Actif() then return end

    -- menu ouvert : clic gauche = équiper, clic droit = annuler
    if Ouvert() then
        if string.find(bind, "+attack2", 1, true) then
            Fermer()
            return true
        elseif string.find(bind, "+attack", 1, true) then
            Valider(ply)
            return true
        end
    end

    local sens
    if string.find(bind, "invnext", 1, true) then sens = 1
    elseif string.find(bind, "invprev", 1, true) then sens = -1
    else return end

    -- clic maintenu : la molette sert à l'arme (distance du physgun...)
    if ply:KeyDown(IN_ATTACK) or ply:KeyDown(IN_ATTACK2) then return end
    if not ply:Alive() or ply:InVehicle() then return end

    local liste = Visibles(ply)
    if #liste == 0 then return true end

    -- à l'ouverture, on part de l'élément actuellement en main
    if not Ouvert() then
        selAbs = (IndexActuel(ply, liste) or 1) - 1
        affiche = selAbs
    end

    -- pas de défilement infini : on s'arrête au premier et au dernier élément
    local nouveau = math.Clamp(selAbs + sens, 0, #liste - 1)
    derniereMolette = CurTime()
    if nouveau ~= selAbs then
        selAbs = nouveau
        impulsion = 1
        ply:EmitSound("solve_naruto_base/ui/menu_selection_v2.wav", 0, 110, 0.35)
    end
    return true
end)

----------------------------------------------------------
-- Affichage
----------------------------------------------------------
hook.Add("HUDShouldDraw", "NA_Selecteur_CacherHL2", function(nom)
    if nom == "CHudWeaponSelection" and Actif() then return false end
end)

-- Géométrie de l'image de l'arc (129 x 428) : cercle de rayon ~244,
-- centre à ~246 px du bord gauche de l'image, à mi-hauteur.
local ARC_W, ARC_H = 129, 428
local ARC_RAYON, ARC_CX = 243.8, 245.8

local function Lissage(x) return x * x * (3 - 2 * x) end

hook.Add("HUDPaint", "NA_Selecteur_Dessin", function()
    if not Actif() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local dt = FrameTime()
    local cible = Ouvert() and 1 or (TOUJOURS_VISIBLE and 0.35 or 0)
    alpha = math.Approach(alpha, cible, dt * (cible > alpha and 6 or 2.5))
    affiche = Lerp(math.min(dt * VITESSE_ANIM, 1), affiche, selAbs)
    impulsion = math.Approach(impulsion, 0, dt * 4)
    if alpha <= 0.01 then return end

    local liste = Visibles(ply)
    local n = #liste
    if n == 0 then return end

    selAbs = math.Clamp(selAbs, 0, n - 1)   -- si un élément a disparu (épée retirée)

    -- menu fermé et toujours visible : on suit l'arme en main
    if not Ouvert() and TOUJOURS_VISIBLE and alpha < 0.4 then
        local actuel = IndexActuel(ply, liste)
        if actuel then selAbs = actuel - 1 end
    end

    local k = ScrH() / 1080
    local echelleArc = (HAUTEUR_ARC * k) / ARC_H
    local cy = ScrH() * 0.5
    local rayon = ARC_RAYON * echelleArc
    local aw, ah = ARC_W * echelleArc, ARC_H * echelleArc
    local glisse = (1 - Lissage(alpha)) * 40 * k   -- entre depuis le bord de l'écran

    -- Trois dispositions :
    --   gauche                 : arc "(" collé au bord gauche, icônes à sa droite
    --   droite + ARC_INVERSE   : arc "(" côté centre, icônes entre l'arc et le bord droit
    --   droite sans ARC_INVERSE: arc ")" collé au bord droit, icônes à sa gauche (miroir de gauche)
    local droite = COTE == "droite"
    local miroir = droite and not ARC_INVERSE
    local cx      -- centre du cercle de l'arc, dans le repère "non retourné"
    if droite and ARC_INVERSE then
        -- + 40 : place pour les icônes du haut et du bas, qui s'écartent vers le bord
        cx = ScrW() - MARGE_BORD * k - (TAILLE_CHOISI + 10 + 40) * k + rayon + glisse
    else
        cx = MARGE_BORD * k + ARC_CX * echelleArc - glisse
    end
    local function X(x) return miroir and (ScrW() - x) or x end
    local sensIcone = miroir and -1 or 1

    -- l'arc
    local arcX = cx - ARC_CX * echelleArc
    surface.SetMaterial(Mat("demi_cercle_wp.png"))
    surface.SetDrawColor(255, 255, 255, 255 * alpha)
    if miroir then
        surface.DrawTexturedRectUV(X(arcX) - aw, cy - ah / 2, aw, ah, 1, 0, 0, 1)   -- retournée
    else
        surface.DrawTexturedRect(arcX, cy - ah / 2, aw, ah)
    end

    -- les éléments, du plus éloigné au plus proche (le sélectionné dessiné en dernier)
    local ordre = {}
    for i = 1, n do
        local d = (i - 1) - affiche
        ordre[#ordre + 1] = { e = liste[i], d = d }
    end
    table.sort(ordre, function(a, b) return math.abs(a.d) > math.abs(b.d) end)

    local choisi = liste[selAbs + 1]

    for _, o in ipairs(ordre) do
        local angle = o.d * ESPACEMENT
        if math.abs(angle) > ANGLE_MAX then continue end

        local rad = math.rad(angle)
        local px = X(cx - rayon * math.cos(rad))
        local py = cy + rayon * math.sin(rad)

        -- 1 au milieu, 0 au bord de l'arc
        local proche = 1 - math.Clamp(math.abs(o.d), 0, 1)
        local fondu = 1 - math.Clamp(math.abs(angle) / ANGLE_MAX, 0, 1)
        local a = alpha * (0.35 + 0.65 * fondu)

        -- pastille sur l'arc (grossit et rebondit quand elle arrive au milieu)
        local tp = TAILLE_PASTILLE * k * (1 + 0.45 * proche + 0.35 * impulsion * proche)
        surface.SetMaterial(Mat("cercle_wp.png"))
        surface.SetDrawColor(255, 255, 255, 255 * a)
        surface.DrawTexturedRect(px - tp / 2, py - tp / 2, tp, tp)

        -- icône, posée vers l'intérieur de l'arc
        local taille = Lerp(proche, TAILLE_AUTRE, TAILLE_CHOISI) * k
        local ix = px + sensIcone * math.cos(rad) * (taille * 0.5 + 10 * k)
        local iy = py - math.sin(rad) * (taille * 0.5 + 10 * k)
        local gris = Lerp(proche, 150, 255)
        surface.SetMaterial(Mat(o.e.icone))
        surface.SetDrawColor(gris, gris, gris, 255 * a)
        surface.DrawTexturedRect(ix - taille / 2, iy - taille / 2, taille, taille)

        -- nom de l'élément sélectionné
        if o.e == choisi and proche > 0.5 then
            local ta = 255 * alpha * (proche - 0.5) * 2
            local tx, aligne
            if droite and ARC_INVERSE then
                tx, aligne = px - tp / 2 - 12 * k, TEXT_ALIGN_RIGHT   -- de l'autre côté de l'arc
            elseif droite then
                tx, aligne = ix - taille / 2 - 10 * k, TEXT_ALIGN_RIGHT
            else
                tx, aligne = ix + taille / 2 + 10 * k, TEXT_ALIGN_LEFT
            end
            draw.SimpleTextOutlined(o.e.nom, "NA.Selecteur.Nom", tx, iy - 4 * k,
                Color(245, 225, 170, ta), aligne, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, ta * 0.8))

            local info = o.e.id == "camera" and "Bientôt disponible"
                or (o.e.id == "epee" and (function()
                    local def = weapons.Get(NA_EpeeDuJoueur(ply) or "")
                    return def and def.PrintName or ""
                end)()) or ""
            if info ~= "" then
                draw.SimpleTextOutlined(info, "NA.Selecteur.Info", tx, iy + 2 * k,
                    Color(220, 220, 220, ta), aligne, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, ta * 0.8))
            end
        end
    end
end)
