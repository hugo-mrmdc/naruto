--========================================================
-- Yeux du joueur (SERVEUR)
--
-- Remplace la texture des yeux de la tête (models/head_03.mdl, posée par
-- sv_playerskin.lua) : Ketsuryugan, Sharingan, Byakugan...
-- Les textures sont dans materials/models/naruto_dev/yeux/ : copies des yeux
-- d'origine avec un IRIS RÉDUIT (x0.8), sinon les paupières de la tête ne
-- laissent pas voir le blanc de l'œil. Générées par tools/reduire_yeux.py.
-- Les yeux "normaux" utilisent aussi leur copie réduite (normal.vmt).
--
-- Choix gardé dans le NW2String "NA_Yeux" (chemin du matériau, "" = yeux normaux) :
-- il est réappliqué à chaque nouvelle tête et recopié sur le corps après
-- la mort (cl_playerskin.lua).
--
-- Commandes (admins) :
--   na_yeux <nom> [joueur]   ex : na_yeux ketsuryugan     (sur toi)
--   na_yeux normal [joueur]       -> yeux normaux
--   Chat : !yeux <nom> [joueur]
--   na_yeux sans argument : liste des yeux disponibles
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES
--========================================================
local DOSSIER = "models/naruto_dev/yeux/"

-- yeux sans rien de choisi (copie réduite de l'œil d'origine de la tête)
NA_YEUX_NORMAUX = DOSSIER .. "normal"

-- nom de commande -> matériau (sans .vmt), tous dans materials/models/naruto_dev/yeux/
NA_YEUX = {}
for _, nom in ipairs({
    "ketsuryugan", "sharingan1", "sharingan2", "sharingan3", "byakugan", "mangekyou",
    "itachi", "sasuke", "obito", "shisui", "madara", "mugen", "ermite_crapaud", "ermite_serpent",
}) do
    NA_YEUX[nom] = DOSSIER .. nom
end

-- Index des matériaux des yeux dans models/head_03.mdl (gauche, droite)
local INDEX_YEUX = { 3, 4 }
--========================================================

-- envoyées aux joueurs (le .vtf du même nom part avec le .vmt)
resource.AddFile("materials/" .. NA_YEUX_NORMAUX .. ".vmt")
for _, mat in pairs(NA_YEUX) do resource.AddFile("materials/" .. mat .. ".vmt") end

-- Pose les yeux choisis sur la tête actuelle du joueur
function NA_AppliquerYeux(ply)
    if not IsValid(ply) then return end
    local tete = ply.NA_Head
    if not IsValid(tete) then return end
    if tete:GetModel() ~= "models/head_03.mdl" then return end   -- les visages personnalisés (models/head/) ont leurs propres yeux

    local mat = ply:GetNW2String("NA_Yeux", "")
    if mat == "" then mat = NA_YEUX_NORMAUX end   -- yeux normaux : copie à iris réduit
    for _, i in ipairs(INDEX_YEUX) do
        tete:SetSubMaterial(i, mat)
    end
end

-- Change les yeux d'un joueur (nom de NA_YEUX, ou "normal" / nil pour les yeux normaux)
function NA_ChangerYeux(ply, nom)
    if not IsValid(ply) then return false end
    local mat = ""
    if nom and nom ~= "normal" then
        mat = NA_YEUX[nom]
        if not mat then return false end
    end
    ply:SetNW2String("NA_Yeux", mat)
    NA_AppliquerYeux(ply)
    return true
end

local function Liste()
    local noms = table.GetKeys(NA_YEUX)
    table.sort(noms)
    return "normal, " .. table.concat(noms, ", ")
end

local function Commande(ply, nom, cibleNom)
    if IsValid(ply) and not ply:IsAdmin() then
        return ply:ChatPrint("Réservé aux admins.")
    end

    local function Dire(msg)
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end

    if not nom or nom == "" then return Dire("Yeux disponibles : " .. Liste()) end
    nom = string.lower(nom)

    -- cible : un joueur dont le nom contient cibleNom, sinon soi-même
    local cible = ply
    if cibleNom and cibleNom ~= "" then
        cible = nil
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(cibleNom), 1, true) then cible = p break end
        end
        if not cible then return Dire("Joueur introuvable : " .. cibleNom) end
    end
    if not IsValid(cible) then return Dire("Précise un joueur : na_yeux <nom> <joueur>") end

    if not NA_ChangerYeux(cible, nom) then
        return Dire("Yeux inconnus : " .. nom .. ". Disponibles : " .. Liste())
    end
    Dire(string.format("Yeux de %s : %s", cible:Nick(), nom))
end

concommand.Add("na_yeux", function(ply, _, args)
    Commande(ply, args[1], args[2])
end)

hook.Add("PlayerSay", "NA_Yeux_Chat", function(ply, texte)
    local args = string.Explode(" ", string.Trim(texte))
    if string.lower(args[1] or "") == "!yeux" or string.lower(args[1] or "") == "/yeux" then
        Commande(ply, args[2], args[3])
        return ""
    end
end)
