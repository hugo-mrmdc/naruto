--========================================================
-- Chinoike : Ketsuryugan (CLIENT)
-- Lancement / arrêt depuis la barre de techniques, et flash des yeux à
-- l'activation ("chinoike_ketsuryugan_on", sv_chinoike_ketsuryugan.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_OEIL = "ketsuryugan_pat"   -- particles/patlick_atgparticules.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.chinoike_ketsuryugan = function()
    net.Start("chinoike_ketsuryugan_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_OEIL)

-- les yeux s'allument à l'activation (attache "eyes", sinon en haut du corps)
net.Receive("chinoike_ketsuryugan_on", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end

    local att = ply:LookupAttachment("eyes")
    if att and att > 0 then
        CreateParticleSystem(ply, FX_OEIL, PATTACH_POINT_FOLLOW, att)
    else
        CreateParticleSystem(ply, FX_OEIL, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ply:OBBMaxs().z * 0.9))
    end
end)
