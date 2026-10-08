--========================================================
-- ÉCRAN DE CHARGEMENT (textures) - CLIENT
--
--   Affiché dès l'arrivée sur le serveur, par-dessus le jeu, le temps que
--   les textures / modèles se chargent. Diaporama des images de
--   materials/ui/loadMenu/ (load1.png ... load4.png), barre de progression,
--   conseils. Disparaît en fondu quand le jeu est prêt et fluide.
--
--   Commande : na_loadmenu_test   (rejoue l'écran pour le tester)
--   ConVar   : na_loadmenu 0/1    (désactiver l'écran)
--========================================================

local IMAGES = {
    "materials/ui/loadMenu/load1.png",
    "materials/ui/loadMenu/load2.png",
    "materials/ui/loadMenu/load3.png",
    "materials/ui/loadMenu/load4.png",
}

if SERVER then
    AddCSLuaFile()
    for _, img in ipairs(IMAGES) do resource.AddFile(img) end
    return
end

--========================================================
-- RÉGLAGES
--========================================================
local DUREE_MIN      = 5     -- secondes minimum d'affichage
local DUREE_MAX      = 40    -- sécurité : on ferme quoi qu'il arrive
local DUREE_IMAGE    = 5     -- secondes par image du diaporama
local DUREE_FONDU_IMG = 1.2  -- fondu enchaîné entre deux images
local DUREE_FONDU_FIN = 1.0  -- fondu de sortie
local ZOOM_LENT      = 0.06  -- zoom lent de l'image (0 = aucun)
local STABLE_FPS     = 1 / 25 -- le jeu est "fluide" sous ce temps par image
local STABLE_DUREE   = 1.2   -- ... pendant au moins N secondes d'affilée

local TITRE = "NARUTO RP"
local CONSEILS = {
    "Maintiens ta concentration : le chakra se régénère quand tu te reposes.",
    "Les mudras s'enchaînent plus vite avec de l'entraînement.",
    "Chaque clan possède ses propres techniques.",
    "Monte en rang pour débloquer de nouvelles techniques.",
    "Le sprint consomme du chakra : garde toujours une réserve.",
    "Mieux vaut esquiver que subir : utilise ton dash.",
}
--========================================================

local cvActif = CreateClientConVar("na_loadmenu", "1", true, false, "Active l'écran de chargement Naruto RP")

local mats = {}
for i, chemin in ipairs(IMAGES) do
    mats[i] = Material(string.gsub(chemin, "^materials/", ""), "noclamp smooth")
end

local function Echelle() return ScrH() / 1080 end

local function CreerPolices()
    local k = Echelle()
    surface.CreateFont("NA.Load.Titre",  { font = "Roboto", size = math.Round(84 * k), weight = 900, extended = true })
    surface.CreateFont("NA.Load.Statut", { font = "Roboto", size = math.Round(24 * k), weight = 700, extended = true })
    surface.CreateFont("NA.Load.Conseil",{ font = "Roboto", size = math.Round(20 * k), weight = 500, extended = true })
end
CreerPolices()

-- Dessine une image en "couvrir l'écran" avec un zoom centré
local function DessinerCouvrant(mat, alpha, zoom)
    local sw, sh = ScrW(), ScrH()
    local ratio = 1672 / 941
    local w, h = sw, sw / ratio
    if h < sh then h = sh; w = sh * ratio end
    w, h = w * zoom, h * zoom
    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, alpha)
    surface.DrawTexturedRect((sw - w) / 2, (sh - h) / 2, w, h)
end

local PANEL = {}
local ecran

function PANEL:Init()
    self:SetSize(ScrW(), ScrH())
    self:SetPos(0, 0)
    self:SetZPos(32767)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(true)   -- bloque les clics pendant le chargement
    self.debut      = SysTime()
    self.progres    = 0
    self.pret       = false           -- InitPostEntity reçu
    self.stableDepuis = nil
    self.fin        = nil             -- début du fondu de sortie
    self.conseil    = math.random(#CONSEILS)
    self.conseilT   = SysTime()
    self.premiere   = math.random(#IMAGES)
end

function PANEL:MarquerPret()
    self.pret = true
    self.pretT = SysTime()
end

function PANEL:Think()
    local maintenant = SysTime()
    local ecoule = maintenant - self.debut

    -- Progression : monte doucement vers 85 %, puis finit quand le jeu est prêt
    local cible = 0.85 * (1 - math.exp(-ecoule / 6))
    if self.pret then
        -- fluidité : le jeu a fini de charger les textures quand les images sont rapides
        if FrameTime() < STABLE_FPS then
            self.stableDepuis = self.stableDepuis or maintenant
        else
            self.stableDepuis = nil
        end
        local stable = self.stableDepuis and (maintenant - self.stableDepuis) >= STABLE_DUREE
        local depuisPret = maintenant - self.pretT
        cible = 0.85 + 0.15 * math.min(depuisPret / 2, 1)
        if not self.fin and ecoule >= DUREE_MIN and (stable or depuisPret > 15) then
            self.fin = maintenant
            cible = 1
        end
    end
    if not self.fin and ecoule >= DUREE_MAX then self.fin = maintenant; cible = 1 end

    self.progres = math.max(self.progres, Lerp(FrameTime() * 4, self.progres, cible))
    if self.fin then self.progres = Lerp(FrameTime() * 8, self.progres, 1) end

    if maintenant - self.conseilT > 6 then
        self.conseil = self.conseil % #CONSEILS + 1
        self.conseilT = maintenant
    end

    if self.fin and maintenant - self.fin >= DUREE_FONDU_FIN then
        self:Remove()
        ecran = nil
    end
end

function PANEL:Paint(w, h)
    local t = SysTime() - self.debut
    local k = Echelle()

    local global = 1
    if self.fin then global = 1 - math.Clamp((SysTime() - self.fin) / DUREE_FONDU_FIN, 0, 1) end
    local a = 255 * global

    surface.SetDrawColor(8, 8, 12, a)
    surface.DrawRect(0, 0, w, h)

    -- Diaporama : image courante + fondu vers la suivante
    local n = #mats
    local pos = t / DUREE_IMAGE
    local idx = math.floor(pos)
    local frac = pos - idx
    local courante = (self.premiere + idx - 1) % n + 1
    local suivante = courante % n + 1
    local seuil = 1 - DUREE_FONDU_IMG / DUREE_IMAGE
    local fondu = frac > seuil and (frac - seuil) / (1 - seuil) or 0

    local zoom = 1 + ZOOM_LENT * frac
    if not mats[courante]:IsError() then
        DessinerCouvrant(mats[courante], a, zoom)
    end
    if fondu > 0 and not mats[suivante]:IsError() then
        DessinerCouvrant(mats[suivante], a * fondu, 1)
    end

    -- Assombrissement haut / bas pour la lisibilité
    surface.SetDrawColor(0, 0, 0, 160 * global)
    surface.SetMaterial(Material("vgui/gradient-d"))
    surface.DrawTexturedRect(0, h * 0.55, w, h * 0.45)
    surface.SetMaterial(Material("vgui/gradient-u"))
    surface.DrawTexturedRect(0, 0, w, h * 0.25)

    -- Titre
    draw.SimpleTextOutlined(TITRE, "NA.Load.Titre", w / 2, 70 * k, Color(255, 255, 255, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3 * k, Color(0, 0, 0, a * 0.7))

    -- Barre de progression
    local bw, bh = 640 * k, 10 * k
    local bx, by = (w - bw) / 2, h - 130 * k
    surface.SetDrawColor(0, 0, 0, 170 * global)
    draw.RoundedBox(bh / 2, bx - 3, by - 3, bw + 6, bh + 6, Color(0, 0, 0, 170 * global))
    draw.RoundedBox(bh / 2, bx, by, bw, bh, Color(255, 255, 255, 40 * global))
    local rempli = bw * math.Clamp(self.progres, 0, 1)
    if rempli > bh then
        draw.RoundedBox(bh / 2, bx, by, rempli, bh, Color(255, 140, 30, 255 * global))
        -- éclat qui défile sur la barre
        local gx = bx + ((t * 0.6) % 1) * rempli
        draw.RoundedBox(bh / 2, math.min(gx, bx + rempli - 40 * k), by, 40 * k, bh, Color(255, 220, 150, 120 * global))
    end

    -- Statut
    local points = string.rep(".", math.floor(t * 2) % 4)
    local statut = self.fin and "Prêt !" or ("Chargement des textures" .. points)
    draw.SimpleTextOutlined(statut, "NA.Load.Statut", bx, by - 14 * k, Color(255, 255, 255, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, a * 0.6))
    draw.SimpleTextOutlined(math.floor(self.progres * 100) .. " %", "NA.Load.Statut", bx + bw, by - 14 * k, Color(255, 200, 120, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, a * 0.6))

    -- Conseil
    local ca = a * math.Clamp(math.min((SysTime() - self.conseilT) * 2, (6 - (SysTime() - self.conseilT)) * 2), 0, 1)
    draw.SimpleTextOutlined(CONSEILS[self.conseil], "NA.Load.Conseil", w / 2, by + 45 * k, Color(230, 230, 230, ca), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, ca * 0.6))
end

vgui.Register("NA.LoadMenu", PANEL, "Panel")

local function Afficher(pret)
    if IsValid(ecran) then ecran:Remove() end
    CreerPolices()
    ecran = vgui.Create("NA.LoadMenu")
    if pret then ecran:MarquerPret() end
end

-- Affichage immédiat à l'arrivée sur le serveur
if cvActif:GetBool() then Afficher(false) end

hook.Add("InitPostEntity", "NA.LoadMenu", function()
    if IsValid(ecran) then ecran:MarquerPret() end
end)

-- Si les Lua sont rechargés en cours de partie (refresh), ne pas rester coincé
if IsValid(LocalPlayer()) and IsValid(ecran) then ecran:MarquerPret() end

hook.Add("OnScreenSizeChanged", "NA.LoadMenu", function()
    if IsValid(ecran) then CreerPolices(); ecran:SetSize(ScrW(), ScrH()) end
end)

concommand.Add("na_loadmenu_test", function() Afficher(true) end)
