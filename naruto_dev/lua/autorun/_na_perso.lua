--========================================================
-- Personnalisation du personnage (PARTAGÉ serveur + client)
--
-- Données communes au serveur (sv_perso.lua : sauvegarde, validation, pose de
-- la tête) et au client (cl_perso.lua : matériaux ; cl_perso_menu.lua : menu).
--
-- Un choix de personnage est une table :
--   visage    0 = tête d'origine (models/head_03.mdl), 1..28 = models/head/face_N.mdl
--   cheveux   0 = coupe 0 du modèle d'origine (hairs1_head, ou hairs1_face sur un visage numéroté),
--             1..n = models/haire/* (visage numéroté), puis les 91 autres coupes du modèle d'origine
--             (P.COUPES : bodygroup), valables avec toutes les têtes
--   yeux      forme des yeux  (index dans NA_PERSO.YEUX)      | visages 1..28 seulement
--   nez       0 = de base, sinon index dans NA_PERSO.NEZ       |
--   sourcils  1..44 (materials/atg/eyebrows/eyebrows_N.vtf)    |
--   barbe     0..9 (bodygroup "beard" du visage)               |
--   bouche    1 = forme de bouche propre au visage, 0 = neutre  |
--   recul     0..40 (dixièmes d'unité) : recul du visage et des cheveux, voir cl_perso.lua
--   logo      0 = celui de la coiffure, sinon index dans NA_PERSO.LOGOS (village du bandeau)
--   peau, cheveux_c, yeux_c, sourcils_c, bandeau_c : couleurs { r, g, b }
--             (bandeau_c : bandeaux et bandages des coiffures, cl_perso.lua)
--
-- Les modèles de la tête d'origine gardent leur apparence (yeux : sv_yeux.lua).
--========================================================

if SERVER then AddCSLuaFile() end

NA_PERSO = NA_PERSO or {}
local P = NA_PERSO

P.NB_VISAGES  = 28
P.NB_SOURCILS = 44
P.NB_BARBES   = 9

-- Flex des visages (communs aux 28) : "eyes_<nom>" + "eyes_<nom>_blink", "nose_<nom>"
P.YEUX = {
    "Moriginal01", "Moriginal02", "Woriginal02", "anko", "choji", "gaara", "guy", "hashirama",
    "hinata", "itachi", "jiraiya", "kakashi", "kiba", "konan", "kurenai", "kushina", "lee",
    "madara", "mei", "naruto", "sakura", "sarada", "sasuke", "shikamaru", "shizune", "temari",
    "tenten", "tsunade",
}
P.NEZ = {
    "Moriginal01", "Moriginal02", "Woriginal01", "Woriginal02", "asuma", "bee", "guy",
    "jiraiya", "kiba", "konan", "mei", "sarada", "tsunade",
}

-- Coiffures : un dossier par coiffure dans models/haire/, triées par nom (même ordre
-- des deux côtés). Les dossiers sans .mdl (fichiers manquants) sont ignorés, ainsi que
-- celles sans os de tête (tools/ajuster_cheveux.py ne peut pas les adapter).
-- Elles sont adaptées au crâne des visages numérotés (même script) : elles ne vont
-- plus sur la tête d'origine.
local EXCLUES = { ["pm_19fb4dc9-aaec-45c9-893b-d010df456b6b"] = true }
P.CHEVEUX = {}
local _, dossiers = file.Find("models/haire/*", "GAME")
for _, d in ipairs(dossiers) do
    local chemin = "models/haire/" .. d .. "/" .. d .. ".mdl"
    if not EXCLUES[d] and file.Exists(chemin, "GAME") then P.CHEVEUX[#P.CHEVEUX + 1] = chemin end
end
-- Les 92 coupes du modèle d'origine (models/hairs1_head.mdl : bodygroup "Headgear", index 0 à 91).
-- La coupe 0 est le choix "cheveux = 0" ; les 91 autres sont ajoutées à la fin de la liste
-- (P.COUPES[indice] = numéro du bodygroup). Elles vont aussi avec la tête d'origine.
P.NOMS_COUPES = {
    "Man_AllBack_01", "Man_AllBack_02", "Man_AllBack_03", "Man_HalfUpBun_01", "Man_HatTurban_01",
    "Man_HatTurban_02", "Man_Cap_01", "Man_SpikyHair_10", "Man_IwabeHat_01", "Man_ShortBob_01",
    "Man_ShortBob_02", "Man_ShortBob_03", "Man_ShortBob_04", "Man_ShortPonyTail_05", "Man_ShortPonyTail_06",
    "Man_ShortSpikyHair_01", "Man_ShortSpikyHair_02", "Man_ShortSpikyHair_03", "Man_ShortSpikyHair_04",
    "Man_ShortSpikyHair_05", "Man_ShortSpikyHair_06", "Man_ShortSpikyHair_07", "Man_ShortSpikyHair_08",
    "Man_ShortSpikyHair_09", "Man_ShortSpikyHair_10", "Man_ShortSpikyHair_11", "Man_ShortPonyTail_01",
    "Man_ShortPonyTail_02", "Man_LongSpikyHair_01", "Man_LongSpikyHair_02", "Man_LongSpikyHair_03",
    "Man_LongSpikyHair_04", "Man_LongSpikyPonyTail_01", "Man_MediumSpikyHair_01", "Man_MediumSpikyHair_03",
    "Man_MediumSpikyHair_04", "Man_MediumStraight_01", "Man_MediumStraight_02", "Man_MediumStraight_03",
    "Man_MediumStraight_04", "Man_MediumStraight_05", "Man_MediumStraight_06", "Man_PonyTail_01",
    "Man_PonyTail_02", "Man_PonyTail_06", "Man_ShortStraight_01", "Man_SpikyHair_01", "Man_SpikyHair_02",
    "Man_SpikyHair_03", "Man_SpikyHair_04", "Man_SpikyHair_05", "Man_SpikyHair_06", "Man_SpikyHair_07",
    "Man_SpikyHair_08", "Man_SpikyHair_09", "Man_SpikyPonyTail_01", "Man_TopKnot_01", "Man_TwoBlock_01",
    "Man_TwoBlock_02", "Woman_Bob_M_01", "Woman_Bob_M_02", "Woman_Bob_M_04", "Woman_Bob_M_05",
    "Woman_Bob_S_01", "Woman_Bob_S_02", "Woman_Bob_S_03", "Woman_BunRose_01", "Woman_Braid_01",
    "Woman_Braid_02", "Woman_Bunches_L_01", "Woman_Medicalhat_01", "Woman_OutCurl_M_01",
    "Woman_PonyTail_L_04", "Woman_PonyTail_L_05", "Woman_PonyTail_L_06", "Woman_PonyTail_S_01",
    "Woman_PonyTail_S_02", "Woman_SpikyBun_02", "Woman_SpikyBun_03", "Woman_SpikyHair_L_01_S",
    "Woman_SpikyHair_L_02_S", "Woman_StraightHair_L_01", "Woman_StraightHair_L_01_S",
    "Woman_StraightHair_L_02_S", "Woman_StraightHair_L_04", "Woman_StraightHair_L_05",
    "Woman_StraightHair_M_02", "Woman_StraightHair_M_04", "Woman_StraightHair_S_01",
    "Woman_StraightHair_S_02", "Woman_TwinBun_01", "Woman_TwinBun_02",
}
P.NB_MODELES = #P.CHEVEUX   -- coiffures des fichiers (models/haire/)
P.COUPES = {}
for k = 1, #P.NOMS_COUPES - 1 do
    P.CHEVEUX[#P.CHEVEUX + 1] = "models/hairs1_face.mdl"
    P.COUPES[#P.CHEVEUX] = k
end

-- Coiffure de l'ancien modèle (coupe 0 ou une des 91 autres) : va avec toutes les têtes
function P.EstClassique(indice) return indice == 0 or P.COUPES[indice] ~= nil end

-- Numéro du bodygroup à afficher pour le choix p (coiffures du modèle d'origine seulement)
function P.CoupeCheveux(p) return P.COUPES[p.cheveux] or 0 end

-- Logos de village des bandeaux (plaque de métal) : textures de materials/atg/hair/. Même
-- disposition pour les coiffures CTG (matériau "headband_symbol") et celles du pack d'origine
-- ("headgear") : ce sont les mêmes textures qui remplacent celle de la plaque.
local function LogoAtg(f) return "atg/hair/headband_atg/t_chr_headgear_metal_" .. f end
P.LOGOS = {
    { "Konoha", "atg/hair/t_chr_headgear_metal_konoha_01_bc" },
    { "Kiri", LogoAtg("kiri_01_bc") }, { "Kumo", LogoAtg("kumo_01_bc") }, { "Ame", LogoAtg("ame_01_bc") },
    { "Iwa", LogoAtg("iwa_01_bc") }, { "Suna", LogoAtg("sunagakure_01_bc") }, { "Kusa", LogoAtg("kusa_01_bc") },
    { "Oto", LogoAtg("oto_01_bc") }, { "Taki", LogoAtg("taki_bc") }, { "Abura", LogoAtg("abura_01_bc") },
    { "Yu", LogoAtg("yu_bc") }, { "Bee", LogoAtg("bee_01_bc") }, { "Med", LogoAtg("med_01_bc") },
    { "Équipe 1", LogoAtg("team01_01_bc") }, { "Équipe 3", LogoAtg("team03_01_bc") },
    { "Équipe 5", LogoAtg("team05_01_bc") }, { "Équipe 7", LogoAtg("team07_01_bc") },
    { "Équipe 9", LogoAtg("team09_01_bc") },
}

-- Aspect d'origine : rien ne change tant que le joueur n'a rien choisi
P.DEFAUT = {
    visage = 0, cheveux = 0, yeux = 1, nez = 0, sourcils = 1, barbe = 0, bouche = 1, recul = 7, logo = 0,
   
    peau = { 255, 210, 180 }, cheveux_c = { 0, 0, 0 },
    yeux_c = { 70, 45, 30 }, sourcils_c = { 0, 0, 0 }, bandeau_c = { 255, 255, 255 },
}

local function Nb(v, min, max, def)
    v = tonumber(v)
    if not v then return def end
    return math.Clamp(math.floor(v), min, max)
end

local function Rgb(t, def)
    if not istable(t) then t = {} end
    return { Nb(t[1], 0, 255, def[1]), Nb(t[2], 0, 255, def[2]), Nb(t[3], 0, 255, def[3]) }
end

-- Rend une table sûre (bornes, types) à partir de n'importe quoi : le serveur
-- l'applique à tout ce que le client envoie.
function P.Valider(t)
    if not istable(t) then t = {} end
    local d = P.DEFAUT
    local visage = Nb(t.visage, 0, P.NB_VISAGES, d.visage)
    -- les coiffures de models/haire/ ne vont qu'aux visages numérotés ; celles du modèle d'origine à tous
    local cheveux = Nb(t.cheveux, 0, #P.CHEVEUX, d.cheveux)
    if visage == 0 and not P.EstClassique(cheveux) then cheveux = 0 end
    return {
        visage     = visage,
        cheveux    = cheveux,
        yeux       = Nb(t.yeux,     1, #P.YEUX,       d.yeux),
        nez        = Nb(t.nez,      0, #P.NEZ,        d.nez),
        sourcils   = Nb(t.sourcils, 1, P.NB_SOURCILS, d.sourcils),
        barbe      = Nb(t.barbe,    0, P.NB_BARBES,   d.barbe),
        bouche     = Nb(t.bouche,   0, 1,             d.bouche),
        recul      = Nb(t.recul,    0, 40,            d.recul),
        logo       = Nb(t.logo,     0, #P.LOGOS,      d.logo),
        peau       = Rgb(t.peau,       d.peau),
        cheveux_c  = Rgb(t.cheveux_c,  d.cheveux_c),
        yeux_c     = Rgb(t.yeux_c,     d.yeux_c),
        sourcils_c = Rgb(t.sourcils_c, d.sourcils_c),
        bandeau_c  = Rgb(t.bandeau_c,  d.bandeau_c),
    }
end

-- Chemins des modèles de la tête et des cheveux
function P.ModeleTete(p)    return p.visage > 0 and ("models/head/face_" .. p.visage .. ".mdl") or "models/head_03.mdl" end
function P.ModeleCheveux(p)
    if p.cheveux > 0 and not P.COUPES[p.cheveux] then return P.CHEVEUX[p.cheveux] end
    return p.visage > 0 and "models/hairs1_face.mdl" or "models/hairs1_head.mdl"   -- copie adaptée aux visages
end

-- JSON <-> table validée (le texte est aussi ce que les clients lisent sur le joueur)
function P.Encoder(p) return util.TableToJSON(p) end

local decodes = {}
function P.Decoder(json)
    local p = decodes[json]
    if not p then
        p = P.Valider(json ~= "" and util.JSONToTable(json) or nil)
        decodes[json] = p
    end
    return p
end
