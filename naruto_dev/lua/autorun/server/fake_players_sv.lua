--========================================================
-- Faux joueurs d'entraînement (SERVEUR)
--
-- Fait apparaître des faux joueurs (entité na_faux_joueur,
-- lua/entities/na_faux_joueur.lua) qu'on peut frapper et combo :
-- vie, barre au-dessus de la tête, chiffres de dégâts, jutsus, stun...
--
-- Commandes (console, admins seulement) :
--   fakeplayers_spawn [nombre] [vie]   ex : fakeplayers_spawn      -> 1 devant toi
--                                           fakeplayers_spawn 3 1000 -> 3 en cercle, 1000 PV
--   fakeplayers_clear                  supprime tous les faux joueurs
-- Dans le chat : !faux [nombre] [vie]  et  !fauxclear
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES
--========================================================
local MODELE      = "models/player/kleiner.mdl"
local VIE_DEFAUT  = 500     -- vie si on ne la précise pas
local MAX_NOMBRE  = 20      -- faux joueurs max par commande
local DISTANCE    = 120     -- distance devant toi (ou rayon du cercle)
--========================================================

NA_FauxJoueurs = NA_FauxJoueurs or {}
NA_FauxJoueurs.Liste = NA_FauxJoueurs.Liste or {}
NA_FauxJoueurs.Generation = NA_FauxJoueurs.Generation or 0   -- +1 à chaque fakeplayers_clear

function NA_FauxJoueurs.Creer(pos, ang, modele, vie)
    local ent = ents.Create("na_faux_joueur")
    if not IsValid(ent) then
        -- l'entité n'est pas chargée : un NOUVEAU fichier dans lua/entities
        -- n'est lu qu'au chargement de la map (le rechargement auto ne le voit pas)
        print("[Faux joueurs] entité na_faux_joueur introuvable : relance la map (changelevel / redémarrage)")
        return
    end

    ent.Modele = modele or MODELE
    ent.VieMax = vie or VIE_DEFAUT
    ent:SetPos(pos)
    ent:SetAngles(Angle(0, ang.y, 0))
    ent:Spawn()
    ent:Activate()

    table.insert(NA_FauxJoueurs.Liste, ent)
    return ent
end

local function Autorise(ply)
    return not IsValid(ply) or ply:IsAdmin()   -- console du serveur ou admin
end

-- Point au sol devant "pos" (évite de faire apparaître dans un mur ou en l'air)
local function AuSol(ply, pos)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 40),
        endpos = pos - Vector(0, 0, 200),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return tr.Hit and tr.HitPos or pos
end

local function Apparaitre(ply, nombre, vie)
    if not IsValid(ply) then return end
    if not Autorise(ply) then return ply:ChatPrint("Réservé aux admins.") end

    nombre = math.Clamp(math.floor(tonumber(nombre) or 1), 1, MAX_NOMBRE)
    vie = math.max(math.floor(tonumber(vie) or VIE_DEFAUT), 1)

    local base = ply:GetPos()
    local avant = ply:GetForward()
    avant.z = 0
    avant:Normalize()

    local crees = 0
    for i = 1, nombre do
        local pos
        if nombre == 1 then
            pos = base + avant * DISTANCE                              -- juste devant toi
        else
            local a = math.rad(ply:EyeAngles().y + (i - 1) * 360 / nombre)
            pos = base + Vector(math.cos(a), math.sin(a), 0) * DISTANCE -- en cercle autour de toi
        end
        pos = AuSol(ply, pos)

        -- tourné vers toi
        local ang = (base - pos):Angle()
        if IsValid(NA_FauxJoueurs.Creer(pos, ang, MODELE, vie)) then crees = crees + 1 end
    end

    if crees == 0 then
        return ply:ChatPrint("Aucun faux joueur créé : l'entité n'est pas chargée. Relance la map (changelevel) puis réessaie.")
    end
    ply:ChatPrint(string.format("%d faux joueur(s) de %d PV. fakeplayers_clear pour les supprimer.", crees, vie))
end

local function Supprimer(ply)
    if not Autorise(ply) then return end
    for _, ent in ipairs(ents.FindByClass("na_faux_joueur")) do ent:Remove() end
    NA_FauxJoueurs.Generation = NA_FauxJoueurs.Generation + 1   -- annule les réapparitions en attente
    NA_FauxJoueurs.Liste = {}
    if IsValid(ply) then ply:ChatPrint("Faux joueurs supprimés.") end
end

concommand.Add("fakeplayers_spawn", function(ply, _, args)
    Apparaitre(ply, args[1], args[2])
end)

concommand.Add("fakeplayers_clear", function(ply)
    Supprimer(ply)
end)

-- raccourcis dans le chat : !faux [nombre] [vie], !fauxclear
hook.Add("PlayerSay", "NA_FauxJoueurs_Chat", function(ply, texte)
    local args = string.Explode(" ", string.Trim(string.lower(texte)))
    if args[1] == "!faux" or args[1] == "/faux" then
        Apparaitre(ply, args[2], args[3])
        return ""
    elseif args[1] == "!fauxclear" or args[1] == "/fauxclear" then
        Supprimer(ply)
        return ""
    end
end)
