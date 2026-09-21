--========================================================
-- Recharge du chakra à la touche R (PARTAGÉ serveur + client)
--
-- Le chakra ne remonte plus tout seul : on maintient R (+reload) pour le
-- recharger. La logique (début / fin, gain) est dans sv_sprint_chakra.lua,
-- l'animation et les particules dans cl_recharge_chakra.lua.
--
-- Ici : ce qui doit être PRÉDIT des deux côtés pendant la recharge
--   - on reste sur place (pas de déplacement ni de saut) ;
--   - NA_EnRechargeChakra(ply), lu par les armes (pas de coups) et les jutsus.
--
-- Réseau : NW2Bool "NA_RechargeChakra" (recharge en cours)
--========================================================

if SERVER then AddCSLuaFile() end

function NA_EnRechargeChakra(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_RechargeChakra", false)
end

-- immobile pendant la recharge
hook.Add("SetupMove", "NA_RechargeChakra_Immobile", function(ply, mv)
    if not NA_EnRechargeChakra(ply) then return end
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
    mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_JUMP)))
end)
