--========================================================
-- Chinoike : Vortex de sang, aspiration des JOUEURS (PARTAGÉ serveur + client)
--
-- Faite dans SetupMove, exécutée par le serveur ET en prédiction par le client :
-- le joueur aspiré glisse sans à-coups. (Avant : SetVelocity côté serveur toutes
-- les 0,05 s, que le client ne prévoyait pas -> corrections = micro-lags.)
--
-- Les vortex actifs sont ajoutés par sv_chinoike_vortex.lua (serveur) et par le
-- message "chinoike_vortex_zone" (client, cl_chinoike_vortex.lua).
-- PNJ / nextbots : toujours déplacés par le serveur (sv_chinoike_vortex.lua).
--========================================================

NA_VortexSang = NA_VortexSang or { liste = {} }

-- v = { centre, fin, lanceur, rayon_attire, rayon_coeur, force, tourbillon }
function NA_VortexSang.Ajouter(v)
    table.insert(NA_VortexSang.liste, v)
end

-- on n'aspire pas à travers les murs
local function Visible(depuis, vers)
    return not util.TraceLine({ start = depuis, endpos = vers, mask = MASK_SOLID_BRUSHONLY }).Hit
end

hook.Add("SetupMove", "ChinoikeVortex_Aspiration", function(ply, mv)
    local liste = NA_VortexSang.liste
    if #liste == 0 or not ply:Alive() then return end

    local now = CurTime()
    local dt = FrameTime()
    local origine = mv:GetOrigin()
    local vel

    for i = #liste, 1, -1 do
        local v = liste[i]
        if now >= v.fin then
            table.remove(liste, i)
        elseif v.lanceur ~= ply then
            local vers = v.centre - origine
            vers.z = 0
            local dist = vers:Length()

            -- déjà au centre (< 30) : pas de tremblement
            if dist >= 30 and dist <= v.rayon_attire
                and Visible(v.centre + Vector(0, 0, 40), origine + ply:OBBCenter()) then
                local dir = vers / dist
                local tangente = Vector(-dir.y, dir.x, 0)
                -- l'aspiration faiblit près du centre, sinon on le dépasse et on fait des allers-retours
                local attenuation = math.Clamp(dist / v.rayon_coeur, 0.25, 1)

                vel = vel or mv:GetVelocity()
                vel = vel + (dir * v.force * attenuation + tangente * v.tourbillon) * dt
            end
        end
    end

    if vel then mv:SetVelocity(vel) end
end)
