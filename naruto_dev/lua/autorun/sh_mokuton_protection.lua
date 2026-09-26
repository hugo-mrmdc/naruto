--========================================================
-- Mokuton : Protection de bois (PARTAGÉ serveur + client)
--
-- Dans le cocon (NW2Bool "NA_Hobi", mokuton_protection_sv.lua) : le joueur ne bouge plus du tout
-- (ni déplacement, ni saut, ni élan, ni poussée à l'horizontale), mais la caméra reste libre.
-- Fait dans StartCommand + SetupMove, exécutés par le serveur ET en prédiction par le client :
-- pas d'à-coup.
--========================================================

if SERVER then AddCSLuaFile() end

hook.Add("StartCommand", "MokutonProtection_Touches", function(ply, cmd)
    if not ply:GetNW2Bool("NA_Hobi", false) then return end
    cmd:ClearMovement()
    cmd:RemoveKey(bit.bor(IN_JUMP, IN_DUCK, IN_SPEED))
end)

hook.Add("SetupMove", "MokutonProtection_Immobile", function(ply, mv)
    if not ply:GetNW2Bool("NA_Hobi", false) then return end
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
    mv:SetUpSpeed(0)
    mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_JUMP, IN_DUCK, IN_SPEED))))
    local vel = mv:GetVelocity()
    mv:SetVelocity(Vector(0, 0, math.min(vel.z, 0)))   -- plus d'élan ; la chute continue
end)
