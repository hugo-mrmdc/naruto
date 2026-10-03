--========================================================
-- Paramètres (F1) : touches + champ de vision (CLIENT)
-- Enregistré dans garrysmod/data/naruto_parametres.txt.
-- NA_Touche(action) donne la touche (KEY_*) d'une action ; les autres fichiers
-- l'appellent à chaque test, donc un changement s'applique tout de suite.
--========================================================
local FICHIER = "naruto_parametres.txt"
local FOV_MIN, FOV_MAX = 60, 120

-- { id, nom, touche par défaut }
local ACTIONS = {
    { "slot1", "Technique 1", KEY_1 }, { "slot2", "Technique 2", KEY_2 }, { "slot3", "Technique 3", KEY_3 },
    { "slot4", "Technique 4", KEY_4 }, { "slot5", "Technique 5", KEY_5 }, { "slot6", "Technique 6", KEY_6 },
    { "barre",      "Changer de barre",         KEY_M },
    { "camera",     "Caméra devant / derrière", KEY_V },
    { "techniques", "Menu techniques",          KEY_F2 },
    { "inventaire", "Menu inventaire",          KEY_F4 },
    { "biblio",     "Bibliothèque",             KEY_F6 },
    { "special",    "Attaque spéciale (armes)", MOUSE_RIGHT },   -- lu par cl_touche_special.lua
}
local DEFAUT = {}
for _, a in ipairs(ACTIONS) do DEFAUT[a[1]] = a[3] end

local Reg = { touches = {}, fov = nil }   -- fov nil = celui du jeu
do
    local brut = file.Read(FICHIER, "DATA")
    local d = brut and util.JSONToTable(brut)
    if d then
        Reg.fov = tonumber(d.fov)
        for k, v in pairs(d.touches or {}) do
            if DEFAUT[k] then Reg.touches[k] = tonumber(v) end
        end
    end
end

local function Sauver() file.Write(FICHIER, util.TableToJSON(Reg)) end

function NA_Touche(action) return Reg.touches[action] or DEFAUT[action] end

local NOMS_SOURIS = { [MOUSE_RIGHT] = "CLIC DROIT", [MOUSE_MIDDLE] = "MOLETTE (clic)", [MOUSE_4] = "SOURIS 4", [MOUSE_5] = "SOURIS 5" }
local BOUTONS_SOURIS = { MOUSE_MIDDLE, MOUSE_4, MOUSE_5 }   -- clic gauche / droit restent réservés

-- la touche de l'action est-elle enfoncée ? (clavier ou souris)
function NA_ToucheBas(action)
    local k = NA_Touche(action)
    if k >= MOUSE_FIRST and k <= MOUSE_LAST then return input.IsMouseDown(k) end
    return input.IsKeyDown(k)
end

function NA_NomTouche(action)
    local k = NA_Touche(action)
    return NOMS_SOURIS[k] or string.upper(input.GetKeyName(k) or "?")
end

-- FOV personnalisé (renvoie celui du jeu tant que rien n'est réglé)
function NA_FovPerso(fovJeu) return Reg.fov or fovJeu end

----------------------------------------------------------
-- Menu
----------------------------------------------------------
local C_OR, C_FOND, C_DOUX = Color(232, 196, 120), Color(20, 14, 12, 245), Color(175, 155, 125)

surface.CreateFont("NA.Param.Titre", { font = "Roboto", size = 30, weight = 800 })
surface.CreateFont("NA.Param.Texte", { font = "Roboto", size = 18, weight = 600 })

local frame

local function Rang(parent, nom, h)
    local p = vgui.Create("DPanel", parent)
    p:Dock(TOP)
    p:DockMargin(0, 0, 8, 6)
    p:SetTall(h or 38)
    p.Paint = function(_, w, ht)
        draw.RoundedBox(6, 0, 0, w, ht, Color(40, 28, 22, 220))
        draw.SimpleText(nom, "NA.Param.Texte", 12, (h and h < 60) and ht / 2 or 20, C_OR, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return p
end

local function Bouton(parent, w)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:Dock(RIGHT)
    b:DockMargin(0, 5, 6, 5)
    b:SetWide(w)
    return b
end

local function Ouvrir()
    if IsValid(frame) then frame:Remove() return end
    if NA_FermerAutresMenus then NA_FermerAutresMenus("parametres") end

    frame = vgui.Create("DFrame")
    frame:SetSize(520, math.min(ScrH() - 80, 620))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(false)
    frame:MakePopup()
    frame.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C_OR)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, C_FOND)
        draw.SimpleText("PARAMÈTRES", "NA.Param.Titre", w / 2, 28, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    frame.OnKeyCodePressed = function(self, k)
        if k == KEY_F1 or k == KEY_ESCAPE then self:Remove() end
    end

    local fermer = vgui.Create("DButton", frame)
    fermer:SetText("")
    fermer:SetSize(28, 28)
    fermer:SetPos(frame:GetWide() - 38, 10)
    fermer.Paint = function(p, w, h)
        draw.SimpleText("X", "NA.Param.Texte", w / 2, h / 2, p:IsHovered() and color_white or C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    fermer.DoClick = function() frame:Remove() end

    local liste = vgui.Create("DScrollPanel", frame)
    liste:Dock(FILL)
    liste:DockMargin(14, 52, 6, 14)
    local vb = liste:GetVBar()
    vb:SetWide(6)
    vb.Paint = function() end
    vb.btnUp.Paint = function() end
    vb.btnDown.Paint = function() end
    vb.btnGrip.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(232, 196, 120, 120)) end

    -- ===== Champ de vision =====
    local fovJeu = GetConVar("fov_desired"):GetInt()
    local rFov = Rang(liste, "Champ de vision (FOV)", 76)
    local slider = vgui.Create("DNumSlider", rFov)
    slider:SetPos(12, 36)
    slider:SetSize(380, 30)
    slider:SetText("")
    slider:SetMinMax(FOV_MIN, FOV_MAX)
    slider:SetDecimals(0)
    slider:SetValue(Reg.fov or fovJeu)
    slider.OnValueChanged = function(_, v)
        Reg.fov = math.Round(v)
        Sauver()
    end
    local rf = vgui.Create("DButton", rFov)
    rf:SetText("")
    rf:SetPos(rFov:GetWide() > 0 and 0 or 0, 8)
    rf:SetSize(130, 24)
    rFov.PerformLayout = function(p, w) rf:SetPos(w - 140, 8) end
    rf.Paint = function(p, w, h)
        draw.RoundedBox(5, 0, 0, w, h, p:IsHovered() and Color(110, 60, 40) or Color(80, 45, 32))
        draw.SimpleText("Valeur du jeu", "NA.Param.Texte", w / 2, h / 2, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    rf.DoClick = function()
        slider:SetValue(fovJeu)   -- déclenche OnValueChanged
        Reg.fov = nil
        Sauver()
    end

    -- ===== Touches =====
    local attente   -- id en cours de saisie

    local function Assigner(id, k)
        attente = nil
        -- si une autre action avait déjà cette touche, on échange
        for _, o in ipairs(ACTIONS) do
            if o[1] ~= id and NA_Touche(o[1]) == k then Reg.touches[o[1]] = NA_Touche(id) end
        end
        Reg.touches[id] = k
        Sauver()
    end

    -- boutons de souris (ils ne passent pas par OnKeyCodePressed)
    local sourisAvant = {}
    frame.Think = function()
        for _, m in ipairs(BOUTONS_SOURIS) do
            local bas = input.IsMouseDown(m)
            if bas and not sourisAvant[m] and attente then Assigner(attente, m) end
            sourisAvant[m] = bas
        end
    end

    for _, a in ipairs(ACTIONS) do
        local id = a[1]
        local r = Rang(liste, a[2])

        local b = Bouton(r, 130)
        b.Paint = function(p, w, h)
            local ecoute = attente == id
            draw.RoundedBox(5, 0, 0, w, h, ecoute and Color(150, 90, 30) or (p:IsHovered() and Color(110, 60, 40) or Color(80, 45, 32)))
            draw.SimpleText(ecoute and "Touche / souris..." or NA_NomTouche(id), "NA.Param.Texte", w / 2, h / 2, C_OR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function(p) attente = id p:RequestFocus() end
        b.OnKeyCodePressed = function(_, k)
            if attente ~= id then
                if k == KEY_F1 then frame:Remove() end
                return
            end
            if k == KEY_ESCAPE then attente = nil return end
            Assigner(id, k)
        end

        local rz = Bouton(r, 30)
        rz:SetTooltip("Touche par défaut")
        rz.Paint = function(p, w, h)
            draw.SimpleText("R", "NA.Param.Texte", w / 2, h / 2, p:IsHovered() and color_white or C_DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        rz.DoClick = function()
            for _, o in ipairs(ACTIONS) do
                if o[1] ~= id and NA_Touche(o[1]) == DEFAUT[id] then Reg.touches[o[1]] = NA_Touche(id) end
            end
            Reg.touches[id] = DEFAUT[id]
            Sauver()
        end
    end
end

if NA_EnregistrerMenu then
    NA_EnregistrerMenu("parametres", function() if IsValid(frame) then frame:Remove() end end)
end

local avant = false
hook.Add("Think", "NA_Parametres_Touche", function()
    if (vgui.GetKeyboardFocus() and not IsValid(frame)) or gui.IsGameUIVisible() then
        avant = false
        return
    end
    local bas = input.IsKeyDown(KEY_F1)
    if bas and not avant then
        local ply = LocalPlayer()
        if not (IsValid(ply) and ply:IsTyping()) then Ouvrir() end
    end
    avant = bas
end)
