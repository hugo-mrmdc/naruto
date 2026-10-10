--========================================================
-- Menu d'équilibrage (PARTAGÉ serveur + client)
--
-- Ouvre avec la commande console : equilibrage   (ou !equilibrage dans le chat)
-- Réservé aux superadmins / à l'hôte d'une partie locale.
--
-- Modifie en direct les stats par niveau de _na_niveaux_techniques.lua
-- (dégâts, chakra, recharge, durée...) : on choisit une technique à gauche,
-- on change une case, Entrée pour valider. Les cases changées sont en orange.
-- Les changements sont enregistrés (garrysmod/data/na_equilibrage.json), envoyés à
-- tous les joueurs et gardés au redémarrage. "Réinitialiser" remet les valeurs du fichier.
-- Chargé APRÈS _na_niveaux_techniques.lua (le "z" dans le nom).
--========================================================

if SERVER then AddCSLuaFile() end

NA_EQUI = NA_EQUI or {}

local FICHIER = "na_equilibrage.json"

-- valeurs d'origine (fichier _na_niveaux_techniques.lua)
NA_EQUI.DEF = NA_EQUI.DEF or {}
if not next(NA_EQUI.DEF) then
    for id, t in pairs(NA_NIV_TECH) do NA_EQUI.DEF[id] = table.Copy(t) end
end
local DEF = NA_EQUI.DEF

-- changements : OV[id][tostring(niveau)][stat] = valeur
local OV = {}

--------------------------------------------------------
-- Armes (SWEP basés sur naruto_arme_base) : id = "arme:<classe>"
-- Colonnes : 1 à 8 = coups du combo, COL_FRAPPE = SWEP.Frappe, COL_SPECIAL = SWEP.Special
-- Seuls les nombres sont réglables. Chargées à InitPostEntity (les armes ne sont pas prêtes avant).
--------------------------------------------------------
NA_EQUI.COL_FRAPPE, NA_EQUI.COL_SPECIAL = 9, 10
local ARMES = NA_EQUI.ARMES or {}   -- classe -> { Combo, Frappe, Special } d'origine
NA_EQUI.ARMES = ARMES

local function Nombres(t)
    local r = {}
    for k, v in pairs(t or {}) do
        if isnumber(v) then r[k] = v end
    end
    return r
end

local function ChargerArmes()
    for _, w in ipairs(weapons.GetList()) do
        local st = weapons.GetStored(w.ClassName)
        if st and st.Base == "naruto_arme_base" and not ARMES[w.ClassName] then
            local P = { Combo = table.Copy(st.Combo or {}), Frappe = table.Copy(st.Frappe or {}), Special = table.Copy(st.Special) }
            ARMES[w.ClassName] = P
            local d = {}
            for i, coup in ipairs(P.Combo) do d[i] = Nombres(coup) end
            d[NA_EQUI.COL_FRAPPE] = Nombres(P.Frappe)
            if P.Special then d[NA_EQUI.COL_SPECIAL] = Nombres(P.Special) end
            DEF["arme:" .. w.ClassName] = d
            NA_NIV_TECH["arme:" .. w.ClassName] = table.Copy(d)   -- valeurs actuelles = celles d'origine
            NA_EQUI.NOMS_ARMES = NA_EQUI.NOMS_ARMES or {}
            NA_EQUI.NOMS_ARMES["arme:" .. w.ClassName] = st.PrintName or w.ClassName
        end
    end
end

-- Écrit les valeurs actuelles dans l'arme (modèle stocké + armes déjà en main)
local function AppliquerArme(id, cur)
    local classe = string.sub(id, 6)
    local P = ARMES[classe]
    if not P then return end
    local combo, frappe, special = table.Copy(P.Combo), table.Copy(P.Frappe), table.Copy(P.Special)
    for i, coup in ipairs(combo) do table.Merge(coup, cur[i] or {}) end
    table.Merge(frappe, cur[NA_EQUI.COL_FRAPPE] or {})
    if special then table.Merge(special, cur[NA_EQUI.COL_SPECIAL] or {}) end

    local function Poser(w)
        w.Combo, w.Frappe, w.Special = table.Copy(combo), table.Copy(frappe), special and table.Copy(special)
    end
    local st = weapons.GetStored(classe)
    if st then Poser(st) end
    for _, w in ipairs(ents.FindByClass(classe)) do Poser(w) end
end

local function Appliquer(id)
    if not DEF[id] then return end
    local t = table.Copy(DEF[id])
    for n, stats in pairs(OV[id] or {}) do
        n = tonumber(n)
        t[n] = t[n] or {}
        for stat, v in pairs(stats) do t[n][stat] = v end
    end
    NA_NIV_TECH[id] = t
    if string.sub(id, 1, 5) == "arme:" then AppliquerArme(id, t) end
end

-- une arme créée plus tard reprend les réglages (le modèle stocké est déjà à jour, ceci couvre les copies)
hook.Add("OnEntityCreated", "NA_Equi_Armes", function(ent)
    timer.Simple(0, function()
        if IsValid(ent) and ent:IsWeapon() and OV["arme:" .. ent:GetClass()] then Appliquer("arme:" .. ent:GetClass()) end
    end)
end)

hook.Add("InitPostEntity", "NA_Equi_Armes", function()
    ChargerArmes()
    for id in pairs(OV) do Appliquer(id) end
end)
if ents and #ents.GetAll() > 0 then ChargerArmes() end   -- lua_refresh en cours de partie

if SERVER then
    util.AddNetworkString("NA_Equi_Sync")
    util.AddNetworkString("NA_Equi_Set")
    util.AddNetworkString("NA_Equi_Reset")
    util.AddNetworkString("NA_Equi_Ouvrir")

    local function Autorise(ply)
        return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsListenServerHost() or game.SinglePlayer())
    end

    local function Envoyer(cible)
        local data = util.Compress(util.TableToJSON(OV))
        net.Start("NA_Equi_Sync")
        net.WriteUInt(#data, 32)
        net.WriteData(data, #data)
        if cible then net.Send(cible) else net.Broadcast() end
    end

    local function Sauver() file.Write(FICHIER, util.TableToJSON(OV)) end

    OV = util.JSONToTable(file.Read(FICHIER, "DATA") or "") or {}
    for id in pairs(OV) do Appliquer(id) end

    hook.Add("PlayerInitialSpawn", "NA_Equi_Sync", function(ply)
        timer.Simple(3, function() if IsValid(ply) then Envoyer(ply) end end)
    end)

    net.Receive("NA_Equi_Set", function(_, ply)
        if not Autorise(ply) then return end
        local id, n, stat, v = net.ReadString(), net.ReadUInt(4), net.ReadString(), net.ReadDouble()
        if not DEF[id] or n < 1 then return end

        -- la stat doit exister dans la technique / l'arme à ce niveau (pas de réglage inventé)
        local connue = false
        if string.sub(id, 1, 5) == "arme:" then
            connue = isnumber(DEF[id][n] and DEF[id][n][stat])
        elseif n <= NA_NIV.MAX then
            for k = 1, NA_NIV.MAX do
                if isnumber(DEF[id][k] and DEF[id][k][stat]) then connue = true break end
            end
        end
        if not connue then return end

        local cle = tostring(n)
        OV[id] = OV[id] or {}
        OV[id][cle] = OV[id][cle] or {}
        local d = DEF[id][n] and DEF[id][n][stat]
        OV[id][cle][stat] = (d ~= v) and v or nil   -- retour à l'origine = on oublie le changement
        if not next(OV[id][cle]) then OV[id][cle] = nil end
        if not next(OV[id]) then OV[id] = nil end

        Appliquer(id)
        Sauver()
        Envoyer()
    end)

    net.Receive("NA_Equi_Reset", function(_, ply)
        if not Autorise(ply) then return end
        local id = net.ReadString()
        if not DEF[id] then return end
        OV[id] = nil
        Appliquer(id)
        Sauver()
        Envoyer()
    end)

    local function Ouvrir(ply)
        if not Autorise(ply) then
            if IsValid(ply) then ply:ChatPrint("Tu n'as pas le droit d'ouvrir le menu d'équilibrage.") end
            return
        end
        net.Start("NA_Equi_Ouvrir")
        net.Send(ply)
    end

    concommand.Add("equilibrage", function(ply) Ouvrir(ply) end)

    hook.Add("PlayerSay", "NA_Equi_Chat", function(ply, texte)
        local cmd = string.lower(string.Trim(texte))
        if cmd ~= "!equilibrage" and cmd ~= "/equilibrage" then return end
        Ouvrir(ply)
        return ""
    end)
    return
end

--========================================================
-- CLIENT
--========================================================
net.Receive("NA_Equi_Sync", function()
    local len = net.ReadUInt(32)
    local nouveau = util.JSONToTable(util.Decompress(net.ReadData(len)) or "") or {}
    local touches = table.Copy(OV)
    OV = nouveau
    for id in pairs(nouveau) do touches[id] = true end
    for id in pairs(touches) do Appliquer(id) end

    local f = NA_EQUI.Frame
    if IsValid(f) and f.Remplir then f:Remplir() end
end)

-- Valeur d'une stat à un niveau dans une table de niveaux (un niveau sans la stat garde celle d'avant)
local function Eff(t, stat, n, arme)
    if arme then return t and t[n] and t[n][stat] end   -- une arme : pas d'héritage entre colonnes
    for k = n, 1, -1 do
        local v = t and t[k] and t[k][stat]
        if v ~= nil then return v end
    end
end

local function EstArme(id) return string.sub(id, 1, 5) == "arme:" end

-- ordre d'affichage des stats = celui de NA_NIV.NOMS
local NOM, RANG = {}, {}
for i, s in ipairs(NA_NIV.NOMS or {}) do NOM[s[1]] = s[2]; RANG[s[1]] = i end

-- noms des stats d'arme (prioritaires sur ceux des techniques : "delai" n'y veut pas dire la même chose)
local NOM_ARME = {
    degats = "DÉGÂTS", duree = "DURÉE (COUP SUIVANT)", delai = "DÉLAI AVANT LE COUP", dureeFrappe = "DURÉE DE LA FRAPPE",
    vitesseAnim = "VITESSE ANIMATION", delaiTouche = "DÉLAI PARTICULE", coups = "TOUCHES PAR COUP", intervalle = "INTERVALLE",
    portee = "PORTÉE", largeur = "LARGEUR", hauteur = "HAUTEUR", recul = "RECUL", reculHaut = "RECUL (HAUT)", sons = "SONS",
    recharge = "RECHARGE", rayon = "RAYON", vitesse = "VITESSE", dureeAller = "DURÉE ALLER", dureeVie = "DURÉE DE VIE",
    delaiSon = "DÉLAI SON", delaiLancer = "DÉLAI LANCER",
}
-- Onglets = ceux du menu des techniques (F2) ; catégorie d'une technique = préfixe de sa lignée
local ONGLETS = {
    { nom = "TOUT" },
    { nom = "NATURES",        cats = { "Katon", "Suiton", "Futon", "Raiton", "Doton" } },
    { nom = "KEKKEI GENKAI",  cats = { "Mokuton", "Jinton", "Kiminari", "Jiton", "Inkuton", "Bakuton", "Futton", "Hyoton", "Shoton" } },
    { nom = "CLAN",           cats = { "Salamandre", "Fuma", "Kami", "Kaguya", "Chinoike", "Hyuga", "Senju", "Uchiha" } },
    { nom = "ARTS NINJA",     cats = { "Taijutsu", "Kenjutsu", "Divers" } },
    { nom = "ARMES",          cats = { "Armes" } },
}

local CAT = {}   -- id -> catégorie
for _, ligne in ipairs(NA_NIV.LIGNEES or {}) do
    local pre = string.match(ligne[1], "^([^_]+)")
    for _, id in ipairs(ligne) do CAT[id] = string.upper(string.sub(pre, 1, 1)) .. string.sub(pre, 2) end
end
local function Categorie(id) return EstArme(id) and "Armes" or CAT[id] or "Divers" end

local function NomStat(stat, arme) return (arme and NOM_ARME[stat]) or NOM[stat] or string.upper(stat) end
local function NomColonne(n)
    if n == NA_EQUI.COL_FRAPPE then return "FRAPPE" end
    if n == NA_EQUI.COL_SPECIAL then return "SPÉCIAL" end
    return "COUP " .. n
end

local OR, CREME, DOUX = Color(232, 196, 120), Color(240, 226, 196), Color(175, 155, 125)
local FOND, PANNEAU, CASE = Color(14, 10, 10, 245), Color(26, 19, 18, 255), Color(8, 6, 6, 255)
local CHANGE = Color(255, 150, 60)

surface.CreateFont("NA.Equi.Titre", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("NA.Equi.Texte", { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("NA.Equi.Petit", { font = "Roboto", size = 14, weight = 700, extended = true })

local function StyleScroll(sp)
    local vb = sp:GetVBar()
    vb:SetWide(6)
    vb.Paint = function() end
    vb.btnUp.Paint, vb.btnDown.Paint = function() end, function() end
    vb.btnGrip.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(OR.r, OR.g, OR.b, 130)) end
end

local function Ouvrir()
    if IsValid(NA_EQUI.Frame) then NA_EQUI.Frame:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(math.min(ScrW() - 40, 1100), math.min(ScrH() - 40, 700))
    f:Center()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:DockPadding(16, 64, 16, 16)
    f:MakePopup()
    NA_EQUI.Frame = f
    f.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, FOND)
        surface.SetDrawColor(OR.r, OR.g, OR.b, 150)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("ÉQUILIBRAGE", "NA.Equi.Titre", 20, 14, OR)
        draw.SimpleText("Entrée pour valider une case  •  orange = modifié", "NA.Equi.Petit", w - 64, 24, DOUX, TEXT_ALIGN_RIGHT)
        surface.SetDrawColor(OR.r, OR.g, OR.b, 60)
        surface.DrawRect(16, 52, w - 32, 1)
    end

    local x = vgui.Create("DButton", f)
    x:SetText("")
    x:SetPos(f:GetWide() - 40, 12)
    x:SetSize(26, 26)
    x.DoClick = function() f:Remove() end
    x.Paint = function(s, w, h)
        draw.SimpleText("✕", "NA.Equi.Texte", w / 2, h / 2, s:IsHovered() and OR or DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- onglets
    f.Onglet = 1
    local barre = vgui.Create("DPanel", f)
    barre:Dock(TOP)
    barre:SetTall(30)
    barre:DockMargin(0, 0, 0, 8)
    barre:SetPaintBackground(false)
    for i, o in ipairs(ONGLETS) do
        local b = vgui.Create("DButton", barre)
        b:Dock(LEFT)
        b:SetWide(150)
        b:DockMargin(0, 0, 6, 0)
        b:SetText("")
        b.Paint = function(s, w, h)
            local actif = f.Onglet == i
            draw.RoundedBox(6, 0, 0, w, h, actif and Color(OR.r, OR.g, OR.b, 45) or (s:IsHovered() and Color(255, 255, 255, 14) or PANNEAU))
            surface.SetDrawColor(OR.r, OR.g, OR.b, actif and 220 or 70)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(o.nom, "NA.Equi.Petit", w / 2, h / 2, actif and OR or DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() f.Onglet = i; f:Remplir() end
    end

    -- gauche : filtre + liste des techniques
    local gauche = vgui.Create("DPanel", f)
    gauche:Dock(LEFT)
    gauche:SetWide(240)
    gauche:DockPadding(8, 8, 8, 8)
    gauche.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, PANNEAU) end

    local filtre = vgui.Create("DTextEntry", gauche)
    filtre:Dock(TOP)
    filtre:SetTall(28)
    filtre:DockMargin(0, 0, 0, 8)
    filtre:SetFont("NA.Equi.Texte")
    filtre.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, CASE)
        s:DrawTextEntryText(CREME, OR, CREME)
        if s:GetValue() == "" then
            draw.SimpleText("Rechercher une technique...", "NA.Equi.Texte", 4, h / 2, DOUX, nil, TEXT_ALIGN_CENTER)
        end
    end

    local scrollListe = vgui.Create("DScrollPanel", gauche)
    scrollListe:Dock(FILL)
    StyleScroll(scrollListe)

    local function Peupler()
        scrollListe:Clear()
        local mot = string.lower(filtre:GetValue())
        local onglet = ONGLETS[f.Onglet or 1]
        local dansOnglet = {}
        for _, c in ipairs(onglet.cats or {}) do dansOnglet[c] = true end

        local ids = {}
        for id in pairs(DEF) do
            local cat = Categorie(id)
            if (not onglet.cats or dansOnglet[cat]) and (mot == "" or string.find(id, mot, 1, true)) then ids[#ids + 1] = id end
        end
        -- tri : techniques d'abord (par catégorie, dans l'ordre de déblocage), armes à la fin
        local ordreId = {}
        for i, id in ipairs(NA_NIV.IDS) do ordreId[id] = i end
        table.sort(ids, function(a, b)
            local ra, rb = ordreId[a] or 9999, ordreId[b] or 9999
            if ra ~= rb then return ra < rb end
            return a < b
        end)

        local derniere
        for _, id in ipairs(ids) do
            local cat = Categorie(id)
            if cat ~= derniere and (not onglet.cats or #onglet.cats > 1) then
                derniere = cat
                local t = vgui.Create("DPanel", scrollListe)
                t:Dock(TOP)
                t:SetTall(24)
                t:DockMargin(0, 6, 0, 2)
                t.Paint = function(_, w, h)
                    draw.SimpleText(string.upper(cat), "NA.Equi.Petit", 4, h / 2, OR, nil, TEXT_ALIGN_CENTER)
                    surface.SetDrawColor(OR.r, OR.g, OR.b, 60)
                    surface.DrawRect(0, h - 1, w, 1)
                end
            end
            local b = vgui.Create("DButton", scrollListe)
            b:Dock(TOP)
            b:SetTall(28)
            b:DockMargin(0, 0, 0, 2)
            b:SetText("")
            b.Paint = function(s, w, h)
                local actif = f.Id == id
                if actif then
                    draw.RoundedBox(6, 0, 0, w, h, Color(OR.r, OR.g, OR.b, 40))
                    surface.SetDrawColor(OR)
                    surface.DrawRect(0, 4, 3, h - 8)
                elseif s:IsHovered() then
                    draw.RoundedBox(6, 0, 0, w, h, Color(255, 255, 255, 12))
                end
                draw.SimpleText((OV[id] and "● " or "") .. (EstArme(id) and (NA_EQUI.NOMS_ARMES[id] or id) or id), "NA.Equi.Texte", 12, h / 2,
                    actif and OR or (OV[id] and CHANGE or CREME), nil, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function()
                f.Id = id
                f:Remplir()
            end
        end
    end
    filtre.OnChange = Peupler
    Peupler()

    -- droite : grille des stats + bouton de remise à zéro
    local droite = vgui.Create("DPanel", f)
    droite:Dock(FILL)
    droite:DockMargin(12, 0, 0, 0)
    droite:DockPadding(12, 12, 12, 12)
    droite.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, PANNEAU) end

    local reset = vgui.Create("DButton", droite)
    reset:Dock(BOTTOM)
    reset:SetTall(32)
    reset:DockMargin(0, 10, 0, 0)
    reset:SetText("")
    reset.Paint = function(s, w, h)
        local survol = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 40) or CASE)
        surface.SetDrawColor(OR.r, OR.g, OR.b, survol and 220 or 90)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("RÉINITIALISER CETTE TECHNIQUE", "NA.Equi.Petit", w / 2, h / 2,
            survol and OR or DOUX, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    reset.DoClick = function()
        if not f.Id then return end
        net.Start("NA_Equi_Reset")
        net.WriteString(f.Id)
        net.SendToServer()
    end

    local zone = vgui.Create("DScrollPanel", droite)
    zone:Dock(FILL)
    StyleScroll(zone)

    function f:Remplir()
        Peupler()
        zone:Clear()
        local id = self.Id
        if not id then return end
        local def = DEF[id] or {}
        local cur = NA_NIV_TECH[id] or def

        local arme = EstArme(id)
        local cols = {}
        if arme then
            for n in pairs(def) do cols[#cols + 1] = n end
            table.sort(cols)
        else
            for n = 1, NA_NIV.MAX do cols[n] = n end
        end

        local stats = {}
        for _, n in ipairs(cols) do
            for s, v in pairs(def[n] or {}) do
                if isnumber(v) then stats[s] = true end
            end
        end
        local ordre = table.GetKeys(stats)
        table.sort(ordre, function(a, b)
            local ra, rb = RANG[a] or 999, RANG[b] or 999
            if ra ~= rb then return ra < rb end
            return a < b
        end)

        local function Ligne(texte, tete)
            local l = vgui.Create("DPanel", zone)
            l:Dock(TOP)
            l:SetTall(tete and 34 or 30)
            l:DockMargin(0, 0, 0, tete and 6 or 2)
            l.Paint = function(_, w, h)
                if tete then
                    surface.SetDrawColor(OR.r, OR.g, OR.b, 70)
                    surface.DrawRect(0, h - 1, w, 1)
                end
            end
            local lab = vgui.Create("DLabel", l)
            lab:Dock(LEFT)
            lab:SetWide(220)
            lab:SetFont(tete and "NA.Equi.Texte" or "NA.Equi.Petit")
            lab:SetTextColor(tete and OR or DOUX)
            lab:SetText(texte)
            return l
        end

        local tete = Ligne(string.upper(NA_EQUI.NOMS_ARMES and NA_EQUI.NOMS_ARMES[id] or (string.gsub(id, "_", " "))), true)
        for _, n in ipairs(cols) do
            local lab = vgui.Create("DLabel", tete)
            lab:Dock(LEFT)
            lab:SetWide(104)
            lab:SetFont("NA.Equi.Petit")
            lab:SetTextColor(DOUX)
            lab:SetContentAlignment(5)
            lab:SetText(arme and NomColonne(n) or ("NIVEAU " .. n))
        end

        for _, stat in ipairs(ordre) do
            local l = Ligne(NomStat(stat, arme))
            for _, n in ipairs(cols) do
                local v = Eff(cur, stat, n, arme)
                local change = v ~= Eff(def, stat, n, arme)
                if v == nil then   -- cette colonne n'a pas cette stat (arme) : case vide
                    local vide = vgui.Create("DPanel", l)
                    vide:Dock(LEFT)
                    vide:SetWide(104)
                    vide:SetPaintBackground(false)
                    continue
                end
                local te = vgui.Create("DTextEntry", l)
                te:Dock(LEFT)
                te:SetWide(100)
                te:DockMargin(0, 1, 4, 1)
                te:SetFont("NA.Equi.Texte")
                te:SetText(string.format("%g", v or 0))
                te.Paint = function(s, w, h)
                    draw.RoundedBox(5, 0, 0, w, h, CASE)
                    local c = change and CHANGE or (s:HasFocus() and OR or Color(255, 255, 255, 25))
                    surface.SetDrawColor(c.r, c.g, c.b, (change or s:HasFocus()) and 200 or 255)
                    surface.DrawOutlinedRect(0, 0, w, h, 1)
                    s:DrawTextEntryText(change and CHANGE or CREME, OR, CREME)
                end
                te.OnEnter = function(s)
                    local nv = tonumber(s:GetValue())
                    if not nv then return self:Remplir() end
                    net.Start("NA_Equi_Set")
                    net.WriteString(id)
                    net.WriteUInt(n, 4)
                    net.WriteString(stat)
                    net.WriteDouble(nv)
                    net.SendToServer()
                end
            end
        end
    end
end

net.Receive("NA_Equi_Ouvrir", Ouvrir)
