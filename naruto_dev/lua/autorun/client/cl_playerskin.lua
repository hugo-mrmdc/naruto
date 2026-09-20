--========================================================
-- Apparence du joueur (CLIENT) : tête et cheveux sur le corps après la mort
--
-- Vivant, la tête et les cheveux sont des props serveur fusionnés au joueur
-- (sv_playerskin.lua). À sa mort, le jeu crée un corps (ragdoll) côté client :
-- on y recopie la tête et les cheveux, sinon le corps tombe sans tête.
--========================================================

local surCorps = {}   -- ragdoll -> { modèles clientside }

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

    for _, d in ipairs(defs) do
        local modele = d[1]
        if modele ~= "" then
            local cs = ClientsideModel(modele, RENDERGROUP_OPAQUE)
            if IsValid(cs) then
                cs:SetParent(ragdoll)
                cs:AddEffects(EF_BONEMERGE)
                cs:AddEffects(EF_BONEMERGE_FASTCULL)
                cs:SetColor(Couleur(d[2]))
                pieces[#pieces + 1] = cs
            end
        end
    end

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
