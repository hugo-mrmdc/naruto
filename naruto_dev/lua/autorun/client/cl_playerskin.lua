--========================================================
-- Apparence du joueur (CLIENT) : tête et cheveux sur le corps après la mort
--
-- Vivant, la tête et les cheveux sont des props serveur fusionnés au joueur
-- (sv_playerskin.lua). À sa mort, le jeu crée un corps (ragdoll) côté client :
-- on y recopie la tête et les cheveux, sinon le corps tombe sans tête.
--========================================================

local surCorps = {}   -- ragdoll -> { modèles clientside }

-- Matériaux d'une COPIE de la tête (corps après la mort, portrait du HUD) :
-- visage teinté couleur peau (matériau 0) et yeux choisis (3 et 4, sv_yeux.lua).
-- La vraie tête du joueur les reçoit déjà du serveur (sv_playerskin.lua).
function NA_MateriauxTete(cs, ply)
    if not IsValid(cs) or not IsValid(ply) then return end

    -- visage personnalisé (models/head/) : peau, yeux, sourcils... (cl_perso.lua)
    local p = NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", ""))
    if p.visage > 0 then return NA_HabillerVisage(cs, p, ply:GetNW2String("NA_Yeux", "")) end

    local visage = ply:GetNW2String("NA_TeteVisage", "")
    if visage ~= "" then cs:SetSubMaterial(0, visage) end

    local yeux = ply:GetNW2String("NA_Yeux", "")
    if yeux == "" then yeux = "models/naruto_dev/yeux/normal" end   -- = NA_YEUX_NORMAUX
    cs:SetSubMaterial(3, yeux)
    cs:SetSubMaterial(4, yeux)
end

local function Couleur(v)
    if not v then return color_white end
    return Color(v.x, v.y, v.z)
end

local function Habiller(ragdoll, ply)
    local pieces = {}
    local defs = {
        { ply:GetNW2String("NA_TeteModele", ""),    ply:GetNW2Vector("NA_TeteCouleur") },
        { ply:GetNW2String("NA_CheveuxModele", ""), ply:GetNW2Vector("NA_CheveuxCouleur") },
    }

    for n, d in ipairs(defs) do
        local modele = d[1]
        if modele ~= "" then
            local cs = ClientsideModel(modele, RENDERGROUP_OPAQUE)
            if IsValid(cs) then
                cs:SetParent(ragdoll)
                cs:AddEffects(EF_BONEMERGE)
                cs:AddEffects(EF_BONEMERGE_FASTCULL)
                cs:SetColor(Couleur(d[2]))

                -- la tête garde son visage et les yeux choisis
                if n == 1 then NA_MateriauxTete(cs, ply) end
                if n == 2 then NA_TeinterCheveux(cs, NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", ""))) end

                -- corps : yeux fermés (flex de clignement, voir cl_clignement.lua)
                local blink = n == 1 and cs:GetFlexIDByName("basic_blink")
                if blink then cs:SetFlexWeight(blink, 1) end
                if n == 1 and cs.NA_Forme then NA_PoserFormes(cs, 1) end   -- visages personnalisés

                pieces[#pieces + 1] = cs
            end
        end
    end

    NA_PeauCorps(ragdoll, NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", "")))
    surCorps[ragdoll] = pieces
end

local function Retirer(ragdoll)
    for _, cs in ipairs(surCorps[ragdoll] or {}) do
        if IsValid(cs) then cs:Remove() end
    end
    surCorps[ragdoll] = nil
end

-- Vérification légère, 5 fois par seconde
local prochain = 0
hook.Add("Think", "NA_Apparence_Corps", function()
    if CurTime() < prochain then return end
    prochain = CurTime() + 0.2

    for _, ply in ipairs(player.GetAll()) do
        if not ply:Alive() then
            local ragdoll = ply:GetRagdollEntity()
            if IsValid(ragdoll) and not surCorps[ragdoll] then
                Habiller(ragdoll, ply)
            end
        end
    end

    -- corps disparus : on nettoie leurs pièces
    for ragdoll in pairs(surCorps) do
        if not IsValid(ragdoll) then Retirer(ragdoll) end
    end
end)

hook.Add("EntityRemoved", "NA_Apparence_CorpsRetire", function(ent)
    if surCorps[ent] then Retirer(ent) end
end)
