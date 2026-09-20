--========================================================
-- Recharges des techniques (PARTAGÉ serveur + client, chargé en premier)
--
-- Le serveur reste le seul juge : chaque technique garde sa propre recharge.
-- En plus, il l'inscrit sur le joueur (variable réseau) avec NA_CD.Set, ce qui
-- permet au client de griser l'emplacement, d'afficher le vrai décompte et de
-- ne pas lancer une technique qui n'est pas prête.
--========================================================

if SERVER then AddCSLuaFile() end

NA_CD = NA_CD or {}

local function CleFin(id) return "na_cd_" .. id end
local function CleTotal(id) return "na_cdt_" .. id end

if SERVER then
    -- Met la technique "id" en recharge pour "secondes" secondes
    function NA_CD.Set(ply, id, secondes)
        if not IsValid(ply) or not id then return end
        secondes = tonumber(secondes) or 0
        if secondes <= 0 then return end
        ply:SetNW2Float(CleFin(id), CurTime() + secondes)
        ply:SetNW2Float(CleTotal(id), secondes)
    end

    -- Annule une recharge (mort, réapparition...)
    function NA_CD.Clear(ply, id)
        if not IsValid(ply) or not id then return end
        ply:SetNW2Float(CleFin(id), 0)
    end
end

-- Secondes restantes avant que la technique soit prête (0 = prête)
function NA_CD.Reste(ply, id)
    if not IsValid(ply) or not id then return 0 end
    return math.max(0, ply:GetNW2Float(CleFin(id), 0) - CurTime())
end

-- Durée totale de la dernière recharge (pour dessiner le secteur)
function NA_CD.Total(ply, id)
    if not IsValid(ply) or not id then return 0 end
    return ply:GetNW2Float(CleTotal(id), 0)
end
