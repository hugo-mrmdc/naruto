--========================================================
-- Tenues (SERVEUR) : équiper / retirer depuis l'inventaire (cl_monmenu.lua)
--
-- La tenue choisie est mémorisée sur le joueur (ply.NA_Tenue) : elle est
-- remise à chaque réapparition par sv_playerskin.lua, au lieu de revenir
-- à la tenue par défaut.
--========================================================

util.AddNetworkString("NA_EquipArmure")
util.AddNetworkString("NA_UnequipArmure")

local COULEUR_CORPS = Color(255, 210, 180)
local DELAI_ANTI_SPAM = 0.5

local prochain = {}

local function Appliquer(ply, modele)
    ply:SetModel(modele)
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetColor(COULEUR_CORPS)

    -- tête et cheveux selon le nouveau modèle (retirés si la tenue a sa propre tête)
    if NA_AppliquerApparence then NA_AppliquerApparence(ply) end
end

local function Autorise(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if (prochain[ply] or 0) > CurTime() then return false end
    prochain[ply] = CurTime() + DELAI_ANTI_SPAM
    return true
end

net.Receive("NA_EquipArmure", function(_, ply)
    local modele = net.ReadString()
    if not Autorise(ply) then return end

    -- refuse les chemins bidons ou les modèles absents du serveur
    modele = string.lower(string.Trim(modele or ""))
    if not string.StartWith(modele, "models/") or not string.EndsWith(modele, ".mdl") then return end
    if not util.IsValidModel(modele) then return end

    ply.NA_Tenue = modele
    Appliquer(ply, modele)
end)

net.Receive("NA_UnequipArmure", function(_, ply)
    if not Autorise(ply) then return end

    ply.NA_Tenue = nil
    -- tenue par défaut : celle de sv_playerskin.lua
    Appliquer(ply, NA_TENUE_DEFAUT or "models/tenue/senju/genin/senju_a.mdl")
end)

hook.Add("PlayerDisconnected", "NA_Armure_Nettoyage", function(ply)
    prochain[ply] = nil
end)
