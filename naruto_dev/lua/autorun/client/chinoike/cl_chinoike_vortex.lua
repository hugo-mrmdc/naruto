--========================================================
-- Chinoike : Vortex de sang (CLIENT)
-- Lancement depuis la barre de techniques, et affichage du vortex sur la
-- zone envoyée par le serveur ("chinoike_vortex_zone", sv_chinoike_vortex.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX       = "vortex_sang_pat"           -- particles/atg_particules2.pcf
local HAUTEUR  = 2                           -- décalage au-dessus du sol (évite que le cercle rentre dans le sol)
local FONDU    = 1.5                         -- secondes de disparition après la fin
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.chinoike_vortex = function()
    net.Start("chinoike_vortex_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_particules2.pcf")
PrecacheParticleSystem(FX)

net.Receive("chinoike_vortex_zone", function()
    local pos = net.ReadVector()
    local duree = net.ReadFloat()

    -- aspiration prédite côté client (sh_chinoike_vortex.lua)
    NA_VortexSang.Ajouter({
        centre       = pos,
        fin          = CurTime() + duree,
        lanceur      = net.ReadEntity(),
        rayon_attire = net.ReadFloat(),
        rayon_coeur  = net.ReadFloat(),
        force        = net.ReadFloat(),
        tourbillon   = net.ReadFloat(),
    })

    -- ancre invisible : le vortex reste posé à plat sur la zone
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(pos + Vector(0, 0, HAUTEUR))
    ancre:SetAngles(angle_zero)

    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)

    -- on coupe l'émission à la fin, puis on retire l'ancre une fois les
    -- dernières particules disparues
    timer.Simple(duree, function()
        if IsValid(ancre) then ancre:StopParticleEmission() end
    end)
    timer.Simple(duree + FONDU, function()
        if IsValid(ancre) then ancre:Remove() end
    end)
end)
