--========================================================
-- ÉDITEUR DE PLACEMENT D'ARME (CLIENT)
--
--   Commande : na_arme_placer [classe]   (sans argument : l'arme en main, ou la 1re arme Naruto)
--
--   Règle EN DIRECT, sur ton personnage vu de face / de dos :
--     - Main droite / Main gauche : SWEP.MainDroite / SWEP.MainGauche
--     - Dos                       : SWEP.Dos
--   "Copier le code" met dans le presse-papier les lignes à coller dans
--   lua/weapons/<arme>/shared.lua (et les affiche dans la console).
--
--   Le réglage du dos ne remplace pas celui du menu inventaire des joueurs :
--   c'est l'outil du créateur de l'arme.
--========================================================

-- Même style que l'éditeur de placement du menu F4 (cl_monmenu.lua)
local BORDURE = Color(90, 60, 45, 255)
local PARCHEMIN = Color(236, 222, 190, 250)
local PANNEAU = Color(214, 197, 160, 255)
local ORANGE  = Color(165, 45, 40)      -- rouge des titres (C_ROUGE)
local TEXTE   = Color(74, 52, 40)       -- C_TEXTE
local DOUX    = Color(125, 100, 80)     -- C_TEXTE_DOUX

-- polices du menu F4 (créées par cl_monmenu.lua)
local F_TITRE, F_TEXTE, F_PETIT = "NA.Inv.Texte", "NA.Inv.Petit", "NA.Inv.Petit"
local function CreerPolices() end

local fenetre, fond

-- Os proposés pour le dos : du bassin jusqu'en haut de la colonne
local OS_DOS = {
    ["ValveBiped.Bip01_Pelvis"] = true,
    ["ValveBiped.Bip01_Spine"] = true,
    ["ValveBiped.Bip01_Spine1"] = true,
    ["ValveBiped.Bip01_Spine2"] = true,
    ["ValveBiped.Bip01_Spine4"] = true,
    ["ValveBiped.Bip01_UpperChest"] = true,
}
local vue = { actif = false, angle = 0, pitch = 0, distance = 90 }

----------------------------------------------------------
-- Caméra : orbite autour du personnage tant que l'éditeur est ouvert
----------------------------------------------------------
hook.Add("ShouldDrawLocalPlayer", "NA_ArmePlacer", function()
    if vue.actif then return true end
end)

hook.Add("CalcView", "NA_ArmePlacer", function(ply, _, _, fov)
    if not vue.actif or not IsValid(ply) then return end
    local centre = ply:GetPos() + Vector(0, 0, 45)
    local dir = Angle(-vue.pitch, ply:GetAngles().y + vue.angle, 0):Forward()
    local cam = centre + dir * vue.distance
    return { origin = cam, angles = (centre - cam):Angle(), fov = fov, drawviewer = true }
end)

-- Pas de tir / de coup pendant le réglage
hook.Add("StartCommand", "NA_ArmePlacer", function(ply, cmd)
    if vue.actif and ply == LocalPlayer() then cmd:RemoveKey(IN_ATTACK) cmd:RemoveKey(IN_ATTACK2) end
end)

----------------------------------------------------------
-- Données d'une partie réglable
--   cfg       = table du SWEP (MainDroite / MainGauche / Dos)
--   rotation  = champ des angles ("rot" pour les mains, "ang" pour le dos)
----------------------------------------------------------
local function ListeParties(wep)
    local l = {}
    if wep.MainDroite then l[#l + 1] = { id = "MainDroite", nom = "Main droite", cfg = wep.MainDroite, rot = "rot" } end
    if wep.MainGauche then l[#l + 1] = { id = "MainGauche", nom = "Main gauche", cfg = wep.MainGauche, rot = "rot" } end
    if wep.Dos        then l[#l + 1] = { id = "Dos",        nom = "Dans le dos", cfg = wep.Dos,        rot = "ang", dos = true } end
    return l
end

local function ArmesNaruto(ply)
    local l = {}
    for _, w in ipairs(ply:GetWeapons()) do
        if w.NA_Arme and (w.MainDroite or w.Dos) then l[#l + 1] = w end
    end
    return l
end

local function FormaterCode(partie, v)
    local cfg = partie.cfg
    local f = function(n) return string.format("%g", math.Round(n, 2)) end
    local l = { "SWEP." .. partie.id .. " = {" }
    l[#l + 1] = string.format('    modele  = "%s",', cfg.modele)
    l[#l + 1] = string.format("    echelle = %s,", f(v.s))
    if partie.dos then
        local os = cfg.os
        if istable(os) then
            local t = {}
            for _, o in ipairs(os) do t[#t + 1] = '"' .. o .. '"' end
            l[#l + 1] = "    os      = { " .. table.concat(t, ", ") .. " },"
        elseif os then
            l[#l + 1] = string.format('    os      = "%s",', os)
        end
        l[#l + 1] = string.format("    pos     = Vector(%s, %s, %s),", f(v.x), f(v.y), f(v.z))
        l[#l + 1] = string.format("    ang     = Angle(%s, %s, %s),", f(v.p), f(v.ya), f(v.r))
        if cfg.mode then l[#l + 1] = string.format('    mode    = "%s",', cfg.mode) end
    else
        if isstring(cfg.os) then l[#l + 1] = string.format('    os      = "%s",', cfg.os) end
        l[#l + 1] = string.format("    pos     = Vector(%s, %s, %s),", f(v.x), f(v.y), f(v.z))
        l[#l + 1] = string.format("    rot     = Angle(%s, %s, %s),", f(v.p), f(v.ya), f(v.r))
    end
    l[#l + 1] = "}"
    return table.concat(l, "\n")
end

----------------------------------------------------------
-- Fenêtre
----------------------------------------------------------
local function Fermer()
    vue.actif = false
    NA_ArmePlacerActif = false
    NA_DosEdition = nil
    NA_EditeurCameraActive = false
    if IsValid(fond) then fond:Remove() end
    if IsValid(fenetre) then fenetre:Remove() end
    fenetre, fond = nil, nil
end

local function Ouvrir(classe, joueur)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if IsValid(fenetre) then Fermer() end
    CreerPolices()

    local armes = ArmesNaruto(ply)
    if joueur then   -- mode joueur (menu F4) : uniquement l'arme choisie, uniquement le dos
        local seule
        for _, w in ipairs(armes) do if w:GetClass() == classe then seule = w end end
        armes = { seule }
        if not seule or not seule.Dos then
            chat.AddText(ORANGE, "[Placer] ", TEXTE, "Cette arme ne se range pas dans le dos (ou n'est pas dans ton inventaire).")
            return
        end
    end
    if #armes == 0 then
        chat.AddText(ORANGE, "[Placer] ", TEXTE, "Aucune arme Naruto dans ton inventaire (donne-t'en une avec le menu Q).")
        return
    end

    local wep
    classe = classe or (IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass())
    for _, w in ipairs(armes) do if w:GetClass() == classe then wep = w break end end
    wep = wep or armes[1]

    local partie, parties
    local originaux = {}       -- valeurs de départ par arme/partie (pour "Annuler")
    local curseurs = {}
    local bloque = false       -- évite la boucle curseur -> valeur -> curseur

    vue.actif, vue.angle, vue.pitch, vue.distance = true, 0, 0, 90
    NA_ArmePlacerActif = true
    NA_EditeurCameraActive = true

    -- Calque plein écran derrière la fenêtre : clic gauche + glisser = tourner / monter, molette = zoom
    fond = vgui.Create("DPanel")
    fond:SetSize(ScrW(), ScrH())
    fond:SetKeyboardInputEnabled(false)
    fond:MakePopup()
    fond.Paint = function() end

    local W, H = 360, 560
    fenetre = vgui.Create("DFrame", fond)
    fenetre:SetSize(W, H)
    fenetre:SetPos(ScrW() - W - 30, ScrH() / 2 - H / 2)
    fenetre:SetTitle("")
    fenetre:ShowCloseButton(false)
    fenetre:SetDraggable(true)
    fenetre.OnRemove = function() if IsValid(fond) then fond:Remove() end vue.actif = false NA_ArmePlacerActif = false NA_DosEdition = nil NA_EditeurCameraActive = false end

    local titreFenetre = joueur and ("Placer : " .. (wep.PrintName or wep:GetClass())) or "Placement d'arme"
    fenetre.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, BORDURE)
        draw.RoundedBox(8, 2, 2, w - 4, h - 4, PARCHEMIN)
        draw.SimpleText(titreFenetre, F_TITRE, 16, 20, TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetDrawColor(ORANGE)
        surface.DrawRect(16, 36, w - 32, 2)
    end

    local croix = vgui.Create("DButton", fenetre)
    croix:SetText("")
    croix:SetPos(W - 40, 4) croix:SetSize(28, 28)
    croix.Paint = function(p, w, h)
        draw.SimpleText("✕", F_TEXTE, w / 2, h / 2, p:IsHovered() and ORANGE or DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    croix.DoClick = function()
        Fermer()
        if joueur then timer.Simple(0, function() RunConsoleCommand("mon_menu") end) end
    end

    local corps = vgui.Create("DPanel", fenetre)
    corps:Dock(FILL)
    corps:DockMargin(8, 34, 8, 8)
    corps.Paint = function() end

    -- Choix de l'arme
    local choixArme = vgui.Create("DComboBox", corps)
    choixArme:Dock(TOP)
    choixArme:SetTall(26)
    choixArme:SetFont(F_TEXTE)
    choixArme:SetTextColor(TEXTE)
    choixArme.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, PANNEAU) end
    for _, w in ipairs(armes) do
        choixArme:AddChoice(w.PrintName or w:GetClass(), w:GetClass(), w == wep)
    end

    if joueur then choixArme:SetVisible(false) end   -- une seule arme : pas de liste

    -- Onglets (main droite / main gauche / dos)
    local barre = vgui.Create("DPanel", corps)
    barre:Dock(TOP)
    barre:DockMargin(0, 8, 0, 4)
    barre:SetTall(32)
    barre.Paint = function() end

    -- Os d'attache
    local Appliquer
    local osChoisi          -- nil = os par défaut de l'arme
    local choixOs = vgui.Create("DComboBox", corps)
    choixOs:Dock(TOP)
    choixOs:DockMargin(0, 4, 0, 0)
    choixOs:SetTall(26)
    choixOs:SetFont(F_PETIT)
    choixOs:SetTextColor(TEXTE)
    choixOs.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, PANNEAU) end
    local nomsOs = {}
    for i = 0, ply:GetBoneCount() - 1 do
        local n = ply:GetBoneName(i)
        if n and OS_DOS[n] then nomsOs[#nomsOs + 1] = n end
    end
    local listeEnCours = false
    local function ChoisirOsListe(os)
        listeEnCours = true
        choixOs:Clear()
        choixOs:AddChoice("Os : (par défaut)", "", os == nil)
        for _, n in ipairs(nomsOs) do
            choixOs:AddChoice("Os : " .. string.sub(n, 18), n, n == os)
        end
        listeEnCours = false
    end
    ChoisirOsListe(nil)
    choixOs.OnSelect = function(_, _, _, donnee)
        if listeEnCours then return end
        osChoisi = (donnee ~= "" and donnee) or nil
        -- l'arme se place directement sur le nouvel os (décalage et rotation à zéro), puis on ajuste
        if osChoisi then
            bloque = true
            curseurs.x:SetValue(0) curseurs.y:SetValue(0) curseurs.z:SetValue(0)
            curseurs.p:SetValue(0) curseurs.ya:SetValue(0) curseurs.r:SetValue(0)
            bloque = false
        end
        Appliquer()
    end

    local function Titre(texte)
        local l = vgui.Create("DLabel", corps)
        l:Dock(TOP)
        l:DockMargin(2, 8, 0, 2)
        l:SetFont(F_PETIT)
        l:SetTextColor(ORANGE)
        l:SetText(texte)
        l:SizeToContents()
    end


    local function Curseur(cle, texte, mini, maxi, dec)
        local c = vgui.Create("NA_NumSlider", corps)
        c:Dock(TOP)
        c:DockMargin(2, 0, 2, 0)
        c:SetTall(24)
        c:SetText(texte)
        c:SetMinMax(mini, maxi)
        c:SetDecimals(dec)
        c.Label:SetTextColor(TEXTE)
        c.Label:SetFont(F_PETIT)
        c.OnValueChanged = function() if not bloque then Appliquer() end end
        curseurs[cle] = c
        return c
    end

    Titre("POSITION")
    Curseur("x", "X  avant / arrière", -50, 50, 1)
    Curseur("y", "Y  droite / gauche", -50, 50, 1)
    Curseur("z", "Z  haut / bas", -50, 50, 1)
    Titre("ROTATION")
    Curseur("p", "Tangage", -180, 180, 0)
    Curseur("ya", "Lacet", -180, 180, 0)
    Curseur("r", "Roulis", -180, 180, 0)
    Titre("TAILLE")
    Curseur("s", "Échelle", 0.1, 3, 2)

    Titre("CAMÉRA")
    local cv = vgui.Create("NA_NumSlider", corps)
    cv:Dock(TOP) cv:DockMargin(2, 0, 2, 0) cv:SetTall(24)
    cv:SetText("Vue (tourner)") cv:SetMinMax(-180, 180) cv:SetDecimals(0) cv:SetValue(0)
    cv.Label:SetTextColor(TEXTE) cv.Label:SetFont(F_PETIT)
    cv.OnValueChanged = function(_, v) vue.angle = v end
    local cd = vgui.Create("NA_NumSlider", corps)
    cd:Dock(TOP) cd:DockMargin(2, 0, 2, 0) cd:SetTall(24)
    cd:SetText("Zoom") cd:SetMinMax(25, 200) cd:SetDecimals(0) cd:SetValue(vue.distance)
    cd.Label:SetTextColor(TEXTE) cd.Label:SetFont(F_PETIT)
    cd.OnValueChanged = function(_, v) vue.distance = v end

    local glisse, dernierX, dernierY
    fond.OnMousePressed = function(_, bouton)
        if bouton ~= MOUSE_LEFT and bouton ~= MOUSE_RIGHT then return end
        glisse = true
        dernierX, dernierY = gui.MousePos()
        fond:MouseCapture(true)
    end
    fond.OnMouseReleased = function() glisse = false fond:MouseCapture(false) end
    fond.OnCursorMoved = function()
        if not glisse then return end
        local x, y = gui.MousePos()
        cv:SetValue(math.NormalizeAngle(vue.angle - (x - dernierX) * 0.4))
        vue.pitch = math.Clamp(vue.pitch + (y - dernierY) * 0.3, -80, 80)
        dernierX, dernierY = x, y
    end
    fond.OnMouseWheeled = function(_, delta)
        cd:SetValue(math.Clamp(vue.distance - delta * 6, 25, 200))
    end

    local pied = vgui.Create("DLabel", corps)
    pied:Dock(BOTTOM)
    pied:SetTall(20)
    pied:SetFont(F_PETIT)
    pied:SetTextColor(DOUX)
    pied:SetText("")

    ------------------------------------------------------
    -- Valeurs <-> arme
    ------------------------------------------------------
    local function Lire()
        return {
            x = curseurs.x:GetValue(), y = curseurs.y:GetValue(), z = curseurs.z:GetValue(),
            p = curseurs.p:GetValue(), ya = curseurs.ya:GetValue(), r = curseurs.r:GetValue(),
            s = curseurs.s:GetValue(),
        }
    end

    local function Ecrire(cfg, v, rot)
        cfg.pos = Vector(v.x, v.y, v.z)
        cfg[rot] = Angle(v.p, v.ya, v.r)
        cfg.echelle = v.s
    end

    Appliquer = function()
        if not partie or not IsValid(wep) then return end
        local v = Lire()
        if not joueur then
            Ecrire(partie.cfg, v, partie.rot)   -- mode joueur : on ne touche pas à l'arme elle-même
            partie.cfg.os = osChoisi or originaux[wep:GetClass() .. "/" .. partie.id].os
        end
        if partie.dos then
            -- aperçu dans le dos (naruto_arme_base.lua)
            NA_DosEdition = { classe = wep:GetClass(), pos = Vector(v.x, v.y, v.z), ang = Angle(v.p, v.ya, v.r), echelle = v.s, os = osChoisi }
        else
            NA_DosEdition = nil
            local m = partie.id == "MainDroite" and wep._ModeleDroite or wep._ModeleGauche
            if IsValid(m) then m:SetModelScale(v.s, 0) end
        end
    end

    local function Charger(p)
        partie = p
        local cfg = p.cfg
        local cle = wep:GetClass() .. "/" .. p.id
        if not originaux[cle] then
            originaux[cle] = {
                pos = Vector(cfg.pos or vector_origin), rot = Angle(cfg[p.rot] or angle_zero), echelle = cfg.echelle or 1, os = cfg.os,
            }
        end
        local pos, ang, echelle = cfg.pos or vector_origin, cfg[p.rot] or angle_zero, cfg.echelle or 1
        local perso = joueur and NA_DosEpeeJoueur and NA_DosEpeeJoueur.get(wep:GetClass())
        if perso then pos, ang, echelle = Vector(perso.x, perso.y, perso.z), Angle(perso.p, perso.ya, perso.r), perso.s end
        -- os d'attache affiché : réglage du joueur, sinon celui de l'arme s'il est unique (texte)
        osChoisi = (joueur and perso and perso.o) or (not joueur and isstring(cfg.os) and cfg.os) or nil
        if osChoisi == "" then osChoisi = nil end
        ChoisirOsListe(osChoisi)
        choixOs:SetVisible(p.dos == true)   -- l'os ne se change que pour le dos
        corps:InvalidateLayout(true)
        bloque = true
        curseurs.x:SetValue(pos.x) curseurs.y:SetValue(pos.y) curseurs.z:SetValue(pos.z)
        curseurs.p:SetValue(ang.p) curseurs.ya:SetValue(ang.y) curseurs.r:SetValue(ang.r)
        curseurs.s:SetValue(echelle)
        bloque = false
        -- regarde le côté utile : de dos pour le dos, de face pour les mains
        cv:SetValue(p.dos and 180 or 0)
        Appliquer()
    end

    local function ConstruireOnglets()
        barre:Clear()
        parties = ListeParties(wep)
        if joueur then parties = { parties[#parties] } end
        local n = #parties
        local bw = (W - 20 - (n - 1) * 6) / n
        for i, p in ipairs(parties) do
            local b = vgui.Create("DButton", barre)
            b:SetText("")
            b:SetPos((i - 1) * (bw + 6), 0) b:SetSize(bw, 32)
            b.Paint = function(s, w, h)
                local actif = partie == p
                draw.RoundedBox(6, 0, 0, w, h, actif and ORANGE or (s:IsHovered() and Color(190, 172, 135) or PANNEAU))
                draw.SimpleText(p.nom, F_TEXTE, w / 2, h / 2, actif and color_white or TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function() Charger(p) end
        end
        Charger(parties[1])
    end

    choixArme.OnSelect = function(_, _, _, classeChoisie)
        for _, w in ipairs(armes) do if w:GetClass() == classeChoisie then wep = w end end
        NA_DosEdition = nil
        ConstruireOnglets()
    end

    ------------------------------------------------------
    -- Boutons du bas
    ------------------------------------------------------
    local function Bouton(texte, couleur, action)
        local b = vgui.Create("DButton", fenetre)
        b:SetText("")
        b.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and couleur or Color(couleur.r, couleur.g, couleur.b, 200))
            draw.SimpleText(texte, F_TEXTE, w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = action
        return b
    end

    local bas = vgui.Create("DPanel", fenetre)
    bas:Dock(BOTTOM)
    bas:DockMargin(12, 0, 12, 12)
    bas:SetTall(34)
    bas.Paint = function() end

    local bw = (W - 24 - 16) / 3
    local b1 = Bouton("Réinitialiser", Color(120, 100, 80), function()
        local o = originaux[wep:GetClass() .. "/" .. partie.id]
        if not o then return end
        if joueur and NA_DosEpeeJoueur then NA_DosEpeeJoueur.forget(wep:GetClass()) end
        osChoisi = isstring(o.os) and o.os or nil
        ChoisirOsListe(osChoisi)
        bloque = true
        curseurs.x:SetValue(o.pos.x) curseurs.y:SetValue(o.pos.y) curseurs.z:SetValue(o.pos.z)
        curseurs.p:SetValue(o.rot.p) curseurs.ya:SetValue(o.rot.y) curseurs.r:SetValue(o.rot.r)
        curseurs.s:SetValue(o.echelle)
        bloque = false
        Appliquer()
    end)
    b1:SetParent(bas) b1:SetPos(0, 0) b1:SetSize(bw, 34)

    local b2 = Bouton(joueur and "Valider" or "Copier le code", joueur and Color(70, 130, 70) or Color(70, 110, 160), function()
        if joueur then
            local v = Lire()
            NA_DosEpeeJoueur.save(wep:GetClass(), Vector(v.x, v.y, v.z), Angle(v.p, v.ya, v.r), v.s, osChoisi)
            Fermer()
            timer.Simple(0, function() RunConsoleCommand("mon_menu") end)
            return
        end
        local sorties = {}
        -- toutes les parties de l'arme, avec les valeurs actuelles
        for _, p in ipairs(ListeParties(wep)) do
            local cfg = p.cfg
            local pos, ang = cfg.pos or vector_origin, cfg[p.rot] or angle_zero
            sorties[#sorties + 1] = FormaterCode(p, { x = pos.x, y = pos.y, z = pos.z, p = ang.p, ya = ang.y, r = ang.r, s = cfg.echelle or 1 })
        end
        local code = table.concat(sorties, "\n\n")
        SetClipboardText(code)
        print("\n----- " .. wep:GetClass() .. " (lua/weapons/" .. wep:GetClass() .. "/shared.lua) -----\n" .. code .. "\n")
        pied:SetText("Code copié ! (aussi dans la console)")
        pied:SetTextColor(Color(60, 120, 60))
    end)
    b2:SetParent(bas) b2:SetPos(bw + 8, 0) b2:SetSize(bw, 34)

    local b3 = Bouton("Annuler", Color(150, 60, 50), function()
        if joueur then
            Fermer()
            timer.Simple(0, function() RunConsoleCommand("mon_menu") end)
            return
        end
        for cle, o in pairs(originaux) do
            local classeC, id = string.match(cle, "^(.-)/(.+)$")
            for _, w in ipairs(armes) do
                if w:GetClass() == classeC and w[id] then
                    w[id].pos = Vector(o.pos)
                    w[id][id == "Dos" and "ang" or "rot"] = Angle(o.rot)
                    w[id].echelle = o.echelle
                    w[id].os = o.os
                    local m = (id == "MainDroite" and w._ModeleDroite) or (id == "MainGauche" and w._ModeleGauche)
                    if IsValid(m) then m:SetModelScale(o.echelle, 0) end
                end
            end
        end
        Fermer()
    end)
    b3:SetParent(bas) b3:SetPos((bw + 8) * 2, 0) b3:SetSize(bw, 34)

    ConstruireOnglets()
    pied:SetText(joueur and "Glisse = tourner (tous sens), molette = zoom. Valide pour enregistrer." or "Glisse la souris pour tourner (tous sens), molette pour zoomer.")
end

concommand.Add("na_arme_placer", function(_, _, args) Ouvrir(args[1]) end)
concommand.Add("na_arme_placer_joueur", function(_, _, args) Ouvrir(args[1], true) end)
concommand.Add("na_arme_placer_fermer", Fermer)

hook.Add("OnScreenSizeChanged", "NA_ArmePlacer", CreerPolices)
