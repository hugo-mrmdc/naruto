--========================================================
-- Niveaux des techniques (PARTAGÉ serveur + client, chargé en premier)
--
-- Chaque technique a un niveau de 0 à 5. Niveau 0 = verrouillée : on ne peut
-- ni la lancer ni l'équiper. On la débloque (niveau 1) puis on l'améliore dans
-- la bibliothèque (F6, cl_bibliotheque.lua) avec des points de compétence.
--
-- Valeurs par niveau :
--   * réglage PAR TECHNIQUE dans _na_niveaux_techniques.lua : pour chaque
--     niveau, on change n'importe quelle stat (dégâts, durée, rayon...) ;
--   * sinon, réglage général PAR_NIVEAU ci-dessous (en pourcentage).
-- Les fichiers serveur des techniques lisent leurs valeurs avec
-- NA_Stat(ply, id, "nom_de_la_stat", valeur_de_base).
--
-- Sauvegarde : PData du joueur (sv.db), clés "na_niveaux" et "na_points".
-- Ajouter des points : na_points <nombre>, na_points <joueur> <nombre>, ou !points dans le chat
--========================================================

if SERVER then AddCSLuaFile() end

NA_NIV = NA_NIV or {}

--========================================================
-- RÉGLAGES
--========================================================
NA_NIV.MAX = 5

-- Effet de CHAQUE niveau au-dessus du 1 (niveau 5 = 4 fois l'effet)
--   degats   : +10 % par niveau  -> +40 % au niveau 5
--   chakra   : -5 % par niveau   -> -20 % au niveau 5
--   recharge : -5 % par niveau   -> -20 % au niveau 5
-- (sert seulement aux stats qu'une technique ne règle PAS dans _na_niveaux_techniques.lua)
NA_NIV.PAR_NIVEAU = {
    degats        = 0.10,
    soin          = 0.10,
    chakra        = -0.05,
    recharge      = -0.05,
    recharge_rate = -0.05,   -- recharge raccourcie quand le Jugement Fuma rate
}

-- Points nécessaires pour débloquer la technique (niveau 1),
-- puis pour passer au niveau 2, 3, 4, 5
NA_NIV.COUT = { [0] = 1, 1, 2, 3, 4 }

NA_NIV.POINTS_DEPART   = 5   -- points d'un nouveau joueur
NA_NIV.POINTS_PAR_KILL = 1   -- points gagnés en tuant un autre joueur

-- Techniques qui ont des niveaux (identifiants NA_Cast)
NA_NIV.IDS = {
    "katon_boule", "katon_saut", "suiton_requin",
    "mokuton_arche", "mokuton_fleur", "mokuton_dragon",
    "salamandre_dome", "salamandre_poison", "salamandre_tornade", "salamandre_corps",
    "fuma_tp", "fuma_jugement", "fuma_aura", "fuma_ciel", "fuma_invisibilite",
    "kami_circle", "kami_shuriken", "kami_bouclier", "kami_ailes",
    "jinton_cube", "jinton_bouclier", "jinton_laser",
    "kaguya_armure", "kaguya_legion", "kaguya_danse",
    "chinoike_pluie", "chinoike_vortex",
}
--========================================================

local valide = {}
for _, id in ipairs(NA_NIV.IDS) do valide[id] = true end

function NA_NIV.Existe(id)
    return valide[id] == true
end

-- Niveau d'une technique pour un joueur (0 = pas encore débloquée).
-- Lanceur qui n'est pas un joueur (PNJ, monde) : niveau 1.
function NA_Niveau(ply, id)
    if not IsValid(ply) or not ply:IsPlayer() or not id then return 1 end
    return math.Clamp(ply:GetNW2Int("na_niv_" .. id, 0), 0, NA_NIV.MAX)
end

-- La technique est-elle débloquée ? (les techniques sans niveau le sont toujours)
function NA_Debloquee(ply, id)
    if not NA_NIV.Existe(id) then return true end
    return NA_Niveau(ply, id) >= 1
end

-- Points de compétence disponibles
function NA_Points(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return 0 end
    return ply:GetNW2Int("NA_Points", 0)
end

-- Coût pour passer du niveau "niveau" au suivant (0 -> 1 = déblocage ; nil = maximum)
function NA_NIV.Cout(niveau)
    return NA_NIV.COUT[niveau]
end

-- Multiplicateur d'une valeur au niveau donné
function NA_NIV.Multiplicateur(genre, niveau)
    local pas = NA_NIV.PAR_NIVEAU[genre] or 0
    return math.max(0, 1 + pas * (math.max(niveau or 1, 1) - 1))   -- verrouillée = valeurs du niveau 1
end

-- Stats réglées niveau par niveau (remplies par _na_niveaux_techniques.lua)
NA_NIV_TECH = NA_NIV_TECH or {}

-- Valeur réglée pour "genre" au niveau donné. Un niveau qui ne précise pas
-- une stat garde celle du niveau d'avant (niveau 3 sans "degats" = dégâts du 2).
-- nil si la technique ne règle pas cette stat.
function NA_NIV.Reglee(id, genre, niveau)
    local t = NA_NIV_TECH[id]
    if not t then return nil end
    for n = math.Clamp(niveau or 1, 1, NA_NIV.MAX), 1, -1 do
        local v = t[n] and t[n][genre]
        if v ~= nil then return v end
    end
    return nil
end

-- Valeur d'une stat à un niveau (sans joueur : sert aussi à l'affichage F6)
function NA_NIV.Valeur(id, genre, niveau, base)
    local v = NA_NIV.Reglee(id, genre, niveau)
    if v ~= nil then return v end
    return (tonumber(base) or 0) * NA_NIV.Multiplicateur(genre, niveau)
end

-- Valeur d'une technique au niveau du joueur.
-- Le lanceur peut être autre chose qu'un joueur (PNJ, monde) : valeurs du niveau 1.
function NA_Stat(ply, id, genre, base)
    local niveau = 1
    if IsValid(ply) and ply:IsPlayer() then niveau = NA_Niveau(ply, id) end
    return NA_NIV.Valeur(id, genre, niveau, base)
end

if CLIENT then return end

----------------------------------------------------------
-- Serveur : chargement, sauvegarde, amélioration
----------------------------------------------------------
util.AddNetworkString("NA_Ameliorer")

local function Sauver(ply)
    local t = {}
    for _, id in ipairs(NA_NIV.IDS) do
        local n = NA_Niveau(ply, id)
        if n >= 1 then t[id] = n end
    end
    ply:SetPData("na_niveaux", util.TableToJSON(t))
    ply:SetPData("na_points", NA_Points(ply))
end

local function Charger(ply)
    local t = util.JSONToTable(ply:GetPData("na_niveaux", "") or "") or {}
    for _, id in ipairs(NA_NIV.IDS) do
        ply:SetNW2Int("na_niv_" .. id, math.Clamp(tonumber(t[id]) or 0, 0, NA_NIV.MAX))
    end
    ply:SetNW2Int("NA_Points", tonumber(ply:GetPData("na_points", NA_NIV.POINTS_DEPART)) or NA_NIV.POINTS_DEPART)
end

hook.Add("PlayerInitialSpawn", "NA_Niveaux_Charger", Charger)
hook.Add("PlayerDisconnected", "NA_Niveaux_Sauver", Sauver)

-- rechargement du fichier (lua_refresh) : on recharge les joueurs déjà là
for _, ply in ipairs(player.GetAll()) do Charger(ply) end

function NA_NIV.DonnerPoints(ply, n)
    if not IsValid(ply) then return end
    ply:SetNW2Int("NA_Points", math.max(0, NA_Points(ply) + n))
    Sauver(ply)
end

net.Receive("NA_Ameliorer", function(_, ply)
    local id = net.ReadString()
    if not IsValid(ply) or not NA_NIV.Existe(id) then return end

    -- anti-spam
    if (ply.NA_ProchaineAmelio or 0) > CurTime() then return end
    ply.NA_ProchaineAmelio = CurTime() + 0.2

    local niveau = NA_Niveau(ply, id)
    local cout = NA_NIV.Cout(niveau)
    if not cout then return end                       -- déjà au maximum
    if NA_Points(ply) < cout then return end          -- pas assez de points

    ply:SetNW2Int("NA_Points", NA_Points(ply) - cout)
    ply:SetNW2Int("na_niv_" .. id, niveau + 1)
    Sauver(ply)
    ply:EmitSound("buttons/button14.wav", 60, 110)
end)

-- points gagnés en tuant un autre joueur
hook.Add("PlayerDeath", "NA_Niveaux_Kill", function(victime, _, attaquant)
    if NA_NIV.POINTS_PAR_KILL <= 0 then return end
    if not IsValid(attaquant) or not attaquant:IsPlayer() or attaquant == victime then return end
    NA_NIV.DonnerPoints(attaquant, NA_NIV.POINTS_PAR_KILL)
end)

----------------------------------------------------------
-- Ajouter des points de compétence
--   Console : na_points <nombre>             -> à toi
--             na_points <joueur> <nombre>    -> à un joueur (nom, même partiel)
--             na_points * <nombre>           -> à tout le monde
--   Chat    : !points <nombre>  /  !points <joueur> <nombre>
--   Un nombre négatif retire des points.
-- Réservé aux superadmins, à l'hôte d'une partie locale et à la console serveur.
----------------------------------------------------------
local function Autorise(ply)
    if not IsValid(ply) then return true end   -- console serveur
    return ply:IsSuperAdmin() or ply:IsListenServerHost() or game.SinglePlayer()
end

local function Repondre(ply, msg)
    if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
end

local function AjouterPoints(ply, args)
    if not Autorise(ply) then
        Repondre(ply, "Tu n'as pas le droit d'ajouter des points.")
        return
    end

    -- "na_points 10" = à soi-même
    local cibleTxt, n
    if #args == 1 then
        n = tonumber(args[1])
    else
        cibleTxt, n = args[1], tonumber(args[2] or "")
    end
    if not n then
        Repondre(ply, "Usage : na_points <nombre>  |  na_points <joueur> <nombre>  |  na_points * <nombre>")
        return
    end
    n = math.floor(n)

    local cibles = {}
    if not cibleTxt or cibleTxt == "moi" then
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
        NA_NIV.DonnerPoints(p, n)
        Repondre(ply, p:Nick() .. " a maintenant " .. NA_Points(p) .. " points de compétence.")
        if p ~= ply then
            p:ChatPrint((n >= 0 and "Tu as reçu " or "Tu as perdu ") .. math.abs(n) .. " points de compétence (F6).")
        end
    end
end

concommand.Add("na_points", function(ply, _, args) AjouterPoints(ply, args) end)

hook.Add("PlayerSay", "NA_Niveaux_ChatPoints", function(ply, texte)
    local args = string.Explode(" ", string.Trim(texte))
    local cmd = string.lower(args[1] or "")
    if cmd ~= "!points" and cmd ~= "/points" then return end
    table.remove(args, 1)
    AjouterPoints(ply, args)
    return ""   -- la commande n'apparaît pas dans le chat
end)
