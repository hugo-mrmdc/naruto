--========================================================
-- Senju : Coup de pied céleste (PARTAGÉ serveur + client)
--
-- Pendant le plongeon, la vitesse est tenue vers la direction choisie par le serveur
-- (NW2Vector "NA_SenjuPiedDir" jusqu'à "NA_SenjuPiedFin"). Fait dans SetupMove, exécuté par le
-- serveur ET en prédiction par le client : le plongeon est fluide, sans à-coups.
-- Le reste de la technique est dans server/senju/sv_senju_pied.lua.
--========================================================

if SERVER then AddCSLuaFile() end

hook.Add("SetupMove", "NA_SenjuPied_Plongeon", function(ply, mv)
    if ply:GetNW2Float("NA_SenjuPiedFin", 0) <= CurTime() then return end

    local v = ply:GetNW2Vector("NA_SenjuPiedDir", vector_origin)
    if v:LengthSqr() > 1 then mv:SetVelocity(v) end
end)
