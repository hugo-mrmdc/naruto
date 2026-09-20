--[[
    Naruto RP - point d'entrée client
]]

include("shared.lua")

local HIDDEN_HUD = {
    CHudHealth = true,
    CHudBattery = true,
    CHudAmmo = true,
    CHudSecondaryAmmo = true,
    CHudWeaponSelection = true,
    CHudDamageIndicator = true,
}

function GM:HUDShouldDraw(name)
    if HIDDEN_HUD[name] then return false end
    return self.BaseClass.HUDShouldDraw(self, name)
end

-- Menus sandbox réservés aux joueurs autorisés (vérifié aussi côté serveur).
-- Menu Q : staff, ou tout le monde pour prendre les armes autorisées (config/compat.lua).
-- Le serveur refuse tout le reste.
function GM:SpawnMenuOpen()
    return NRP.Perm.Has(LocalPlayer(), "admin.sandbox") or NRP.Config.Compat.SpawnMenuForPlayers == true
end

-- Menu C : staff uniquement, et jamais avec les mains ninja (C = garde par défaut)
function GM:ContextMenuOpen()
    local wep = LocalPlayer():GetActiveWeapon()
    if IsValid(wep) and wep:GetClass() == "nrp_hands" then return false end
    return NRP.Perm.Has(LocalPlayer(), "admin.sandbox")
end

-- Pas de nom de joueur Source au-dessus des têtes : le module HUD dessine le nom RP.
function GM:HUDDrawTargetID()
end
