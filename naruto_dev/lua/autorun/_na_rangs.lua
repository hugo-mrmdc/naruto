--========================================================
-- Rangs des joueurs (PARTAGÉ serveur + client)
--
-- Le joueur a un rang ninja : Genin, Chûnin, Jônin, Kage. Chaque rang :
--   * donne plus de vie (pv) et plus de chakra maximum ;
--   * débloque l'accès aux techniques du rang correspondant
--     (technique rang C = Genin, B = Chûnin, A = Jônin, S = Kage).
-- Une technique d'un rang supérieur au sien ne peut ni se débloquer dans la
-- bibliothèque (F6), ni se lancer (NA_Debloquee, _na_niveaux.lua).
--
-- Le rang de chaque technique est dans NA_RANG_TECH plus bas (même valeur
-- que "rang" dans cl_techniques_ui.lua : à garder identique).
--
-- Monter de rang : bouton dans la bibliothèque (F6), coût en points de compétence.
-- Admin : na_rang <rang>, na_rang <joueur> <rang>, na_rang * <rang>
--         ou !rang <rang> / !rang <joueur> <rang> dans le chat
--         (rang = genin, chunin, jonin, kage ou 1 à 4)
--
-- Sauvegarde : PData du joueur, clé "na_rang".
--========================================================

if SERVER then AddCSLuaFile() end

NA_RANG = NA_RANG or {}

--========================================================
-- RÉGLAGES
--========================================================
-- Dans l'ordre : du plus faible au plus fort.
--   lettre = rang de technique accessible (C, B, A, S : toutes celles <= à cette lettre)
--   vie    = pv maximum
--   chakra = chakra maximum
--   cout   = points de compétence pour ATTEINDRE ce rang (le premier est gratuit)
NA_RANG.LISTE = {
    { id = "genin",  nom = "Genin",  lettre = "C", vie = 700, chakra = 500,  cout = 0  },
    { id = "geninConf",  nom = "geninConf",  lettre = "C", vie = 900, chakra = 800,  cout = 0  },
    { id = "tkc",  nom = "tkc",  lettre = "B", vie = 1300, chakra = 1200,  cout = 0  },
    { id = "chunin", nom = "Chûnin", lettre = "B", vie = 1600, chakra = 1400,  cout = 5  },
    { id = "chuninConf",  nom = "chuninConf",  lettre = "B", vie = 2000, chakra = 1600,  cout = 0  },
    { id = "tkj",  nom = "tkj",  lettre = "A", vie = 2700, chakra = 2000,  cout = 10 },
    { id = "jonin",  nom = "Jônin",  lettre = "A", vie = 3300, chakra = 3000,  cout = 10 },
     { id = "cmj",  nom = "cmj",  lettre = "S", vie = 4000, chakra = 3000,  cout = 10 },
    { id = "kage",   nom = "Kage",   lettre = "S", vie = 6000, chakra = 4500, cout = 20 },
}

-- Valeur des lettres de technique
local VALEUR = { C = 1, B = 2, A = 3, S = 4 }

-- Rang de chaque technique (identifiants NA_Cast)
NA_RANG_TECH = {
    katon_boule = "C", katon_dome = "C", katon_souffle = "C", katon_tornade = "B", katon_nuee = "A",
    katon_meteore = "S", katon_grosse_boule = "B", katon_saut = "C", katon_dragons = "B",
    uchiha_genjutsu = "B", uchiha_shuriken = "C", inkuton_chiens = "C", inkuton_singes = "B",
    inkuton_serpents = "C", inkuton_moine = "B", inkuton_dieux = "A", inkuton_dragon = "S",
    bakuton_oiseaux = "C", bakuton_mignons = "C", bakuton_araignees = "B", bakuton_meute = "B",
    bakuton_dragon = "B", bakuton_bombe = "S", futton_vapeur = "C", futton_tornade = "C", futton_cage = "B",
    futton_monde = "S", hyoton_dome = "C", hyoton_pics = "C", hyoton_vague = "B", hyoton_loup = "B",
    hyoton_prison = "A", shoton_cristal = "C", shoton_armure = "C", shoton_rockets = "B", shoton_pics = "A",
    shoton_chute = "B", futton_prison = "A", futton_projectile = "B", suiton_requin = "B",
    suiton_tsunami = "S", suiton_ocean = "A", suiton_pluie = "B", suiton_waterball = "C",
    suiton_prison = "C", suiton_bulle = "C", futon_windslash = "C", futon_tornade = "C",
    futon_windball = "C", futon_ouragan = "B", futon_grand_ouragan = "A", futon_expulsion = "B",
    futon_rasenshuriken = "S", raiton_jugement = "C", raiton_cercle = "C", raiton_zone = "B",
    raiton_chidori = "A", raiton_kirin = "S", raiton_poing = "B", raiton_boule = "C", doton_pierre = "C",
    doton_seisme = "C", doton_taupe = "C", doton_pics = "B", doton_dragon = "A", doton_golem = "S",
    doton_eruption = "B", mokuton_arche = "C", mokuton_fleur = "C", mokuton_protection = "C",
    mokuton_wood_hand = "B", mokuton_dragon = "B", mokuton_golem = "A", salamandre_dome = "B",
    salamandre_poison = "C", salamandre_tornade = "A", salamandre_corps = "B", fuma_tp = "C",
    fuma_jugement = "B", fuma_aura = "B", fuma_ciel = "A", fuma_invisibilite = "C", kami_circle = "B",
    kami_shuriken = "C", kami_bouclier = "B", kami_ailes = "A", kami_roue = "B", jinton_cube = "C",
    jinton_bouclier = "C", jinton_cubes = "B", jinton_cage = "B", jinton_laser = "A", kaguya_armure = "C", kaguya_legion = "A", kaguya_danse = "C",
    senju_renfo = "B", senju_soin = "B", senju_frappe = "B", senju_pied = "A", senju_ermite = "S",
    chinoike_ketsuryugan = "C", chinoike_genjutsu = "C", chinoike_pluie = "B", chinoike_vortex = "B",
    hyuga_byakugan = "C", hyuga_paume = "C", hyuga_32points = "B", hyuga_64points = "A",
    hyuga_tourbillon = "A", uchiha_sharingan = "C", kiminari_frappe = "C", kiminari_prison = "C",
    kiminari_laser = "B", kiminari_boulets = "A", jiton_sarcophage = "C", jiton_emergence = "C",
    jiton_vortex = "B", jiton_tornade = "B", jiton_nuage = "A", taijutsu_pied = "C",
    taijutsu_descendant = "C", kenjutsu_perforant = "C", kenjutsu_tourbillon = "C", kenjutsu_triple = "B", kenjutsu_allerretour = "B", kenjutsu_tornade = "A", taijutsu_combo = "B", taijutsu_releve = "B",
    taijutsu_rafale = "A",
}

--========================================================

NA_RANG.MAX = #NA_RANG.LISTE

function NA_RANG.Donnees(index)
    return NA_RANG.LISTE[math.Clamp(index or 1, 1, NA_RANG.MAX)]
end

-- Index du rang d'un joueur (1 = Genin). Non-joueur (PNJ, monde) : rang maximum.
function NA_Rang(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return NA_RANG.MAX end
    return math.Clamp(ply:GetNW2Int("NA_Rang", 1), 1, NA_RANG.MAX)
end

function NA_RANG.Nom(index)
    return NA_RANG.Donnees(index).nom
end

-- Rang minimum (index) pour utiliser la technique "id" (1 si elle n'a pas de rang)
function NA_RANG.RangRequis(id)
    return VALEUR[NA_RANG_TECH[id] or "C"] or 1
end

-- Le rang du joueur permet-il cette technique ?
function NA_RangOk(ply, id)
    return NA_Rang(ply) >= NA_RANG.RangRequis(id)
end

-- Chakra et vie maximum d'un joueur selon son rang
function NA_ChakraMax(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return NA_CHAKRA_MAX or 100 end
    return NA_RANG.Donnees(NA_Rang(ply)).chakra
end

function NA_VieMax(ply)
    return NA_RANG.Donnees(NA_Rang(ply)).vie
end

if CLIENT then return end

----------------------------------------------------------
-- Serveur : application, sauvegarde, promotion
----------------------------------------------------------
util.AddNetworkString("NA_Promotion")

-- Applique la vie maximum du rang. "soigner" = remplit aussi la vie
-- (apparition) ; sinon on ajoute seulement la vie gagnée (promotion).
local function AppliquerVie(ply, soigner)
    if not IsValid(ply) or not ply:Alive() then return end
    local ancien = ply:GetMaxHealth()
    local nouveau = NA_VieMax(ply)
    ply:SetMaxHealth(nouveau)
    if soigner then
        ply:SetHealth(nouveau)
    elseif nouveau > ancien then
        ply:SetHealth(math.min(ply:Health() + (nouveau - ancien), nouveau))
    else
        ply:SetHealth(math.min(ply:Health(), nouveau))
    end
end

local function AppliquerChakra(ply, soigner)
    local maxi = NA_ChakraMax(ply)
    local cur = ply:GetNW2Float("NA_Chakra", maxi)
    ply:SetNW2Float("NA_Chakra", soigner and maxi or math.min(cur, maxi))
end

local function Sauver(ply)
    ply:SetPData("na_rang", NA_Rang(ply))
end

local function Charger(ply)
    ply:SetNW2Int("NA_Rang", math.Clamp(tonumber(ply:GetPData("na_rang", 1)) or 1, 1, NA_RANG.MAX))
end

hook.Add("PlayerInitialSpawn", "NA_Rang_Charger", Charger)
hook.Add("PlayerDisconnected", "NA_Rang_Sauver", Sauver)

-- Après les autres scripts d'apparition (modèle, chakra...)
hook.Add("PlayerSpawn", "NA_Rang_Spawn", function(ply)
    timer.Simple(0, function()
        if not IsValid(ply) then return end
        AppliquerVie(ply, true)
        AppliquerChakra(ply, true)
    end)
end)

for _, ply in ipairs(player.GetAll()) do Charger(ply) AppliquerVie(ply, false) end

-- Change le rang (index 1 à 4). Pas de coût : voir Promouvoir / admin.
function NA_RANG.Definir(ply, index)
    if not IsValid(ply) then return end
    ply:SetNW2Int("NA_Rang", math.Clamp(index, 1, NA_RANG.MAX))
    Sauver(ply)
    AppliquerVie(ply, false)
    AppliquerChakra(ply, false)
end

-- Monte d'un rang en dépensant des points de compétence
net.Receive("NA_Promotion", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if (ply.NA_ProchainePromo or 0) > CurTime() then return end
    ply.NA_ProchainePromo = CurTime() + 0.5

    local rang = NA_Rang(ply)
    if rang >= NA_RANG.MAX then return end
    local suivant = NA_RANG.Donnees(rang + 1)
    if NA_Points(ply) < suivant.cout then return end

    ply:SetNW2Int("NA_Points", NA_Points(ply) - suivant.cout)
    NA_RANG.Definir(ply, rang + 1)
    ply:EmitSound("buttons/button14.wav", 60, 80)
    ply:ChatPrint("Promotion ! Tu es maintenant " .. suivant.nom .. " (" .. suivant.vie .. " PV, " .. suivant.chakra .. " chakra).")
    if NA_NIV and NA_NIV.Sauver then NA_NIV.Sauver(ply) end
end)

----------------------------------------------------------
-- Commande admin : na_rang <rang> | na_rang <joueur> <rang> | na_rang * <rang>
----------------------------------------------------------
local function Autorise(ply)
    if not IsValid(ply) then return true end
    return ply:IsSuperAdmin() or ply:IsListenServerHost() or game.SinglePlayer()
end

local function Repondre(ply, msg)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end

local function TrouverRang(txt)
    txt = string.lower(txt or "")
    local n = tonumber(txt)
    if n then return math.floor(n) >= 1 and math.floor(n) <= NA_RANG.MAX and math.floor(n) or nil end
    txt = string.gsub(txt, "û", "u")
    txt = string.gsub(txt, "ô", "o")
    for i, r in ipairs(NA_RANG.LISTE) do
        if r.id == txt then return i end
    end
end

local function CommandeRang(ply, args)
    if not Autorise(ply) then
        Repondre(ply, "Tu n'as pas le droit de changer les rangs.")
        return
    end

    local cibleTxt, rangTxt
    if #args <= 1 then rangTxt = args[1] else cibleTxt, rangTxt = args[1], args[2] end
    local index = TrouverRang(rangTxt)
    if not index then
        Repondre(ply, "Usage : na_rang <genin|chunin|jonin|kage>  |  na_rang <joueur> <rang>  |  na_rang * <rang>")
        return
    end

    local cibles = {}
    if not cibleTxt then
        if not IsValid(ply) then Repondre(ply, "Depuis la console serveur, précise un joueur.") return end
        cibles[1] = ply
    elseif cibleTxt == "*" then
        cibles = player.GetAll()
    else
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Nick()), string.lower(cibleTxt), 1, true) then cibles[1] = p break end
        end
    end
    if #cibles == 0 then Repondre(ply, "Joueur introuvable : " .. tostring(cibleTxt)) return end

    for _, p in ipairs(cibles) do
        NA_RANG.Definir(p, index)
        Repondre(ply, p:Nick() .. " est maintenant " .. NA_RANG.Nom(index) .. ".")
        if p ~= ply then p:ChatPrint("Ton rang est maintenant " .. NA_RANG.Nom(index) .. ".") end
    end
end

concommand.Add("na_rang", function(ply, _, args) CommandeRang(ply, args) end)

hook.Add("PlayerSay", "NA_Rang_Chat", function(ply, texte)
    local args = string.Explode(" ", string.Trim(texte))
    local cmd = string.lower(args[1] or "")
    if cmd ~= "!rang" and cmd ~= "/rang" then return end
    table.remove(args, 1)
    CommandeRang(ply, args)
    return ""
end)
