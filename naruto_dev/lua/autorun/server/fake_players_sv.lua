--========================================================
-- Faux joueurs d'entraînement (SERVEUR)
--
-- Fait apparaître des faux joueurs (entité na_faux_joueur,
-- lua/entities/na_faux_joueur.lua) qu'on peut frapper et combo :
-- vie, barre au-dessus de la tête, chiffres de dégâts, jutsus, stun...
--
-- (Les vrais bots GMod sont impossibles en singleplayer : "Cannot create a
-- player bot in singleplayer!" C'est pour ça qu'on reste sur ce nextbot.)
--
-- Commandes (console, admins seulement) :
--   fakeplayers_spawn [nombre] [vie]   ex : fakeplayers_spawn      -> 1 devant toi
--                                           fakeplayers_spawn 3 1000 -> 3 en cercle, 1000 PV
--   fakeplayers_spawn_moi [vie]        1 faux joueur à TA tenue (corps, tête,
--                                      cheveux, yeux) : pour voir les animations
--                                      de tes coups sur ton propre modèle
--   fakeplayers_clear                  supprime tous les faux joueurs
-- Dans le chat : !faux [nombre] [vie], !fauxmoi [vie], !fauxclear
--========================================================

if not SERVER then return end

--========================================================
-- RÉGLAGES
--========================================================
local MODELE      = "models/player/kleiner.mdl"
local VIE_DEFAUT  = 4000     -- vie si on ne la précise pas
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

----------------------------------------------------------
-- Faux joueur à TA PROPRE apparence (tenue, tête, cheveux, yeux) : pour voir
-- les animations de tes coups/techniques sur ton propre modèle.
--   fakeplayers_spawn_moi [vie]   ou  !fauxmoi [vie] dans le chat
----------------------------------------------------------

-- Copie une pièce fusionnée (tête / cheveux, sv_playerskin.lua) sur "base"
local function CreerPieceSur(base, modele, couleur, sousMateriau0, bodygroup0, bodygroup1)
    if not modele or modele == "" then return end
    local ent = ents.Create("prop_dynamic")
    if not IsValid(ent) then return end

    ent:SetModel(modele)
    ent:SetPos(base:GetPos())
    ent:SetAngles(base:GetAngles())
    ent:Spawn()

    ent:SetParent(base)
    ent:AddEffects(EF_BONEMERGE)
    ent:AddEffects(EF_BONEMERGE_FASTCULL)
    ent:AddEffects(EF_PARENT_ANIMATES)
    ent:SetSolid(SOLID_NONE)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetOwner(base)
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    ent:SetColor(couleur or color_white)
    if sousMateriau0 and sousMateriau0 ~= "" then ent:SetSubMaterial(0, sousMateriau0) end
    if bodygroup0 then ent:SetBodygroup(0, bodygroup0) end
    if bodygroup1 then ent:SetBodygroup(1, bodygroup1) end

    return ent
end

local function ApparaitreAvecMaTenue(ply, vie)
    if not IsValid(ply) then return end
    if not Autorise(ply) then return ply:ChatPrint("Réservé aux admins.") end

    vie = math.max(math.floor(tonumber(vie) or VIE_DEFAUT), 1)

    local base = ply:GetPos()
    local avant = ply:GetForward()
    avant.z = 0
    avant:Normalize()

    local pos = AuSol(ply, base + avant * DISTANCE)
    local ang = (base - pos):Angle()

    local bot = NA_FauxJoueurs.Creer(pos, ang, ply:GetModel(), vie)
    if not IsValid(bot) then
        return ply:ChatPrint("Aucun faux joueur créé : l'entité n'est pas chargée. Relance la map (changelevel) puis réessaie.")
    end

    -- tête + cheveux : mêmes modèle, peau, coiffure que le joueur
    if IsValid(ply.NA_Head) then
        local tete = CreerPieceSur(bot, ply.NA_Head:GetModel(), ply.NA_Head.__NA_NormalColor,
            ply.NA_Head:GetSubMaterial(0), ply.NA_Head:GetBodygroup(0), ply.NA_Head:GetBodygroup(1))

        -- yeux choisis par le joueur (sous-matériaux 3 et 4, sv_yeux.lua)
        local yeux = ply:GetNW2String("NA_Yeux", "")
        if yeux ~= "" and IsValid(tete) then
            tete:SetSubMaterial(3, yeux)
            tete:SetSubMaterial(4, yeux)
        end
    end
    if IsValid(ply.NA_Hair) then
        CreerPieceSur(bot, ply.NA_Hair:GetModel(), ply.NA_Hair.__NA_NormalColor, nil, ply.NA_Hair:GetBodygroup(0))
    end

    bot:SetColor(ply:GetColor())   -- teinte de peau du corps

    ply:ChatPrint(string.format("Faux joueur à ta tenue créé (%d PV). fakeplayers_clear pour le supprimer.", vie))
end

concommand.Add("fakeplayers_spawn_moi", function(ply, _, args)
    ApparaitreAvecMaTenue(ply, args[1])
end)

-- raccourcis dans le chat : !faux [nombre] [vie], !fauxclear, !fauxmoi [vie]
hook.Add("PlayerSay", "NA_FauxJoueurs_Chat", function(ply, texte)
    local args = string.Explode(" ", string.Trim(string.lower(texte)))
    if args[1] == "!faux" or args[1] == "/faux" then
        Apparaitre(ply, args[2], args[3])
        return ""
    elseif args[1] == "!fauxclear" or args[1] == "/fauxclear" then
        Supprimer(ply)
        return ""
    elseif args[1] == "!fauxmoi" or args[1] == "/fauxmoi" then
        ApparaitreAvecMaTenue(ply, args[2])
        return ""
    end
end)
