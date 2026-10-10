--========================================================
-- Menu admin (PARTAGÉ serveur + client)
--
-- Ouvre avec la commande console : na_admin   (ou !admin dans le chat)
-- Réservé aux superadmins / à l'hôte d'une partie locale.
--
-- On choisit un joueur à gauche, puis :
--   * Armes       : ajoute l'épée dans l'inventaire F4 du joueur (comme ajouter_epee)
--   * Techniques  : débloquer à un niveau (1 à 5, sans condition) ou retirer
--   * Grades      : changer le rang ninja (voir _na_rangs.lua)
--   * Téléportation : aller vers lui / l'amener à soi
-- NB : une technique d'un rang supérieur au sien reste inutilisable (NA_Debloquee) :
-- penser à monter aussi le grade.
--========================================================

if SERVER then AddCSLuaFile() end

-- Catalogue des tenues (playermodels) donnables : TOUS les .mdl des dossiers ci-dessous sont
-- détectés automatiquement (commun par défaut). Pour une rareté ou un nom précis, ajouter une
-- ligne dans INFOS (clé = chemin du modèle en minuscules). Rarétés : commun | rare | epique | legendaire.
local DOSSIERS = { "models/tenue", "models/salamandre" }   -- ordre = priorité en cas de doublon
local INFOS = {
    ["models/tenue/senju/genin/senju_a.mdl"]                  = { "Tenue Senju", "rare" },
    ["models/tenue/fuma/jonin/m_fuma_tkj.mdl"]                     = { "Tenue Fuma" },
    ["models/salamandre/eclypse_salamandre_chef.mdl"]   = { "Tenue Salamandre Chef", "epique" },
}

-- Clan = premier mot-clé trouvé dans le chemin du modèle (ajouter une ligne pour un nouveau clan)
local CLANS = {
    { "salamandre", "Salamandre" }, { "fuma", "Fuma" }, { "senju", "Senju" }, { "uchiha", "Uchiha" },
    { "hyuga", "Hyuga" }, { "kaguya", "Kaguya" }, { "kami", "Kami" }, { "chinoike", "Chinoike" },
    { "aburame", "Aburame" }, { "inuzuka", "Inuzuka" }, { "nara", "Nara" }, { "akimichi", "Akimichi" },
    { "yamanaka", "Yamanaka" }, { "uzumaki", "Uzumaki" }, { "sabaku", "Sabaku" }, { "suna", "Suna" },
}
-- Dossiers de village (models/tenue/<village>/<grade>/) : tenues sans clan, toujours affichés dans le menu
local VILLAGES = { konoha = "Konoha", ame = "Ame", iwa = "Iwa", neutre = "Neutre" }
local function Clan(m)
    for _, c in ipairs(CLANS) do if string.find(m, c[1], 1, true) then return c[2] end end
    return "Autres"
end

NA_TENUES = {}
local vus = {}   -- même nom de fichier dans deux dossiers : on garde le premier (models/tenue)
-- m_chunin1_salamandre.mdl -> "Chunin1 Salamandre (H)" ; w_ = femme
local function Nom(f)
    local base = string.StripExtension(f)
    local sexe = string.match(base, "^([mw])_")
    if sexe then base = string.sub(base, 3) end
    return string.NiceName(base) .. (sexe == "m" and " (H)" or sexe == "w" and " (F)" or "")
end
local function Scanner(dossier)
    local fichiers, sous = file.Find(dossier .. "/*", "GAME")
    for _, f in ipairs(fichiers) do
        if string.EndsWith(f, ".mdl") and not vus[f] then
            vus[f] = true
            local m = string.lower(dossier .. "/" .. f)
            local i = INFOS[m] or {}
            local t = { nom = i[1] or Nom(f), modele = m, rarete = i[2] or "commun", clan = Clan(m) }
            -- models/tenue/<clan>/<grade>/ : le sous-dossier est le grade ; models/tenue/konoha/, ame/ = tenues
            -- de village sans clan
            local village, grade = string.match(m, "^models/tenue/([^/]+)/([^/]+)/")
            t.grade = grade or "autres"   -- hors dossier de grade (ex : models/salamandre/)
            if VILLAGES[village or ""] then t.clan = VILLAGES[village] end
            NA_TENUES[#NA_TENUES + 1] = t
        end
    end
    for _, d in ipairs(sous) do Scanner(dossier .. "/" .. d) end
end
for _, d in ipairs(DOSSIERS) do Scanner(d) end
local RANG = { legendaire = 4, epique = 3, rare = 2, commun = 1 }
-- ordre des sous-dossiers de grade (models/tenue/<clan>/<grade>/) ; un autre dossier passe après
local NOMS_GRADES = { genin = "Genin", chunin = "Chunin", jonin = "Jonin", kage = "Kage", special = "Spécial", autres = "Autres" }
local GRADES = { genin = 1, chunin = 2, jonin = 3, kage = 4, special = 5 }
table.sort(NA_TENUES, function(a, b)
    if a.clan ~= b.clan then
        if a.clan == "Autres" or b.clan == "Autres" then return b.clan == "Autres" end   -- "Autres" en dernier
        return a.clan < b.clan
    end
    if a.grade ~= b.grade then return (GRADES[a.grade or ""] or 9) < (GRADES[b.grade or ""] or 9) end
    if a.rarete ~= b.rarete then return RANG[a.rarete] > RANG[b.rarete] end
    return a.nom < b.nom
end)

if SERVER then
    util.AddNetworkString("NA_Adm_Ouvrir")
    util.AddNetworkString("NA_Adm_DonnerTenue")
    util.AddNetworkString("NA_Adm_Action")

    local function Autorise(ply)
        return IsValid(ply) and (ply:IsSuperAdmin() or ply:IsListenServerHost() or game.SinglePlayer())
    end

    util.AddNetworkString("NA_Adm_DonnerArme")

    -- armes donnables : classe -> nom (mêmes critères que ajouter_epee, cl_monmenu.lua)
    local function ListeArmes()
        local r = {}
        for _, w in ipairs(weapons.GetList()) do
            local def = weapons.Get(w.ClassName)
            if def and def.NA_Arme and def.Spawnable and w.ClassName ~= "naruto_poings" then
                r[w.ClassName] = def.PrintName or w.ClassName
            end
        end
        return r
    end

    local function Ouvrir(ply)
        if not Autorise(ply) then
            if IsValid(ply) then ply:ChatPrint("Tu n'as pas le droit d'ouvrir le menu admin.") end
            return
        end
        local armes = ListeArmes()
        net.Start("NA_Adm_Ouvrir")
        net.WriteUInt(table.Count(armes), 8)
        for classe, nom in pairs(armes) do
            net.WriteString(classe)
            net.WriteString(nom)
        end
        net.Send(ply)
    end

    concommand.Add("na_admin", Ouvrir)
    hook.Add("PlayerSay", "NA_Adm_Chat", function(ply, texte)
        local cmd = string.lower(string.Trim(texte))
        if cmd ~= "!admin" and cmd ~= "/admin" then return end
        Ouvrir(ply)
        return ""
    end)

    net.Receive("NA_Adm_Action", function(_, ply)
        if not Autorise(ply) then return end
        local action, cible, arg, niveau = net.ReadString(), net.ReadEntity(), net.ReadString(), net.ReadUInt(4)
        if not IsValid(cible) or not cible:IsPlayer() then return end
        local nom = cible:Nick()

        if action == "arme" then
            if not ListeArmes()[arg] then return end
            -- l'inventaire (F4) est côté client : c'est le client du joueur qui range l'arme
            net.Start("NA_Adm_DonnerArme")
            net.WriteString(arg)
            net.Send(cible)
            ply:ChatPrint(arg .. " envoyée dans l'inventaire de " .. nom .. ".")
        elseif action == "tenue" then
            local t
            for _, v in ipairs(NA_TENUES) do if v.modele == arg then t = v end end
            if not t then return end
            net.Start("NA_Adm_DonnerTenue")
            net.WriteString(t.modele)
            net.Send(cible)
            ply:ChatPrint(t.nom .. " envoyée dans l'inventaire de " .. nom .. ".")
        elseif action == "tech" then
            if not NA_NIV.Existe(arg) then return end
            niveau = math.Clamp(niveau, 0, NA_NIV.MAX)
            cible:SetNW2Int("na_niv_" .. arg, niveau)
            NA_NIV.Sauver(cible)
            ply:ChatPrint(nom .. " : " .. arg .. " niveau " .. niveau .. ".")
        elseif action == "rang" then
            local i = tonumber(arg)
            if not i or i < 1 or i > NA_RANG.MAX then return end
            NA_RANG.Definir(cible, i)
            ply:ChatPrint(nom .. " est maintenant " .. NA_RANG.Nom(i) .. ".")
            if cible ~= ply then cible:ChatPrint("Ton rang est maintenant " .. NA_RANG.Nom(i) .. ".") end
        elseif action == "goto" or action == "bring" then
            if cible == ply then return end
            local qui, vers = ply, cible
            if action == "bring" then qui, vers = cible, ply end
            qui:SetPos(vers:GetPos() + vers:GetForward() * 70 + Vector(0, 0, 10))
            qui:SetLocalVelocity(vector_origin)
        end
    end)
    return
end

--========================================================
-- CLIENT
--========================================================
local OR, CREME, DOUX = Color(232, 196, 120), Color(240, 226, 196), Color(175, 155, 125)
local FOND, PANNEAU, CASE = Color(14, 10, 10, 245), Color(26, 19, 18, 255), Color(8, 6, 6, 255)

surface.CreateFont("NA.Adm.Titre", { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("NA.Adm.Texte", { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("NA.Adm.Petit", { font = "Roboto", size = 13, weight = 700, extended = true })

local function Scroll(parent)
    local sp = vgui.Create("DScrollPanel", parent)
    local vb = sp:GetVBar()
    vb:SetWide(6)
    vb.Paint = function() end
    vb.btnUp.Paint, vb.btnDown.Paint = function() end, function() end
    vb.btnGrip.Paint = function(_, w, h) draw.RoundedBox(3, 0, 0, w, h, Color(OR.r, OR.g, OR.b, 130)) end
    return sp
end

-- bouton à plat : dessin = fonction(w, h, survol)
local function Btn(parent, clic, dessin)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.DoClick = clic
    b.Paint = function(s, w, h)
        local survol = s:IsHovered()
        draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 35) or PANNEAU)
        dessin(w, h, survol)
    end
    return b
end

local function Texte(texte, x, y, col, align, font)
    draw.SimpleText(texte, font or "NA.Adm.Texte", x, y, col or CREME, align, TEXT_ALIGN_CENTER)
end

-- AjouterEpee (cl_monmenu.lua) range l'arme dans l'inventaire F4 et prévient le joueur
net.Receive("NA_Adm_DonnerArme", function()
    local classe = net.ReadString()
    if AjouterEpee then AjouterEpee(classe) end
end)

net.Receive("NA_Adm_DonnerTenue", function()
    local modele = net.ReadString()
    if AjouterTenue then AjouterTenue(modele) end
end)

local COUL_RARETE = {
    commun = { "COMMUN", Color(205, 205, 205) }, rare = { "RARE", Color(90, 175, 255) },
    epique = { "ÉPIQUE", Color(195, 115, 255) }, legendaire = { "LÉGENDAIRE", Color(255, 216, 75) },
}

net.Receive("NA_Adm_Ouvrir", function()
    local armes = {}
    for _ = 1, net.ReadUInt(8) do armes[#armes + 1] = { net.ReadString(), net.ReadString() } end
    table.sort(armes, function(a, b) return a[2] < b[2] end)

    if IsValid(NA_ADMIN_FRAME) then NA_ADMIN_FRAME:Remove() end
    local f = vgui.Create("DFrame")
    NA_ADMIN_FRAME = f
    f:SetSize(math.min(ScrW() - 40, 1200), math.min(ScrH() - 40, 780))
    f:Center()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:DockPadding(16, 64, 16, 16)
    f:MakePopup()
    f.Cible = LocalPlayer()
    f.Onglet = 1
    f.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, FOND)
        surface.SetDrawColor(OR.r, OR.g, OR.b, 150)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        Texte("MENU ADMIN", 20, 28, OR, nil, "NA.Adm.Titre")
        surface.SetDrawColor(OR.r, OR.g, OR.b, 60)
        surface.DrawRect(16, 52, w - 32, 1)
    end

    local x = Btn(f, function() f:Remove() end, function(w, h, survol) Texte("✕", w / 2, h / 2, survol and OR or DOUX, TEXT_ALIGN_CENTER) end)
    x:SetPos(f:GetWide() - 42, 12)
    x:SetSize(28, 28)

    local function Envoyer(action, arg, niveau)
        if not IsValid(f.Cible) then return end
        net.Start("NA_Adm_Action")
        net.WriteString(action)
        net.WriteEntity(f.Cible)
        net.WriteString(tostring(arg or ""))
        net.WriteUInt(niveau or 0, 4)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end

    -- GAUCHE : joueurs (clic = sélection)
    local gauche = vgui.Create("DPanel", f)
    gauche:Dock(LEFT)
    gauche:SetWide(210)
    gauche:DockPadding(8, 8, 8, 8)
    gauche.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, PANNEAU) end
    local lj = Scroll(gauche)
    lj:Dock(FILL)

    local nbJoueurs = -1
    local function RemplirJoueurs()
        lj:Clear()
        nbJoueurs = player.GetCount()
        for _, p in ipairs(player.GetAll()) do
            local b = Btn(lj, function() f.Cible = p end, function(w, h)
                if f.Cible == p then
                    draw.RoundedBox(6, 0, 0, w, h, Color(OR.r, OR.g, OR.b, 45))
                    surface.SetDrawColor(OR)
                    surface.DrawRect(0, 6, 3, h - 12)
                end
                if not IsValid(p) then return end
                Texte(p:Nick() .. (p == LocalPlayer() and " (moi)" or ""), 12, 14, f.Cible == p and OR or CREME)
                Texte(NA_RANG.Nom(NA_Rang(p)), 12, 32, DOUX, nil, "NA.Adm.Petit")
            end)
            b:Dock(TOP)
            b:SetTall(46)
            b:DockMargin(0, 0, 0, 4)
        end
    end
    RemplirJoueurs()
    f.Think = function() if player.GetCount() ~= nbJoueurs then RemplirJoueurs() end end

    -- DROITE : en-tête (joueur + téléportation), onglets, contenu
    local droite = vgui.Create("DPanel", f)
    droite:Dock(FILL)
    droite:DockMargin(12, 0, 0, 0)
    droite:SetPaintBackground(false)

    local tete = vgui.Create("DPanel", droite)
    tete:Dock(TOP)
    tete:SetTall(40)
    tete:DockMargin(0, 0, 0, 8)
    tete.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, PANNEAU)
        Texte(IsValid(f.Cible) and f.Cible:Nick() or "Aucun joueur", 14, h / 2, OR, nil, "NA.Adm.Titre")
    end
    local function Tp(texte, action, w)
        local b = Btn(tete, function() if f.Cible ~= LocalPlayer() then Envoyer(action) end end, function(bw, bh, survol)
            Texte(texte, bw / 2, bh / 2, f.Cible == LocalPlayer() and DOUX or (survol and OR or CREME), TEXT_ALIGN_CENTER)
        end)
        b:Dock(RIGHT)
        b:SetWide(w)
        b:DockMargin(0, 4, 6, 4)
    end
    Tp("L'AMENER À MOI", "bring", 140)
    Tp("ALLER VERS LUI", "goto", 130)

    local barre = vgui.Create("DPanel", droite)
    barre:Dock(TOP)
    barre:SetTall(32)
    barre:DockMargin(0, 0, 0, 8)
    barre:SetPaintBackground(false)

    local contenu = vgui.Create("DPanel", droite)
    contenu:Dock(FILL)
    contenu:DockPadding(10, 10, 10, 10)
    contenu.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, PANNEAU) end

    -- ARMES : une grille de boutons, clic = donner
    local function PageArmes()
        local sp = Scroll(contenu)
        sp:Dock(FILL)
        local grille = vgui.Create("DIconLayout", sp)
        grille:Dock(TOP)
        grille:SetSpaceX(6)
        grille:SetSpaceY(6)
        for _, a in ipairs(armes) do
            local b = Btn(grille, function() Envoyer("arme", a[1]) end, function(w, h, survol)
                draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 35) or CASE)
                Texte(a[2], w / 2, h / 2 - 7, survol and OR or CREME, TEXT_ALIGN_CENTER)
                Texte("clic pour donner", w / 2, h / 2 + 12, DOUX, TEXT_ALIGN_CENTER, "NA.Adm.Petit")
            end)
            b:SetSize(190, 56)
        end
    end

    -- TENUES : toutes les tenues avec leur rareté, clic = donner
    local function PageTenues()
        local filtre = vgui.Create("DTextEntry", contenu)
        filtre:Dock(TOP)
        filtre:SetTall(28)
        filtre:DockMargin(0, 0, 0, 8)
        filtre:SetFont("NA.Adm.Texte")
        filtre.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, CASE)
            s:DrawTextEntryText(CREME, OR, CREME)
            if s:GetValue() == "" then Texte("Rechercher une tenue (nom, clan ou rareté)...", 6, h / 2, DOUX) end
        end
        local sp = Scroll(contenu)
        sp:Dock(FILL)
        NA_ADM_TENUES_OUVERT = NA_ADM_TENUES_OUVERT or {}
        local ouvert = NA_ADM_TENUES_OUVERT   -- clan ou clan/grade -> déplié ? (gardé quand on referme le menu ; une recherche déplie tout)
        local function Remplir()
            local scroll = sp:GetVBar():GetScroll()
            sp:Clear()
            local mot = string.lower(filtre:GetValue())
            local groupes, ordre = {}, {}
            for _, t in ipairs(NA_TENUES) do
                local r = COUL_RARETE[t.rarete] or COUL_RARETE.commun
                if mot == "" or string.find(string.lower(t.nom), mot, 1, true) or string.find(string.lower(r[1]), mot, 1, true)
                    or string.find(string.lower(t.clan), mot, 1, true) then
                    if not groupes[t.clan] then groupes[t.clan] = {} ordre[#ordre + 1] = t.clan end
                    table.insert(groupes[t.clan], t)
                end
            end
            -- villages (Konoha, Ame, Iwa, Neutre : models/tenue/<village>/) toujours affichés, même vides : c'est là qu'on ajoute les nouvelles tenues
            if mot == "" then
                for _, village in pairs(VILLAGES) do
                    if not groupes[village] then
                        groupes[village] = {}
                        local pos = #ordre + 1
                        for k, c in ipairs(ordre) do if c == "Autres" or c > village then pos = k break end end
                        table.insert(ordre, pos, village)
                    end
                end
            end
            for _, clan in ipairs(ordre) do
                local liste = groupes[clan]
                local ouv = mot ~= "" or ouvert[clan]
                local e = Btn(sp, function() ouvert[clan] = not ouvert[clan] Remplir() end, function(w, h, survol)
                    draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 35) or CASE)
                    Texte((ouv and "▼  " or "▶  ") .. string.upper(clan), 10, h / 2, OR)
                    Texte(#liste == 0 and "vide" or (#liste .. " tenue" .. (#liste > 1 and "s" or "")), w - 12, h / 2, DOUX, TEXT_ALIGN_RIGHT, "NA.Adm.Petit")
                end)
                e:Dock(TOP)
                e:SetTall(32)
                e:DockMargin(0, 0, 0, 3)
                if ouv then
                    local grade, gouv
                    for _, t in ipairs(liste) do
                        if t.grade ~= grade then   -- sous-dossier de grade
                            grade = t.grade
                            local nomGrade, cle, n = NOMS_GRADES[grade] or string.upper(string.sub(grade, 1, 1)) .. string.sub(grade, 2), clan .. "/" .. grade, 0
                            for _, u in ipairs(liste) do if u.grade == grade then n = n + 1 end end
                            local deplie = mot ~= "" or ouvert[cle]   -- copies locales : les boutons gardent LEUR valeur
                            gouv = deplie
                            local g = Btn(sp, function() ouvert[cle] = not ouvert[cle] Remplir() end, function(w, h, survol)
                                draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 30) or CASE)
                                Texte((deplie and "▼  " or "▶  ") .. nomGrade, 10, h / 2, CREME)
                                Texte(n .. (n > 1 and " tenues" or " tenue"), w - 12, h / 2, DOUX, TEXT_ALIGN_RIGHT, "NA.Adm.Petit")
                            end)
                            g:Dock(TOP)
                            g:SetTall(28)
                            g:DockMargin(16, 0, 0, 3)
                        end
                        if gouv then
                            local r = COUL_RARETE[t.rarete] or COUL_RARETE.commun
                            local b = Btn(sp, function() Envoyer("tenue", t.modele) end, function(w, h, survol)
                                draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 25) or CASE)
                                Texte(t.nom, 14, h / 2, survol and OR or CREME)
                                Texte(r[1], w - 14, h / 2, r[2], TEXT_ALIGN_RIGHT)
                            end)
                            b:Dock(TOP)
                            b:SetTall(30)
                            b:DockMargin(32, 0, 0, 3)
                        end
                    end
                end
            end
            sp:InvalidateLayout(true)
            sp:GetVBar():SetScroll(scroll)
        end
        filtre.OnChange = Remplir
        Remplir()
    end

    -- TECHNIQUES : une ligne par technique, cases 0..5 = niveau (clic direct)
    local function PageTechs()
        local filtre = vgui.Create("DTextEntry", contenu)
        filtre:Dock(TOP)
        filtre:SetTall(28)
        filtre:DockMargin(0, 0, 0, 8)
        filtre:SetFont("NA.Adm.Texte")
        filtre.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, CASE)
            s:DrawTextEntryText(CREME, OR, CREME)
            if s:GetValue() == "" then Texte("Rechercher une technique ou un élément...", 6, h / 2, DOUX) end
        end
        local sp = Scroll(contenu)
        sp:Dock(FILL)

        NA_ADM_TECHS_OUVERT = NA_ADM_TECHS_OUVERT or {}
        local ouvert = NA_ADM_TECHS_OUVERT   -- ligne -> dépliée ? (gardé quand on referme le menu ; une recherche déplie tout)
        local function Remplir()
            local scroll = sp:GetVBar():GetScroll()
            sp:Clear()
            local mot = string.lower(filtre:GetValue())
            -- une ligne de techniques (NA_NIV.LIGNEES) = un menu, nommée d'après sa première technique
            for n, ligne in ipairs(NA_NIV.LIGNEES) do
                local nomLigne = string.upper(string.match(ligne[1], "^[^_]+"))
                local ids = {}
                for _, id in ipairs(ligne) do
                    if mot == "" or string.find(id, mot, 1, true) or string.find(string.lower(nomLigne), mot, 1, true) then ids[#ids + 1] = id end
                end
                if #ids > 0 then
                    local ouv = mot ~= "" or ouvert[n]
                    local e = Btn(sp, function() ouvert[n] = not ouvert[n] Remplir() end, function(w, h, survol)
                        draw.RoundedBox(6, 0, 0, w, h, survol and Color(OR.r, OR.g, OR.b, 35) or CASE)
                        Texte((ouv and "▼  " or "▶  ") .. nomLigne, 10, h / 2, OR)
                        Texte(#ids .. " technique" .. (#ids > 1 and "s" or ""), w - 12, h / 2, DOUX, TEXT_ALIGN_RIGHT, "NA.Adm.Petit")
                    end)
                    e:Dock(TOP)
                    e:SetTall(32)
                    e:DockMargin(0, 0, 0, 3)
                    if ouv then
                        for _, id in ipairs(ids) do
                            local l = vgui.Create("DPanel", sp)
                            l:Dock(TOP)
                            l:SetTall(28)
                            l:DockMargin(16, 0, 0, 2)
                            l.Paint = function(_, w, h)
                                Texte(id, 6, h / 2)
                                Texte(NA_RANG_TECH[id] or "C", w - (NA_NIV.MAX + 1) * 30 - 16, h / 2, DOUX, TEXT_ALIGN_CENTER, "NA.Adm.Petit")
                            end
                            for niv = NA_NIV.MAX, 0, -1 do
                                local c = Btn(l, function() Envoyer("tech", id, niv) end, function(w, h, survol)
                                    local actuel = IsValid(f.Cible) and NA_Niveau(f.Cible, id) or 0
                                    local plein = niv >= 1 and niv <= actuel
                                    draw.RoundedBox(4, 0, 0, w, h, plein and Color(OR.r, OR.g, OR.b, 200) or (survol and Color(OR.r, OR.g, OR.b, 60) or CASE))
                                    Texte(niv == 0 and "✕" or tostring(niv), w / 2, h / 2, plein and CASE or DOUX, TEXT_ALIGN_CENTER, "NA.Adm.Petit")
                                end)
                                c:Dock(RIGHT)
                                c:SetWide(26)
                                c:DockMargin(4, 2, 0, 2)
                            end
                        end
                    end
                end
            end
            sp:InvalidateLayout(true)
            sp:GetVBar():SetScroll(scroll)
        end
        filtre.OnChange = Remplir
        Remplir()
    end

    -- GRADES : un bouton par rang, clic = appliquer
    local function PageGrades()
        for i, r in ipairs(NA_RANG.LISTE) do
            local b = Btn(contenu, function() Envoyer("rang", i) end, function(w, h, survol)
                local actuel = IsValid(f.Cible) and NA_Rang(f.Cible) == i
                draw.RoundedBox(6, 0, 0, w, h, actuel and Color(OR.r, OR.g, OR.b, 45) or (survol and Color(OR.r, OR.g, OR.b, 25) or CASE))
                Texte(r.nom .. (actuel and "  ✔" or ""), 14, h / 2, actuel and OR or CREME)
                Texte(r.lettre .. "  •  " .. r.vie .. " PV  •  " .. r.chakra .. " chakra", w - 14, h / 2, DOUX, TEXT_ALIGN_RIGHT)
            end)
            b:Dock(TOP)
            b:SetTall(34)
            b:DockMargin(0, 0, 0, 4)
        end
    end

    local ONGLETS = { { "ARMES", PageArmes }, { "TENUES", PageTenues }, { "TECHNIQUES", PageTechs }, { "GRADES", PageGrades } }
    local function Afficher(i)
        f.Onglet = i
        contenu:Clear()
        ONGLETS[i][2]()
    end
    for i, o in ipairs(ONGLETS) do
        local b = Btn(barre, function() Afficher(i) end, function(w, h)
            local actif = f.Onglet == i
            if actif then draw.RoundedBox(6, 0, 0, w, h, Color(OR.r, OR.g, OR.b, 45)) end
            Texte(o[1], w / 2, h / 2, actif and OR or DOUX, TEXT_ALIGN_CENTER)
        end)
        b:Dock(LEFT)
        b:SetWide(150)
        b:DockMargin(0, 0, 6, 0)
    end
    Afficher(1)
end)

