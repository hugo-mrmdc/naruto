--========================================================
-- Chinoike : Pluie de sang (CLIENT)
-- Lancement depuis la barre de techniques, et affichage de la pluie sur la
-- zone envoyée par le serveur ("chinoike_pluie_zone", sv_chinoike_pluie.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX       = "izox_chinoike_pluie"       -- particles/1atgyoltix.pcf
local HAUTEUR  = 320                         -- hauteur de la pluie au-dessus du sol
local FONDU    = 1.5                         -- secondes de disparition après la fin
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.chinoike_pluie = function()
    net.Start("chinoike_pluie_cast")
    net.SendToServer()
end

game.AddParticles("particles/1atgyoltix.pcf")
PrecacheParticleSystem(FX)

net.Receive("chinoike_pluie_zone", function()
    local pos = net.ReadVector()
    local duree = net.ReadFloat()

    -- ancre invisible : la pluie reste posée sur la zone
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(pos + Vector(0, 0, HAUTEUR))
    ancre:SetAngles(angle_zero)

    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)

    -- on coupe l'émission à la fin, puis on retire l'ancre une fois les
    -- dernières gouttes tombées
    timer.Simple(duree, function()
        if IsValid(ancre) then ancre:StopParticles() end
    end)
    timer.Simple(duree + FONDU, function()
        if IsValid(ancre) then ancre:Remove() end
    end)
end)
