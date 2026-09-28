--========================================================
-- Effet de slash des armes (CLIENT)
--
-- À chaque coup du clic gauche, le serveur envoie "NA_Arme_Slash"
-- (naruto_arme_base.lua) et on dessine un grand arc de slash translucide
-- CENTRÉ SUR LE JOUEUR, couché dans le monde comme une vraie coupe. On voit le
-- personnage à travers. Le slash se « trace » de la droite vers la gauche puis
-- s'efface. La forme vient de models/slash/slash.mdl (copiée ici en Lua), la
-- texture de katanart/effects/blade*.
--
-- ANGLES d'un coup : trois valeurs X Y Z, en degrés, dans le repère du joueur
-- (0 0 0 = arc À PLAT autour de lui, dans l'axe où il regarde) :
--     X = roulis   : fait pencher le plan autour de l'axe avant/arrière
--                    (90 = coupe verticale, 45 / -45 = diagonales)
--     Y = bascule  : NÉGATIF = lève l'avant du plan (utile pour mieux le voir depuis derrière),
--                    positif = le baisse
--     Z = cap      : tourne le plan autour de la verticale (orienter à gauche / droite)
--
-- RÉGLAGES, dans l'ordre de priorité (le premier trouvé gagne) :
--   1. réglage fait EN JEU pour l'arme tenue (commandes na_slash_arme*, sauvegardé
--      dans data/na_slash_armes.txt) ;
--   2. réglage écrit dans le fichier de l'arme (SWEP.Slash, voir plus bas) ;
--   3. réglage général (commandes na_slash_*).
--
-- COMMANDES GÉNÉRALES (valables pour toutes les armes sans réglage propre) :
--   na_slash 0/1            active / coupe l'effet
--   na_slash_angle N X Y Z  angles du coup N (1 à 3), ex : na_slash_angle 2 -45 -20 0
--   na_slash_couleur        blanc | bleu | rouge | vert | violet
--   na_slash_teinte         "r g b" (0-255) : colore / assombrit la texture
--   na_slash_alpha          opacité 0-255
--   na_slash_echelle        taille (1.8 = arc d'environ 190 unités de large)
--   na_slash_dist           décalage vers l'avant du centre de l'arc (0 = centré sur le joueur)
--   na_slash_haut           hauteur du centre de l'arc au-dessus des pieds (45 = taille)
--   na_slash_delai          secondes après le début du coup avant l'effet
--   na_slash_duree          durée de l'effet
--   na_slash_sens           1 = tracé de droite à gauche, -1 = l'inverse
--   na_slash_tourne         fait tourner l'arc dans son plan (180 = bombé vers le joueur)
--   na_slash_suit           0 = le slash reste où le coup a eu lieu ; 1 = il suit le joueur quand il se
--                           déplace ; 2 = il suit aussi quand le joueur tourne (comme soudé au corps)
--   na_slash_test [1-3]     joue un slash pour régler sans frapper
--   na_slash_debug 1        affiche dans la console ce que fait l'effet
--   na_slash_reset          remet les réglages généraux par défaut
--
-- COMMANDES PAR ARME (pour l'arme que tu tiens en main) :
--   na_slash_arme_angle N X Y Z   angles du coup N pour cette arme
--   na_slash_arme REGLAGE VALEUR  couleur | teinte | alpha | echelle | dist | haut |
--                                 delai | duree | sens | tourne | suit | actif   (VALEUR "auto" = retirer)
--   na_slash_arme_info            affiche tous les réglages de cette arme
--   na_slash_arme_reset           efface les réglages en jeu de cette arme
--
-- PAS DE SLASH POUR UNE ARME (poings, armes sans swing...) : dans son shared.lua, écris
--   SWEP.Slash = false
-- ou, en jeu, avec l'arme en main :  na_slash_arme actif 0   (et  na_slash_arme actif auto  pour annuler)
--
-- DANS LE FICHIER D'UNE ARME (lua/weapons/<arme>/shared.lua), tout est optionnel :
--   SWEP.Slash = {
--       angles  = { {x = 0, y = -25, z = 0}, {x = -45, y = -25, z = 0}, {x = 90, y = -40, z = 0} },
--       couleur = "bleu",     echelle = 2,     alpha = 160,   -- et : actif, teinte, dist, haut, delai, duree, sens, tourne, suit
--   }
--
-- Les réglages sont ceux de chaque joueur (ils décident de ce qu'ils VOIENT).
--========================================================

local SLASH_VERTS = {
    {-10.81, 50.33, 0.0007, 0.2409},
    {-10.59, 24.88, 0.0076, 0.8310},
    {-10.70, 37.60, 0.0000, 0.5000},
    {-5.94, 23.94, 0.0677, 0.8382},
    {-0.98, 48.39, 0.0625, 0.2125},
    {-3.46, 36.17, 0.0625, 0.5000},
    {8.38, 45.55, 0.1250, 0.1773},
    {-1.39, 22.50, 0.1426, 0.8590},
    {3.50, 34.03, 0.1250, 0.5000},
    {2.92, 20.06, 0.1999, 0.8734},
    {16.81, 40.90, 0.1875, 0.1327},
    {9.87, 30.48, 0.1875, 0.5000},
    {24.14, 34.76, 0.2500, 0.1083},
    {6.71, 16.89, 0.2488, 0.8871},
    {15.42, 25.83, 0.2500, 0.5000},
    {9.69, 13.26, 0.3113, 0.9159},
    {30.20, 27.48, 0.3125, 0.0893},
    {19.95, 20.37, 0.3125, 0.5000},
    {34.69, 19.11, 0.3750, 0.0628},
    {11.83, 9.21, 0.3722, 0.9303},
    {23.26, 14.16, 0.3750, 0.5000},
    {13.09, 4.78, 0.4343, 0.9407},
    {37.31, 9.70, 0.4375, 0.0474},
    {25.20, 7.24, 0.4375, 0.5000},
    {38.17, -0.15, 0.4993, 0.0365},
    {13.47, 0.19, 0.4926, 0.9526},
    {25.82, 0.02, 0.5000, 0.5000},
    {12.99, -4.38, 0.5604, 0.9563},
    {37.38, -9.84, 0.5659, 0.0190},
    {25.18, -7.11, 0.5625, 0.5000},
    {34.79, -19.05, 0.6264, 0.0190},
    {11.62, -8.84, 0.6271, 0.9549},
    {23.21, -13.94, 0.6250, 0.5000},
    {9.37, -13.15, 0.6948, 0.9542},
    {30.28, -27.47, 0.6895, 0.0203},
    {19.83, -20.31, 0.6875, 0.5000},
    {24.14, -34.87, 0.7520, 0.0365},
    {6.39, -16.98, 0.7564, 0.9706},
    {15.26, -25.92, 0.7500, 0.5000},
    {2.83, -20.01, 0.8292, 0.9777},
    {16.65, -41.03, 0.8220, 0.0569},
    {9.74, -30.52, 0.8125, 0.5000},
    {8.11, -45.63, 0.8872, 0.0596},
    {-1.26, -22.27, 0.8995, 0.9838},
    {3.42, -33.95, 0.8750, 0.5000},
    {-10.78, -24.92, 1.0070, 0.8381},
    {-10.95, -50.18, 1.0000, 0.0920},
    {-5.89, -23.78, 0.9407, 1.0041},
    {-10.86, -37.55, 1.0000, 0.5000},
    {-1.23, -48.37, 0.9328, 0.0690},
    {-3.56, -36.07, 0.9375, 0.5000}
}
local SLASH_TRIS = { {49,47,46}, {51,49,46}, {49,51,47}, {41,42,39}, {33,31,35}, {31,33,29}, {42,34,39}, {33,25,29}, {25,33,30}, {27,25,30}, {26,27,30}, {45,51,46}, {42,45,46}, {51,45,47}, {45,50,47}, {41,45,42}, {45,43,50}, {43,45,41}, {37,41,39}, {43,37,35}, {37,43,41}, {48,44,46}, {38,42,46}, {38,34,42}, {34,36,39}, {36,37,39}, {36,33,35}, {37,36,35}, {1,6,3}, {6,2,3}, {15,7,11}, {27,23,25}, {25,23,29}, {20,22,26}, {22,27,26}, {18,15,11}, {18,17,21}, {23,24,19}, {24,23,27}, {24,17,19}, {17,24,21}, {21,24,20}, {24,22,20}, {22,24,27}, {16,21,20}, {6,4,2}, {4,6,9}, {10,12,15}, {12,7,15}, {26,28,48}, {28,38,48}, {28,26,30}, {40,44,48}, {38,40,48}, {44,40,46}, {40,38,46}, {5,6,1}, {6,5,9}, {11,5,1}, {7,5,11}, {5,12,9}, {12,5,7}, {13,18,11}, {18,13,17}, {17,13,19}, {8,16,2}, {16,8,10}, {4,8,2}, {8,12,10}, {8,4,9}, {12,8,9}, {14,18,21}, {16,14,21}, {14,16,10}, {14,10,15}, {18,14,15}, {38,32,34}, {28,32,38}, {36,32,33}, {32,36,34}, {33,32,30}, {32,28,30} }

local COULEURS = {
    blanc  = "slash_arme/blanc",
    bleu   = "slash_arme/bleu",
    rouge  = "slash_arme/rouge",
    vert   = "slash_arme/vert",
    violet = "slash_arme/violet",
}

local DEFAUTS = {
    na_slash          = "1",
    na_slash_couleur  = "blanc",
    na_slash_teinte   = "255 255 255",
    na_slash_alpha    = "130",
    na_slash_echelle  = "1.8",
    na_slash_dist     = "0",
    na_slash_haut     = "45",
    na_slash_delai    = "0.15",
    na_slash_duree    = "0.4",
    na_slash_sens     = "1",
    na_slash_tourne   = "0",
    na_slash_suit     = "2",
    na_slash_angle1   = "0 0 0",
    na_slash_angle2   = "-45 0 0",
    na_slash_angle3   = "90 0 0",
}

local cvDebug = CreateClientConVar("na_slash_debug", "0", true, false)
local function Dbg(...)
    if cvDebug:GetBool() then MsgC(Color(255, 200, 0), "[Slash] ", color_white, string.format(...) .. "\n") end
end

local cv = {}
for nom, val in pairs(DEFAUTS) do
    cv[nom] = CreateClientConVar(nom, val, true, false)
end

-- sommets prêts à l'emploi : x = vers l'avant, y = vers le côté (droite du joueur)
local SOMMETS = {}
for i, v in ipairs(SLASH_VERTS) do
    SOMMETS[i] = { x = v[1], y = v[2], u = v[3], v = v[4] }
end

--------------------------------------------------------
-- Réglages par arme (en jeu, sauvegardés)
--------------------------------------------------------
local FICHIER = "na_slash_armes.txt"
local surcharges = {}   -- [classe] = { angles = { [n] = {x,y,z} }, couleur = ..., echelle = ... }

local function Charger()
    local brut = file.Read(FICHIER, "DATA")
    local t = brut and util.JSONToTable(brut) or {}
    surcharges = {}
    for classe, o in pairs(t) do
        local angles = {}
        for k, a in pairs(o.angles or {}) do angles[tonumber(k) or k] = a end
        o.angles = angles
        surcharges[classe] = o
    end
end
Charger()

local function Sauver()
    file.Write(FICHIER, util.TableToJSON(surcharges, true))
end

local function ClasseTenue(ply)
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() or nil
end

-- réglage propre à l'arme dans son fichier (SWEP.Slash)
local function DansFichierArme(classe)
    local swep = classe and weapons.Get(classe)
    return swep and swep.Slash
end

-- Cette arme fait-elle un slash ?  en jeu (na_slash_arme actif) > SWEP.Slash = false / actif = false > oui
local function EstFalse(v)
    v = string.lower(tostring(v))
    return v == "0" or v == "false" or v == "non" or v == "off" or v == "no"
end

local function SlashActif(classe)
    local o = classe and surcharges[classe]
    if o and o.actif ~= nil then return not EstFalse(o.actif) end

    local swep = classe and weapons.Get(classe)
    if swep and swep.Slash == false then return false end
    if swep and istable(swep.Slash) and swep.Slash.actif ~= nil then return not EstFalse(swep.Slash.actif) end
    return true
end

-- valeur d'un réglage : en jeu (par arme) > fichier de l'arme > réglage général
local function Reglage(classe, nom)
    local o = classe and surcharges[classe]
    if o and o[nom] ~= nil then return o[nom], "arme (en jeu)" end
    local f = DansFichierArme(classe)
    if f and f[nom] ~= nil then return f[nom], "fichier de l'arme" end
    return cv["na_slash_" .. nom]:GetString(), "général"
end

local function ReglageNombre(classe, nom)
    return tonumber((Reglage(classe, nom))) or tonumber(DEFAUTS["na_slash_" .. nom]) or 0
end

local function LireAngles(chaine)
    local x, y, z = string.match(tostring(chaine), "(-?[%d%.]+)%s+(-?[%d%.]+)%s+(-?[%d%.]+)")
    return { x = tonumber(x) or 0, y = tonumber(y) or 0, z = tonumber(z) or 0 }
end

-- angles X Y Z du coup N pour cette arme
local function AnglesDuCoup(classe, index)
    local o = classe and surcharges[classe]
    if o and o.angles and o.angles[index] then return o.angles[index], "arme (en jeu)" end

    local f = DansFichierArme(classe)
    if f and istable(f.angles) and #f.angles > 0 then
        local a = f.angles[((index - 1) % #f.angles) + 1]
        return { x = a.x or 0, y = a.y or 0, z = a.z or 0 }, "fichier de l'arme"
    end

    return LireAngles(cv["na_slash_angle" .. (((index - 1) % 3) + 1)]:GetString()), "général"
end

local materiaux = {}
local function GetMat(nom)
    local chemin = COULEURS[string.lower(tostring(nom))] or COULEURS.blanc
    if not materiaux[chemin] then materiaux[chemin] = Material(chemin) end
    return materiaux[chemin]
end

local function Teinte(chaine)
    local r, g, b = string.match(tostring(chaine), "(%d+)%D+(%d+)%D+(%d+)")
    return math.Clamp(tonumber(r) or 255, 0, 255), math.Clamp(tonumber(g) or 255, 0, 255), math.Clamp(tonumber(b) or 255, 0, 255)
end

--------------------------------------------------------
-- Apparition d'un slash
--------------------------------------------------------
local actifs = {}

local function Creer(ply, index)
    if not cv.na_slash:GetBool() or not IsValid(ply) or not ply:Alive() then return end
    index = index or 1

    local classe = ClasseTenue(ply)
    if not SlashActif(classe) then return end
    local a = AnglesDuCoup(classe, index)

    -- repère du slash : 0 0 0 = plan horizontal dans l'axe du regard (sans haut/bas)
    --   X = roulis autour de l'avant, Y = bascule avant/arrière, Z = cap autour de la verticale
    local ang = Angle(a.y, ply:EyeAngles().y + a.z, a.x)
    local avant, cote = ang:Forward(), ang:Right()

    local pos = ply:GetPos() + Angle(0, ply:EyeAngles().y, 0):Forward() * ReglageNombre(classe, "dist")
    pos.z = pos.z + ReglageNombre(classe, "haut")

    local echelle = ReglageNombre(classe, "echelle")
    local tourne = math.rad(ReglageNombre(classe, "tourne"))
    local c, sn = math.cos(tourne), math.sin(tourne)

    -- le croissant ne doit pas passer sous le sol (le sol le couperait net)
    local basZ = math.huge
    for _, v in ipairs(SOMMETS) do
        local x = (v.x * c - v.y * sn) * echelle
        local y = (v.x * sn + v.y * c) * echelle
        basZ = math.min(basZ, pos.z + avant.z * x + cote.z * y)
    end
    local sol = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
    local solZ = sol.Hit and sol.HitPos.z or (pos.z - 400)
    if basZ < solZ + 3 then pos.z = pos.z + (solZ + 3 - basZ) end

    local r, g, b = Teinte((Reglage(classe, "teinte")))
    actifs[#actifs + 1] = {
        pos = pos, avant = avant, cote = cote,
        ply = ply, decal = pos - ply:GetPos(), yaw0 = ply:EyeAngles().y,
        suit = math.floor(ReglageNombre(classe, "suit")),
        debut = CurTime(),
        duree = math.max(ReglageNombre(classe, "duree"), 0.05),
        echelle = echelle,
        cos = c, sin = sn,
        alpha = math.Clamp(ReglageNombre(classe, "alpha"), 0, 255),
        sens = ReglageNombre(classe, "sens") >= 0 and 1 or -1,
        mat = GetMat((Reglage(classe, "couleur"))),
        r = r, g = g, b = b,
    }

    Dbg("slash créé : arme=%s coup=%d angles=(%g, %g, %g) pos=%s", tostring(classe), index, a.x, a.y, a.z, tostring(pos))
end

--------------------------------------------------------
-- Dessin
--------------------------------------------------------
-- Position et orientation du slash à cet instant : suivent le joueur s'il bouge / tourne
local function Repere(s)
    if s.suit <= 0 then return s.pos, s.avant, s.cote end
    local ply = s.ply
    if not IsValid(ply) then return end

    local base = ply:GetPos()
    if s.suit == 1 then return base + s.decal, s.avant, s.cote end

    local rot = Angle(0, ply:EyeAngles().y - s.yaw0, 0)
    local decal, avant, cote = Vector(s.decal), Vector(s.avant), Vector(s.cote)
    decal:Rotate(rot) avant:Rotate(rot) cote:Rotate(rot)
    return base + decal, avant, cote
end

local function Dessiner(s, t, pos, avant, cote)
    -- balayage : le slash se trace de u=0 vers u=1 pendant le début, puis fondu
    local avance = math.min(t / 0.45, 1)
    local fondu = t > 0.55 and 1 - (t - 0.55) / 0.45 or 1

    render.SetMaterial(s.mat)
    mesh.Begin(MATERIAL_TRIANGLES, #SLASH_TRIS)
    for _, tri in ipairs(SLASH_TRIS) do
        for k = 1, 3 do
            local v = SOMMETS[tri[k]]
            local x = (v.x * s.cos - v.y * s.sin) * s.echelle
            local y = (v.x * s.sin + v.y * s.cos) * s.echelle
            local u = s.sens > 0 and v.u or 1 - v.u
            local a = math.Clamp((avance * 1.3 - u) * 4, 0, 1) * fondu

            mesh.Position(pos + avant * x + cote * y)
            mesh.TexCoord(0, v.u, v.v)
            mesh.Color(s.r, s.g, s.b, math.floor(s.alpha * a))
            mesh.AdvanceVertex()
        end
    end
    mesh.End()
end

hook.Add("PostDrawTranslucentRenderables", "NA_Slash_Dessin", function(profondeur, ciel)
    if ciel or #actifs == 0 then return end

    local now = CurTime()
    for i = #actifs, 1, -1 do
        local s = actifs[i]
        local t = (now - s.debut) / s.duree
        local pos, avant, cote = Repere(s)
        if t >= 1 or not pos then
            table.remove(actifs, i)
        else
            Dessiner(s, t, pos, avant, cote)
            if cvDebug:GetBool() then debugoverlay.Cross(pos, 10, 0.05, Color(255, 200, 0), true) end
        end
    end
end)

net.Receive("NA_Arme_Slash", function()
    local ply = net.ReadEntity()
    local index = net.ReadUInt(4)
    Dbg("message reçu du serveur (coup %s) joueur=%s", tostring(index), tostring(ply))
    if not IsValid(ply) then return end
    timer.Simple(ReglageNombre(ClasseTenue(ply), "delai"), function() Creer(ply, index) end)
end)

--------------------------------------------------------
-- Commandes générales
--------------------------------------------------------
local function Msg(...) MsgC(Color(255, 200, 0), "[Slash] ", color_white, string.format(...) .. "\n") end

concommand.Add("na_slash_test", function(ply, cmd, args)
    Creer(LocalPlayer(), tonumber(args[1]) or 1)
end, nil, "Joue un slash devant toi. Argument : numéro du coup (1, 2 ou 3).")

concommand.Add("na_slash_reset", function()
    for nom, val in pairs(DEFAUTS) do
        RunConsoleCommand(nom, val)
    end
    Msg("réglages généraux remis par défaut.")
end, nil, "Remet les réglages généraux du slash par défaut.")

-- na_slash_angle N X Y Z : angles du coup N (réglage général)
concommand.Add("na_slash_angle", function(ply, cmd, args)
    local n, x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
    if not n or n < 1 or n > 3 or not x or not y or not z then
        Msg("usage : na_slash_angle N X Y Z   (N = 1, 2 ou 3 ; angles en degrés)  ex : na_slash_angle 2 -45 20 0")
        return
    end
    RunConsoleCommand("na_slash_angle" .. math.floor(n), string.format("%g %g %g", x, y, z))
    Msg("coup %d (général) : X=%g Y=%g Z=%g", n, x, y, z)
end, nil, "na_slash_angle N X Y Z : angles (roulis, bascule, cap) du coup N.")

--------------------------------------------------------
-- Commandes par arme
--------------------------------------------------------
local REGLAGES_ARME = { couleur = true, teinte = true, alpha = true, echelle = true, dist = true,
                        haut = true, delai = true, duree = true, sens = true, tourne = true, suit = true, actif = true }

local function ArmeTenue()
    local classe = ClasseTenue(LocalPlayer())
    if not classe then Msg("tu ne tiens aucune arme.") end
    return classe
end

concommand.Add("na_slash_arme_angle", function(ply, cmd, args)
    local classe = ArmeTenue()
    if not classe then return end
    local n, x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
    if not n or n < 1 or not x or not y or not z then
        Msg("usage : na_slash_arme_angle N X Y Z   (N = numéro du coup ; angles en degrés)")
        return
    end
    n = math.floor(n)
    surcharges[classe] = surcharges[classe] or { angles = {} }
    surcharges[classe].angles = surcharges[classe].angles or {}
    surcharges[classe].angles[n] = { x = x, y = y, z = z }
    Sauver()
    Msg("%s, coup %d : X=%g Y=%g Z=%g (sauvegardé)", classe, n, x, y, z)
end, nil, "na_slash_arme_angle N X Y Z : angles du coup N pour l'arme tenue.")

concommand.Add("na_slash_arme", function(ply, cmd, args)
    local classe = ArmeTenue()
    if not classe then return end
    local nom, valeur = string.lower(args[1] or ""), args[2]
    if not REGLAGES_ARME[nom] or not valeur then
        Msg("usage : na_slash_arme REGLAGE VALEUR   réglages : actif, couleur, teinte, alpha, echelle, dist, haut, delai, duree, sens, tourne, suit")
        Msg("         VALEUR \"auto\" retire le réglage de cette arme. Pour teinte, mets des guillemets : \"255 100 100\"")
        return
    end
    surcharges[classe] = surcharges[classe] or { angles = {} }
    if string.lower(valeur) == "auto" then
        surcharges[classe][nom] = nil
        Msg("%s : %s retiré (retour au réglage général)", classe, nom)
    else
        surcharges[classe][nom] = valeur
        Msg("%s : %s = %s (sauvegardé)", classe, nom, valeur)
    end
    Sauver()
end, nil, "na_slash_arme REGLAGE VALEUR : réglage du slash pour l'arme tenue.")

concommand.Add("na_slash_arme_reset", function()
    local classe = ArmeTenue()
    if not classe then return end
    surcharges[classe] = nil
    Sauver()
    Msg("%s : réglages en jeu effacés.", classe)
end, nil, "Efface les réglages en jeu du slash pour l'arme tenue.")

concommand.Add("na_slash_arme_info", function()
    local classe = ArmeTenue()
    if not classe then return end
    Msg("arme : %s", classe)
    Msg("  actif    = %s", tostring(SlashActif(classe)))
    for _, nom in ipairs({ "couleur", "teinte", "alpha", "echelle", "dist", "haut", "delai", "duree", "sens", "tourne", "suit" }) do
        local v, d = Reglage(classe, nom)
        Msg("  %-8s = %-12s (%s)", nom, tostring(v), d)
    end
    for i = 1, 3 do
        local a, d = AnglesDuCoup(classe, i)
        Msg("  coup %d   X=%g Y=%g Z=%g (%s)", i, a.x, a.y, a.z, d)
    end
end, nil, "Affiche les réglages du slash de l'arme tenue.")
