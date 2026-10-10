--========================================================
-- Notification "objet reçu" (CLIENT)
--
-- Petite carte qui glisse sur le côté droit de l'écran : cadre de rareté
-- (ui/newUi/optimized), icône de l'objet, nom et rareté. Les cartes
-- s'empilent et disparaissent seules.
--
-- NA_NotifItem(nom, rarete, modele, image)
--   rarete : commun | rare | epique | legendaire (défaut commun)
--   modele : chemin d'un modèle (icône générée par le jeu) ou nil
--   image  : chemin d'une image (prioritaire sur le modèle) ou nil
-- Utilisé par AjouterEpee (cl_monmenu.lua).
--========================================================

local DUREE = 4.5       -- secondes affichées
local CHEMIN = "ui/newUi/optimized/"

local RARETES = {
    commun     = { nom = "COMMUN",     couleur = Color(205, 205, 205) },
    rare       = { nom = "RARE",       couleur = Color(90, 175, 255) },
    epique     = { nom = "ÉPIQUE",     couleur = Color(195, 115, 255) },
    legendaire = { nom = "LÉGENDAIRE", couleur = Color(255, 216, 75) },
}
local ALIAS = { common = "commun", epic = "epique", legendary = "legendaire", ["épique"] = "epique", ["légendaire"] = "legendaire" }

-- cadre utile de chaque texture de rareté (même réglage que cl_monmenu.lua)
local CADRE = { 7.5, 33, 242, 175 }

local FOND, OR, CREME, DOUX = Color(14, 10, 10, 235), Color(232, 196, 120), Color(240, 226, 196), Color(175, 155, 125)

local function Polices()
    local s = math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.7, 1.5)
    surface.CreateFont("NA.Notif.Titre", { font = "Roboto", size = math.floor(22 * s), weight = 800, extended = true })
    surface.CreateFont("NA.Notif.Petit", { font = "Roboto", size = math.floor(14 * s), weight = 700, extended = true })
    return s
end

local toasts = {}
local MAT = {}
local function Mat(chemin)
    MAT[chemin] = MAT[chemin] or Material(chemin, "smooth noclamp")
    return MAT[chemin]
end

local function Replacer(instant)
    local S = Polices()
    local h = 92 * S
    local y = ScrH() * 0.62
    for i = #toasts, 1, -1 do   -- la plus récente en bas
        local t = toasts[i]
        if not IsValid(t) then table.remove(toasts, i) end
    end
    for i = #toasts, 1, -1 do
        toasts[i].CibleY = y
        if instant then toasts[i]:SetY(y) end
        y = y - h - 10 * S
    end
end

function NA_NotifItem(nom, rarete, modele, image)
    local S = Polices()
    local cle = string.lower(tostring(rarete or "commun"))
    cle = ALIAS[cle] or cle
    local r = RARETES[cle] or RARETES.commun
    local tex = RARETES[cle] and cle or "commun"
    if tex == "commun" then tex = "comun" end   -- le fichier s'écrit "comun.png"

    local W, H = 330 * S, 92 * S
    local p = vgui.Create("DPanel")
    p:SetSize(W, H)
    p:SetMouseInputEnabled(false)
    p:SetKeyboardInputEnabled(false)
    p:SetPos(ScrW(), ScrH() * 0.62)
    p.Debut = SysTime()
    toasts[#toasts + 1] = p

    -- icône : modèle (icône mise en cache par le jeu) ou image
    local zone = H * 0.78
    local icone
    if image then
        icone = vgui.Create("DImage", p)
        icone:SetImage(image)
    elseif modele then
        icone = vgui.Create("ModelImage", p)
        icone:SetModel(modele)
    end
    if icone then
        icone:SetMouseInputEnabled(false)
        local ic = zone * 0.6
        icone:SetSize(ic, ic)
        icone:SetPos(H * 0.11 + (zone - ic) / 2, (H - ic) / 2)
    end

    p.Paint = function(s, w, h)
        local t = SysTime() - s.Debut
        local sortie = math.Clamp((t - (DUREE - 0.4)) / 0.4, 0, 1)
        s:SetAlpha(255 * (1 - sortie))

        draw.RoundedBox(8, 0, 0, w, h, FOND)
        surface.SetDrawColor(r.couleur.r, r.couleur.g, r.couleur.b, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        -- liseré de rareté à gauche
        surface.SetDrawColor(r.couleur)
        surface.DrawRect(0, 8, 3, h - 16)

        -- cadre de rareté autour de l'icône
        local fw = zone
        local fh = fw   -- case carrée
        local x0, y0 = h * 0.11, (h - fh) / 2
        local tw, th = fw * 256 / CADRE[3], fh * 256 / CADRE[4]
        local tx, ty = x0 - tw * CADRE[1] / 256, y0 - th * CADRE[2] / 256
        surface.SetMaterial(Mat(CHEMIN .. tex .. ".png"))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(tx, ty, tw, th)

        local tx2 = h + 4
        draw.SimpleText("OBJET REÇU", "NA.Notif.Petit", tx2, h * 0.24, DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(nom, "NA.Notif.Titre", tx2, h * 0.5, CREME, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(r.nom, "NA.Notif.Petit", tx2, h * 0.76, r.couleur, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- barre de temps
        surface.SetDrawColor(r.couleur.r, r.couleur.g, r.couleur.b, 120)
        surface.DrawRect(6, h - 4, (w - 12) * (1 - math.Clamp(t / DUREE, 0, 1)), 2)
    end

    p.Think = function(s)
        local t = SysTime() - s.Debut
        if t >= DUREE then s:Remove() return end
        -- glisse depuis la droite, puis reste à 16 px du bord
        local entree = math.Clamp(t / 0.35, 0, 1)
        entree = 1 - (1 - entree) ^ 3
        local cible = ScrW() - W - 16 * S
        s:SetX(Lerp(entree, ScrW(), cible))
        local y = s:GetY()
        if s.CibleY then s:SetY(Lerp(FrameTime() * 10, y, s.CibleY)) end
    end
    p.OnRemove = function() timer.Simple(0, function() Replacer() end) end

    Replacer(true)
    return p
end

concommand.Add("na_notif_test", function()
    NA_NotifItem("Épée de test", "legendaire", "models/weapons/w_pistol.mdl")
end)
