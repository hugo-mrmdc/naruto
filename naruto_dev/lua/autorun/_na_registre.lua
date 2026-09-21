--========================================================
-- Registre des techniques (chargé en PREMIER : le "_" passe avant les autres noms)
--
-- Chaque technique range sa fonction de lancement dans NA_Cast.<id>.
-- La touche historique de la technique ET la barre de techniques (touches 1 à 6)
-- passent toutes les deux par NA_Lancer(id) : une seule logique de lancement,
-- et une technique en recharge ne peut pas être lancée.
--========================================================

if SERVER then
    AddCSLuaFile()
    return
end

NA_Cast = NA_Cast or {}

-- Touches historiques des techniques (N, Y, H, B, T, I...).
-- false = les techniques ne se lancent QUE depuis la barre (touches 1 à 6).
-- true  = les anciennes touches marchent aussi.
local TOUCHES_DIRECTES = false

function NA_TouchesDirectes()
    return TOUCHES_DIRECTES
end

----------------------------------------------------------
-- Recharges
-- Deux sources, on garde la plus longue :
--   1) la vraie recharge envoyée par le serveur (NA_CD, _na_cooldowns.lua) ;
--   2) la durée "cd" de la liste des techniques, comptée depuis le dernier
--      lancement : elle couvre le temps d'incantation, avant que le serveur
--      ait enregistré quoi que ce soit.
----------------------------------------------------------
NA_DernierLancer = NA_DernierLancer or {}
NA_DernierRefus = NA_DernierRefus or {}

local function CdListe(id)
    local info = NA_TechniqueParId and NA_TechniqueParId(id)
    local cd = info and info.cd or 0
    -- la recharge baisse avec le niveau de la technique (_na_niveaux.lua)
    if cd > 0 and NA_Stat then cd = NA_Stat(LocalPlayer(), id, "recharge", cd) end
    return cd
end

-- Secondes restantes avant de pouvoir relancer "id"
function NA_ResteRecharge(id)
    local ply = LocalPlayer()
    local serveur = (NA_CD and IsValid(ply)) and NA_CD.Reste(ply, id) or 0

    local local_ = 0
    local dernier = NA_DernierLancer[id]
    local cd = CdListe(id)
    if dernier and cd > 0 then
        local_ = math.max(0, cd - (CurTime() - dernier))
    end

    return math.max(serveur, local_)
end

-- Durée totale de la recharge en cours (pour le secteur de la barre)
function NA_DureeRecharge(id)
    local ply = LocalPlayer()
    local serveurReste = (NA_CD and IsValid(ply)) and NA_CD.Reste(ply, id) or 0
    local serveurTotal = (NA_CD and IsValid(ply)) and NA_CD.Total(ply, id) or 0
    local cd = CdListe(id)

    local dernier = NA_DernierLancer[id]
    local localReste = (dernier and cd > 0) and math.max(0, cd - (CurTime() - dernier)) or 0

    if serveurReste >= localReste and serveurTotal > 0 then
        return serveurTotal
    end
    return cd > 0 and cd or serveurTotal
end

----------------------------------------------------------
-- Lancement
----------------------------------------------------------
-- developer 1 : raison des refus affichée dans la console
local function Diag(id, raison)
    local dev = GetConVar("developer")
    if dev and dev:GetInt() > 0 then print("[Techniques] " .. id .. " refusé : " .. raison) end
end

function NA_Lancer(id)
    local fn = NA_Cast[id]
    if not fn then return false end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return false end

    -- pas encore débloquée dans la bibliothèque (F6, _na_niveaux.lua)
    if NA_Debloquee and not NA_Debloquee(ply, id) then
        NA_DernierRefus[id] = CurTime()
        notification.AddLegacy("Technique verrouillée : débloque-la dans la bibliothèque (F6).", NOTIFY_ERROR, 3)
        Diag(id, "pas débloquée")
        return false
    end

    -- immobilisé (cube Jinton...) : pas de jutsu
    if ply:GetNW2Bool("NA_Etourdi", false) then
        NA_DernierRefus[id] = CurTime()
        Diag(id, "tu es immobilisé")
        return false
    end

    -- mains vides ou mode caméra : pas de jutsu (cl_selecteur_armes.lua)
    if NA_JutsuBloque and NA_JutsuBloque(ply) then
        NA_DernierRefus[id] = CurTime()   -- la case clignote en rouge, sans son
        Diag(id, "mains vides ou mode caméra")
        return false
    end

    -- en recharge : pas utilisable
    if NA_ResteRecharge(id) > 0 then
        Diag(id, string.format("en recharge (%.1f s)", NA_ResteRecharge(id)))
        NA_DernierRefus[id] = CurTime()   -- la case clignote en rouge, sans son
        return false
    end

    local ok, err = pcall(fn)
    if not ok then
        MsgC(Color(255, 80, 80), "[Techniques] erreur en lançant " .. id .. " : " .. tostring(err) .. "\n")
        return false
    end

    NA_DernierLancer[id] = CurTime()

    -- un jutsu lancé pendant l'invisibilité Fuma fait réapparaître (sv_fumainv.lua)
    if id ~= "fuma_invisibilite" and ply:GetNWBool("IsInvisible", false) then
        net.Start("Invis_Reveler")
        net.SendToServer()
    end

    -- lancer une technique coupe la course de chakra (sv_sprint_chakra.lua)
    if ply:GetNW2Bool("NA_ChakraRun", false) then
        net.Start("NA_ArretCourseChakra")
        net.SendToServer()
    end
    return true
end
