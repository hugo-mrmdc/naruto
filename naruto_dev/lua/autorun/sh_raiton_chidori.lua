--========================================================
-- Raiton : Chidori (PARTAGÉ serveur + client)
--
-- Tant que NW2Float "NA_ChidoriFin" est dans le futur, le joueur est tenu par la technique :
--   - NW2Float "NA_ChidoriVit" = 0 : phase de CHARGE, il reste immobile (horizontalement) ;
--   - NW2Float "NA_ChidoriVit" > 0 : phase de COURSE, sa vitesse horizontale est tenue à cette valeur, dans la direction
--     où il REGARDE à chaque instant : il peut TOURNER en courant (il dirige la course avec la souris).
-- Fait dans SetupMove, exécuté par le serveur ET en prédiction par le client : la course est fluide, sans à-coups.
-- Le reste de la technique est dans server/raiton/sv_raiton_chidori.lua et client/raiton/cl_raiton_chidori.lua.
--========================================================

if SERVER then AddCSLuaFile() end

hook.Add("SetupMove", "NA_Chidori_Course", function(ply, mv)
    if ply:GetNW2Float("NA_ChidoriFin", 0) <= CurTime() then return end

    local vit = ply:GetNW2Float("NA_ChidoriVit", 0)
    local cur = mv:GetVelocity()
    if vit > 0 then
        local dir = Angle(0, mv:GetAngles().y, 0):Forward()
        mv:SetVelocity(Vector(dir.x * vit, dir.y * vit, cur.z))   -- course : la verticale (gravité) n'est pas touchée
    else
        mv:SetVelocity(Vector(0, 0, cur.z))                        -- charge : immobile
    end
end)
