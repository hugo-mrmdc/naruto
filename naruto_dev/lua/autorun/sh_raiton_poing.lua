--========================================================
-- Raiton : Poing de foudre (PARTAGÉ serveur + client)
--
-- Pendant le plongeon, la vitesse est tenue vers la direction choisie par le serveur
-- (NW2Vector "NA_RaitonPoingDir" jusqu'à "NA_RaitonPoingFin"). Fait dans SetupMove, exécuté par le
-- serveur ET en prédiction par le client : le plongeon est fluide, sans à-coups.
-- Le reste de la technique est dans server/raiton/sv_raiton_poing.lua (même principe que le Coup de pied Senju).
--========================================================

if SERVER then AddCSLuaFile() end

hook.Add("SetupMove", "NA_RaitonPoing_Plongeon", function(ply, mv)
    if ply:GetNW2Float("NA_RaitonPoingFin", 0) <= CurTime() then return end

    local v = ply:GetNW2Vector("NA_RaitonPoingDir", vector_origin)
    if v:LengthSqr() > 1 then mv:SetVelocity(v) end
end)
