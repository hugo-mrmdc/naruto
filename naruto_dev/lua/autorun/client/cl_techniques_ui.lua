--========================================================
-- Liste des attaques + équipement de la barre (CLIENT)
-- Ouvre avec F2, ou la commande console : attaques
--
-- Équiper une technique dans la barre (touches 1 à 6) :
--   - clique sur une technique, puis sur un emplacement en haut ;
--   - ou clic droit sur la technique -> "Équiper dans l'emplacement N".
--   Clic droit sur un emplacement pour le vider.
--
-- Pour ajouter une technique : une ligne dans TECHNIQUES ci-dessous.
--   key   = code de touche (KEY_*) -> le vrai nom de la touche est affiché,
--           ou texte ("Clic gauche") -> affiché tel quel
--   id    = identifiant NA_Cast de la technique (la rend équipable dans la barre)
--   court = nom court affiché dans l'emplacement de la barre
--   cd    = recharge en secondes (affichée, et indicative dans la barre)
--   icone = image de la technique, chemin RELATIF au dossier materials/
--           ex : "ui/icon/kami_aile_papier.png"  (vide "" = nom court affiché à la place)
--========================================================

local OPEN_KEY = KEY_F2

local TECHNIQUES = {
    -- ===== KATON =====
    { cat = "Katon", name = "Boule de feu", key = KEY_Y, id = "katon_boule", icone = "ui/icon/katon_boule_feu.png", court = "Feu", cd = 3,
      desc = "Projette une boule de feu qui suit la direction du regard." },
    { cat = "Katon", name = "Boule de feu sautée", key = KEY_J, id = "katon_saut", icone = "", court = "Saut feu", cd = 2,
      desc = "Charge de chakra puis boule de feu avec un bond." },

    -- ===== SUITON =====
    { cat = "Suiton", name = "Requin d'eau", key = KEY_R, id = "suiton_requin", icone = "", court = "Requin", cd = 5.3,
      desc = "Envoie un requin d'eau sur la cible visée." },

    -- ===== MOKUTON =====
    { cat = "Mokuton", name = "Arche", key = KEY_K, id = "mokuton_arche", icone = "", court = "Arche", cd = 2,
      desc = "Fait jaillir une arche de bois devant toi." },
    { cat = "Mokuton", name = "Fleur", key = KEY_O, id = "mokuton_fleur", icone = "", court = "Fleur", cd = 1.5,
      desc = "Fait pousser une fleur de bois à l'endroit visé." },
    { cat = "Mokuton", name = "Dragon", key = "B / L", id = "mokuton_dragon", icone = "", court = "Dragon",
      desc = "Invoque le dragon et monte dessus (B), ou le renvoie (L). Dans la barre, un seul emplacement fait les deux. En vol : Espace pour monter, Ctrl pour descendre." },
    { cat = "Mokuton", name = "Dragon : attraper", key = KEY_E,
      desc = "En vol, attrape la cible devant toi dans la gueule. Rappuie pour la lâcher." },

    -- ===== SALAMANDRE =====
    { cat = "Salamandre", name = "Invocation", key = KEY_E,
      desc = "En regardant le vide, fait apparaître la salamandre. E sur elle pour la monter." },
    { cat = "Salamandre", name = "Dôme de brume", key = KEY_T, id = "salamandre_dome", icone = "ui/icon/salamandre_nuage_poison.png", court = "Dôme",
      desc = "Pose au sol un dôme de brume toxique pendant 5 secondes : il blesse et empoisonne tous ceux qui sont dedans, sauf toi. Coûte 15 de chakra.",
      dmg = "5 par demi-seconde + poison" },
    { cat = "Salamandre", name = "Crachat de poison", key = KEY_I, id = "salamandre_poison", icone = "ui/icon/salamandre_tir_poison.png", court = "Poison", cd = 2.5,
      desc = "Crache un projectile empoisonné : dégâts à l'impact puis poison pendant quelques secondes. Coûte 10 de chakra.",
      dmg = "50 + 10 par seconde" },
    { cat = "Salamandre", name = "Typhon de poison", key = "Barre", id = "salamandre_tornade", icone = "ui/icon/salamandre_tornade_poison.png", court = "Typhon",
      desc = "Fait naître un typhon là où tu regardes (900 unités max) pendant 6 secondes : il aspire les ennemis vers son cœur, qui les blesse et les empoisonne. Un cercle au sol montre l'endroit pendant l'incantation. Uniquement depuis la barre. Coûte 25 de chakra.",
      dmg = "8 par demi-seconde au cœur + poison" },
    { cat = "Salamandre", name = "Corps de poison", key = "Barre", id = "salamandre_corps", icone = "ui/icon/salamandre_corp_poison.png", court = "Corps",
      desc = "Ton corps suinte le poison pendant 10 secondes : ceux qui te collent sont brûlés et empoisonnés, ceux qui te frappent de près sont empoisonnés, et tu es immunisé contre le poison. Uniquement depuis la barre. Coûte 20 de chakra.",
      dmg = "4 par demi-seconde au contact + poison" },

    -- ===== FUMA =====
    { cat = "Fuma", name = "Téléportation", key = KEY_G, id = "fuma_tp", icone = "ui/icon/fuma_shuriken.png", court = "TP",
      desc = "Lance un shuriken : rappuie pour te téléporter dessus. S'il touche un mur, tu y es téléporté automatiquement ; s'il touche un ennemi, il explose. S'il ne touche rien, il disparaît.",
      dmg = "60 (explosion sur un ennemi)" },
    { cat = "Fuma", name = "Jugement des Quatre Lames", key = "", id = "fuma_jugement", icone = "ui/icon/fuma_jugement_shuriken.png", court = "Jugement",
      desc = "Lance un fil d'acier là où tu vises. S'il touche un ennemi, il est étourdi 2,5 secondes : quatre shurikens apparaissent au-dessus de lui, un de chaque côté, et foncent sur lui. Coûte 25 de chakra.",
      dmg = "4 x 20" },
    { cat = "Fuma", name = "Aura Fuma", key = "", id = "fuma_aura", icone = "ui/icon/fuma_morsure_sanglante.png", court = "Aura",
      desc = "Une aura t'entoure pendant 12 secondes : tu infliges 30 % de dégâts en plus et tu en encaisses 25 % de moins. Coûte 20 de chakra.",
      dmg = "+30 % de dégâts, -25 % de dégâts subis" },
    { cat = "Fuma", name = "Shuriken Céleste", key = "", id = "fuma_ciel", icone = "ui/icon/fuma_shuriken_acier.png", court = "Céleste",
      desc = "Un shuriken géant tombe du ciel sur le point que tu vises et explose en fumée au sol : dégâts de zone et projection. Coûte 35 de chakra.",
      dmg = "70 au centre" },
    { cat = "Fuma", name = "Invisibilité", key = KEY_F, id = "fuma_invisibilite", icone = "ui/icon/fuma_invisible.png", court = "Invisible",
      desc = "Te rend invisible 10 secondes après une seconde d'incantation, dans un nuage de fumée. Rappuie pour réapparaître plus tôt ; lancer un autre jutsu te fait aussi réapparaître." },

    -- ===== KAMI =====
    { cat = "Kami", name = "Kami Circle", key = KEY_N, id = "kami_circle", icone = "ui/icon/kami_tornade_papier.png", court = "Cercle",
      desc = "Zone de dégâts posée au sol. Touche tout le monde sauf toi. Réglable en console (kami_circle_damage, kami_circle_tick).",
      dmg = "20 par tick" },
    { cat = "Kami", name = "Shuriken de papier", key = KEY_M, id = "kami_shuriken", icone = "ui/icon/kami_shuriken_papier.png", court = "Shuriken", cd = 25,
      desc = "Lance un shuriken de papier tournoyant dans la direction du regard. Coûte 8 de chakra.",
      dmg = "35 (70 à la tête)" },
    { cat = "Kami", name = "Paper Shield", key = KEY_P, id = "kami_bouclier", icone = "ui/icon/kami_bouclier_papier.png", court = "Bouclier",
      desc = "Enveloppe ton corps de papier : tu encaisses moitié moins de dégâts. Coûte 25 de chakra.",
      dmg = "-50 % de dégâts reçus" },
    { cat = "Kami", name = "Ailes de papier", key = KEY_H, id = "kami_ailes", icone = "ui/icon/kami_aile_papier.png", court = "Ailes",
      desc = "Fait apparaître des ailes dans ton dos et te permet de voler. Direction avec ZQSD, Espace pour monter, Ctrl pour descendre, rappuie pour te poser.",
      dmg = "6 chakra par seconde" },

    -- ===== JINTON =====
    { cat = "Jinton", name = "Cube de confinement", key = "", id = "jinton_cube", icone = "ui/icon/jinton_cube_confinement.png", court = "Cube",
      desc = "Vise un ennemi à portée : un cube l'enferme, l'immobilise 4 secondes et le ronge à chaque tick. Coûte 30 de chakra.",
      dmg = "8 par tick (toutes les 0,5 s)" },
    { cat = "Jinton", name = "Bouclier Jinton", key = "", id = "jinton_bouclier", icone = "ui/icon/jinton_bulle_poussiere.png", court = "Bouclier",
      desc = "Une sphère de poussière t'entoure pendant 10 secondes : un bouclier égal à 20 % de ta vie max encaisse les dégâts à ta place. Coûte 25 de chakra.",
      dmg = "Bouclier de 20 % de la vie" },
    { cat = "Jinton", name = "Rayon de dissolution", key = "", id = "jinton_laser", icone = "ui/icon/jinton_rayon_dissolution.png", court = "Rayon",
      desc = "Pendant 15 secondes, tu t'envoles et un laser part de ta main vers là où tu vises. Il traverse tout jusqu'au premier mur et ronge ce qu'il touche. Vol : ZQSD, Espace pour monter, Ctrl pour descendre. Coûte 40 de chakra.",
      dmg = "6 par tick (toutes les 0,25 s)" },

    -- ===== KAGUYA =====
    { cat = "Kaguya", name = "Armure d'os", key = "", id = "kaguya_armure", icone = "ui/icon/kaguya_armure_os.png", court = "Armure",
      desc = "Une armure d'os pousse sur ton corps pendant 15 secondes : tu encaisses 40 % de dégâts en moins. Coûte 25 de chakra.",
      dmg = "-40 % de dégâts subis" },
    { cat = "Kaguya", name = "Légion d'os", key = "", id = "kaguya_legion", icone = "ui/icon/kaguya_legion_os.png", court = "Légion",
      desc = "Des os jaillissent autour de toi pendant 8 secondes et blessent tous les ennemis proches à chaque tick. Coûte 30 de chakra.",
      dmg = "12 par tick (toutes les 0,5 s)" },
    { cat = "Kaguya", name = "Danse des os", key = "", id = "kaguya_danse", icone = "ui/icon/kaguya_danse_des_os.png", court = "Danse",
      desc = "Vise un ennemi : un lien s'accroche entre ton torse et lui pendant 6 secondes. Il perd de la vie à chaque tick et tu la récupères. Coûte 30 de chakra.",
      dmg = "12 par tick, +8 de vie pour toi" },

    -- ===== CHINOIKE =====
    { cat = "Chinoike", name = "Pluie de sang", key = "", id = "chinoike_pluie", icone = "ui/icon/chinoike_zone_de_sang.png", court = "Pluie",
      desc = "Une pluie de sang s'abat sur l'endroit que tu vises pendant 8 secondes : tout ennemi qui reste dessous est blessé et ralenti. Coûte 35 de chakra.",
      dmg = "8 par tick (toutes les 0,5 s)" },

    -- ===== ARMES =====
    { cat = "Armes", name = "Zabuza", key = "Clic gauche / droit",
      desc = "Kubikiribocho. Clic gauche pour trancher, clic droit pour la double explosion." },
    { cat = "Armes", name = "Shibuki", key = "Clic gauche / droit",
      desc = "Épée explosive : coups au corps à corps et déclenchement des parchemins." },
    { cat = "Armes", name = "Kabutowari", key = "Clic gauche / droit",
      desc = "Hache et marteau : attaque lourde à deux temps." },
    { cat = "Armes", name = "Hiramekarei", key = "Clic gauche / droit",
      desc = "Double sabre de chakra." },
    { cat = "Armes", name = "Shuriken Fuma", key = "Clic gauche / droit",
      desc = "Coups de lame, et lancer du shuriken géant au clic droit." },

    -- ===== DÉPLACEMENT =====
    { cat = "Déplacement", name = "Course", key = "Maj (Shift)",
      desc = "Course normale, sans coût de chakra." },
    { cat = "Déplacement", name = "Course de chakra", key = "Maj x2",
      desc = "Double appui rapide sur Maj puis maintiens : course très rapide et saut renforcé. Consomme du chakra et s'arrête quand la jauge est vide.",
      dmg = "18 chakra par seconde" },

    -- ===== DIVERS =====
    { cat = "Divers", name = "Caméra 3e personne", key = KEY_V,
      desc = "Bascule la vue devant / derrière le personnage." },
    { cat = "Divers", name = "Menu / inventaire", key = KEY_F4,
      desc = "Ouvre ton menu personnel." },
    { cat = "Divers", name = "Techniques et barre", key = KEY_F2,
      desc = "Ouvre ce menu. Les techniques se lancent uniquement avec les touches 1 à 6 de la barre." },
}

-- Accès pour la barre de techniques (cl_skillbar.lua)
local parId = {}
for _, t in ipairs(TECHNIQUES) do
    if t.id then parId[t.id] = t end
end

NA_TechniquesListe = TECHNIQUES
function NA_TechniqueParId(id)
    return parId[id]
end

----------------------------------------------------------
-- Apparence
----------------------------------------------------------
local COL_BG      = Color(18, 18, 22, 250)
local COL_PANEL   = Color(30, 30, 36)
local COL_PANEL_2 = Color(40, 40, 48)
local COL_SELECT  = Color(60, 52, 40)
local COL_ACCENT  = Color(255, 128, 32)
local COL_TEXT    = Color(235, 235, 235)
local COL_DIM     = Color(150, 150, 160)
local COL_OK      = Color(120, 220, 120)

surface.CreateFont("NA.Tech.Title", { font = "Roboto", size = 28, weight = 700 })
surface.CreateFont("NA.Tech.Cat", { font = "Roboto", size = 19, weight = 600 })
surface.CreateFont("NA.Tech.Name", { font = "Roboto", size = 21, weight = 600 })
surface.CreateFont("NA.Tech.Desc", { font = "Roboto", size = 17, weight = 400 })
surface.CreateFont("NA.Tech.Key", { font = "Roboto", size = 17, weight = 700 })

local function KeyLabel(key)
    if isstring(key) then return key end
    local name = input.GetKeyName(key)
    return name and string.upper(name) or "?"
end

local function Categories()
    local order, seen = {}, {}
    for _, t in ipairs(TECHNIQUES) do
        if not seen[t.cat] then
            seen[t.cat] = true
            order[#order + 1] = t.cat
        end
    end
    return order
end

-- Emplacement de la barre où se trouve une technique (ou nil)
local function EmplacementDe(id)
    if not NA_SkillBar or not id then return nil end
    for i = 1, NA_SkillBar.NB do
        if NA_SkillBar.Get(i) == id then return i end
    end
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local frame
local selection -- id de la technique choisie pour être équipée

local function Open()
    if IsValid(frame) then
        frame:Remove()
        return
    end

    selection = nil

    local w = math.min(ScrW() * 0.75, 960)
    local h = math.min(ScrH() * 0.85, 740)

    frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()
    frame.Paint = function(pan, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, COL_BG)
        draw.RoundedBox(0, 0, 46, pw, 2, COL_ACCENT)
        draw.SimpleText("ATTAQUES ET TECHNIQUES", "NA.Tech.Title", 20, 23, COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("")
    close:SetSize(32, 32)
    close:SetPos(w - 42, 8)
    close.Paint = function(pan, pw, ph)
        draw.SimpleText("X", "NA.Tech.Name", pw / 2, ph / 2,
            pan:IsHovered() and COL_ACCENT or COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() frame:Remove() end

    -- Colonne des catégories
    local side = vgui.Create("DPanel", frame)
    side:Dock(LEFT)
    side:DockMargin(14, 58, 10, 14)
    side:SetWide(160)
    side.Paint = function(pan, pw, ph)
        draw.RoundedBox(6, 0, 0, pw, ph, COL_PANEL)
    end

    ------------------------------------------------------
    -- Zone d'équipement : les 6 emplacements de la barre
    ------------------------------------------------------
    local equip = vgui.Create("DPanel", frame)
    equip:Dock(TOP)
    equip:DockMargin(0, 58, 14, 10)
    equip:SetTall(122)
    equip.Paint = function(pan, pw, ph)
        draw.RoundedBox(6, 0, 0, pw, ph, COL_PANEL)
        local txt = selection
            and ("Choisis un emplacement pour : " .. (parId[selection] and parId[selection].name or selection))
            or "BARRE DE TECHNIQUES  —  clique sur une technique puis sur un emplacement  •  clic droit : vider"
        draw.SimpleText(txt, "NA.Tech.Desc", 12, 14, selection and COL_ACCENT or COL_DIM, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local rangee = vgui.Create("DPanel", equip)
    rangee:Dock(FILL)
    rangee:DockMargin(10, 28, 10, 8)
    rangee.Paint = function() end

    local TAILLE_SLOT = 80
    for i = 1, (NA_SkillBar and NA_SkillBar.NB or 6) do
        local slot = vgui.Create("DButton", rangee)
        slot:SetText("")
        slot:SetSize(TAILLE_SLOT, TAILLE_SLOT)
        slot:Dock(LEFT)
        slot:DockMargin(0, 0, 12, 0)
        slot:SetWide(TAILLE_SLOT)

        slot.Paint = function(pan, pw, ph)
            if not NA_SkillBar then return end
            local survol = pan:IsHovered()
            local alpha = (selection and not survol) and 200 or 255
            NA_SkillBar.DessinerEmplacement(0, 0, math.min(pw, ph), i, NA_SkillBar.Get(i), alpha)
            if survol and selection then
                surface.SetDrawColor(COL_ACCENT)
                surface.DrawOutlinedRect(0, 0, pw, ph, 2)
            end
        end

        slot.DoClick = function()
            if not NA_SkillBar then return end
            if selection then
                NA_SkillBar.Equiper(i, selection)
                selection = nil
                if IsValid(frame) and frame.Rafraichir then frame.Rafraichir() end
            end
        end

        slot.DoRightClick = function()
            if not NA_SkillBar or not NA_SkillBar.Get(i) then return end
            NA_SkillBar.Vider(i)
            if IsValid(frame) and frame.Rafraichir then frame.Rafraichir() end
        end

        slot:SetTooltip("Emplacement " .. i .. " (touche " .. i .. ")")
    end

    ------------------------------------------------------
    -- Liste des techniques
    ------------------------------------------------------
    local content = vgui.Create("DScrollPanel", frame)
    content:Dock(FILL)
    content:DockMargin(0, 0, 14, 14)

    local bar = content:GetVBar()
    bar:SetWide(6)
    bar.Paint = function() end
    bar.btnUp.Paint = function() end
    bar.btnDown.Paint = function() end
    bar.btnGrip.Paint = function(pan, pw, ph)
        draw.RoundedBox(3, 0, 0, pw, ph, COL_ACCENT)
    end

    local current = "Tout"
    local search = ""
    local Refresh

    local function MenuEquiper(tech)
        local m = DermaMenu()
        for i = 1, NA_SkillBar.NB do
            local occupe = NA_SkillBar.Get(i)
            local label = "Équiper dans l'emplacement " .. i
            if occupe and parId[occupe] then label = label .. "  (remplace " .. parId[occupe].name .. ")" end
            m:AddOption(label, function()
                NA_SkillBar.Equiper(i, tech.id)
                Refresh()
            end)
        end
        local deja = EmplacementDe(tech.id)
        if deja then
            m:AddSpacer()
            m:AddOption("Retirer de la barre", function()
                NA_SkillBar.Vider(deja)
                Refresh()
            end)
        end
        m:Open()
    end

    local function BuildCard(parent, tech)
        local equipable = tech.id ~= nil and NA_Cast and NA_Cast[tech.id] ~= nil

        local card = vgui.Create("DPanel", parent)
        card:Dock(TOP)
        card:DockMargin(0, 0, 0, 8)
        card:DockPadding(14, 10, 14, 10)
        if equipable then card:SetCursor("hand") end

        card.Paint = function(pan, w2, h2)
            local choisie = equipable and selection == tech.id
            draw.RoundedBox(6, 0, 0, w2, h2, choisie and COL_SELECT or COL_PANEL_2)
            surface.SetDrawColor(choisie and COL_TEXT or COL_ACCENT)
            surface.DrawRect(0, 0, 3, h2)
            if equipable and pan:IsHovered() and not choisie then
                surface.SetDrawColor(255, 128, 32, 60)
                surface.DrawOutlinedRect(0, 0, w2, h2, 1)
            end
        end

        if equipable then
            card.OnMousePressed = function(pan, code)
                if code == MOUSE_LEFT then
                    selection = (selection == tech.id) and nil or tech.id
                    surface.PlaySound("ui/buttonclick.wav")
                elseif code == MOUSE_RIGHT then
                    MenuEquiper(tech)
                end
            end
        end

        -- icône de la technique, à gauche de la carte
        local icone = tech.id and NA_SkillBar and NA_SkillBar.Icone(tech.id)
        if icone then
            local img = vgui.Create("DPanel", card)
            img:Dock(LEFT)
            img:DockMargin(0, 0, 12, 0)
            img:SetWide(56)
            img:SetMouseInputEnabled(false)
            img.Paint = function(pan, pw, ph)
                surface.SetMaterial(icone)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(0, 0, 56, 56)
            end
        end

        local header = vgui.Create("DPanel", card)
        header:Dock(TOP)
        header:SetTall(26)
        header:SetMouseInputEnabled(false)
        header.Paint = function() end

        local name = vgui.Create("DLabel", header)
        name:Dock(LEFT)
        name:SetFont("NA.Tech.Name")
        name:SetTextColor(COL_TEXT)
        name:SetText(tech.name)
        name:SizeToContents()

        -- pastille de touche, alignée à droite (masquée si la technique ne se lance que par la barre)
        if not equipable or NA_TouchesDirectes() then
            local keyText = KeyLabel(tech.key)
            surface.SetFont("NA.Tech.Key")
            local kw = surface.GetTextSize(keyText) + 20

            local keyTag = vgui.Create("DPanel", header)
            keyTag:Dock(RIGHT)
            keyTag:SetWide(kw)
            keyTag.Paint = function(pan, w2, h2)
                draw.RoundedBox(4, 0, 3, w2, h2 - 6, COL_ACCENT)
                draw.SimpleText(keyText, "NA.Tech.Key", w2 / 2, h2 / 2, Color(20, 20, 20), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- état dans la barre
        if equipable then
            local slotNum = EmplacementDe(tech.id)
            local etat = vgui.Create("DLabel", header)
            etat:Dock(RIGHT)
            etat:DockMargin(0, 0, 10, 0)
            etat:SetFont("NA.Tech.Desc")
            etat:SetTextColor(slotNum and COL_OK or COL_DIM)
            etat:SetText(slotNum and ("Équipée : touche " .. slotNum) or "Équipable")
            etat:SizeToContents()
        end

        local desc = vgui.Create("DLabel", card)
        desc:Dock(TOP)
        desc:DockMargin(0, 4, 0, 0)
        desc:SetFont("NA.Tech.Desc")
        desc:SetTextColor(COL_DIM)
        desc:SetWrap(true)
        desc:SetAutoStretchVertical(true)
        desc:SetText(tech.desc or "")

        local extra = {}
        if tech.dmg then extra[#extra + 1] = "Dégâts : " .. tech.dmg end
        if tech.cd then extra[#extra + 1] = "Recharge : " .. tech.cd .. " s" end

        local infoTall = 0
        if #extra > 0 then
            local info = vgui.Create("DLabel", card)
            info:Dock(TOP)
            info:DockMargin(0, 4, 0, 0)
            info:SetFont("NA.Tech.Desc")
            info:SetTextColor(COL_ACCENT)
            info:SetText(table.concat(extra, "   •   "))
            info:SetTall(20)
            infoTall = 24
        end

        -- hauteur : le libellé s'étire tout seul, on l'attend une frame
        card:SetTall(80 + infoTall)
        card.Think = function(pan)
            local want = 26 + 4 + desc:GetTall() + infoTall + 20
            if math.abs(pan:GetTall() - want) > 1 then
                pan:SetTall(want)
            end
        end

        return card
    end

    Refresh = function()
        local scroll = content:GetVBar():GetScroll()
        content:Clear()
        local shown = 0
        for _, tech in ipairs(TECHNIQUES) do
            local okCat = (current == "Tout") or (tech.cat == current)
            local text = string.lower(tech.name .. " " .. (tech.desc or "") .. " " .. tech.cat)
            local okSearch = search == "" or string.find(text, search, 1, true) ~= nil
            if okCat and okSearch then
                BuildCard(content, tech)
                shown = shown + 1
            end
        end

        if shown == 0 then
            local empty = vgui.Create("DLabel", content)
            empty:Dock(TOP)
            empty:SetFont("NA.Tech.Desc")
            empty:SetTextColor(COL_DIM)
            empty:SetText("Aucune technique ne correspond.")
        end

        -- garde la position de défilement après une modification
        timer.Simple(0, function()
            if IsValid(content) then content:GetVBar():SetScroll(scroll) end
        end)
    end
    frame.Rafraichir = Refresh

    -- Barre de recherche
    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(w - 254, 12)
    entry:SetSize(200, 26)
    entry:SetPlaceholderText("Rechercher...")
    entry:SetUpdateOnType(true)
    entry.OnValueChange = function(pan, val)
        search = string.lower(val or "")
        Refresh()
    end

    local function AddCatButton(label)
        local btn = vgui.Create("DButton", side)
        btn:Dock(TOP)
        btn:DockMargin(8, 8, 8, 0)
        btn:SetTall(30)
        btn:SetText("")
        btn.Paint = function(pan, pw, ph)
            local active = (current == label)
            draw.RoundedBox(4, 0, 0, pw, ph, active and COL_ACCENT or COL_PANEL_2)
            draw.SimpleText(label, "NA.Tech.Cat", 10, ph / 2,
                active and Color(20, 20, 20) or COL_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            current = label
            Refresh()
        end
    end

    AddCatButton("Tout")
    for _, cat in ipairs(Categories()) do
        AddCatButton(cat)
    end

    Refresh()
end

concommand.Add("attaques", Open)
concommand.Add("techniques", Open)

----------------------------------------------------------
-- Touche d'ouverture
----------------------------------------------------------
local wasDown = false

hook.Add("Think", "NA_TechniquesUI_Key", function()
    -- la fenêtre ouverte capte le clavier : on laisse quand même F2 la refermer
    if (vgui.GetKeyboardFocus() and not IsValid(frame)) or gui.IsGameUIVisible() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(OPEN_KEY)
    if down and not wasDown then
        Open()
    end
    wasDown = down
end)
