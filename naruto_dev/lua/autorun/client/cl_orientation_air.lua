--========================================================
-- Orientation du corps en l'air (CLIENT)
--
-- En l'air (double saut, dash aérien...), le moteur ne tourne pas le corps : le perso garde
-- sa direction jusqu'à retoucher le sol. Ici le corps se tourne vers là où regarde la caméra,
-- rapidement mais sans à-coup.
--========================================================

local VITESSE = 900   -- degrés par seconde (plus haut = tourne plus vite, 0 = désactivé)

-- Cas où une autre orientation / animation prend la main (vol, ailes, course de chakra...)
local function AutreOrientation(ply)
    if ply:InVehicle() or ply:WaterLevel() >= 2 then return true end
    if ply:GetMoveType() ~= MOVETYPE_WALK then return true end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return true end
    if (ply:GetNWBool("MokutonRide", false) or ply:GetNWBool("InkutonRide", false)) or ply:GetNW2Bool("NA_Golem", false) then return true end
    return false
end

hook.Add("PrePlayerDraw", "NA_OrientationAir", function(ply)
    if VITESSE <= 0 or not ply:Alive() or ply:OnGround() or AutreOrientation(ply) then
        ply.NA_AirYaw = nil
        return
    end

    -- le cap n'avance qu'une fois par image (PrePlayerDraw est appelé plusieurs fois : ombres, reflets...)
    local now = CurTime()
    local cible = ply:EyeAngles().y
    if not ply.NA_AirYaw then
        -- GetRenderAngles peut renvoyer nil : sans cap connu, on part du regard
        local ra = ply:GetRenderAngles()
        ply.NA_AirYaw = ra and ra.y or cible
    elseif now ~= ply.NA_AirT then
        ply.NA_AirYaw = math.ApproachAngle(ply.NA_AirYaw, cible, (now - (ply.NA_AirT or now)) * VITESSE)
    end
    ply.NA_AirT = now

    ply:SetRenderAngles(Angle(0, ply.NA_AirYaw, 0))
    ply:InvalidateBoneCache()
end)
