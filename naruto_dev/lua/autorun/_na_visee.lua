--========================================================
-- Visée des techniques d'étourdissement (PARTAGÉ serveur + client)
--
-- NA_FindAlongRay(debut, fin, taille) : comme ents.FindAlongRay, mais SÛR quand on vise le bas du corps
-- (bassin, jambes). Le moteur ne renvoyait pas toujours la cible dans ce cas ; ici on ajoute tout joueur / PNJ
-- dont UN point du corps (pieds, jambes, bassin, torse, tête) passe à moins de "taille" du trajet.
-- "taille" : demi-largeur de la hitbox de visée (nombre ou Vector).
--========================================================

if SERVER then AddCSLuaFile() end

local POINTS = { 0, 0.25, 0.5, 0.75, 1 }   -- hauteurs testées le long du corps (0 = pieds, 1 = sommet de la tête)

function NA_FindAlongRay(debut, fin, taille)
    local r = isvector(taille) and taille.x or taille
    local vus, liste = {}, {}
    local function Ajouter(ent)
        if IsValid(ent) and not vus[ent] then vus[ent] = true liste[#liste + 1] = ent end
    end

    -- ce que le moteur trouve déjà
    for _, ent in ipairs(ents.FindAlongRay(debut, fin, Vector(-r, -r, -r), Vector(r, r, r))) do Ajouter(ent) end

    -- + les corps dont un point passe assez près du trajet
    local seg = fin - debut
    local long2 = seg:LengthSqr()
    for _, ent in ipairs(ents.FindInSphere(debut + seg * 0.5, math.sqrt(long2) * 0.5 + r + 150)) do
        if vus[ent] or not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot()) then continue end

        local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
        local pos = ent:GetPos()
        for _, f in ipairs(POINTS) do
            local p = pos + Vector(0, 0, mins.z + f * (maxs.z - mins.z))
            local t = long2 > 0 and math.Clamp((p - debut):Dot(seg) / long2, 0, 1) or 0
            if p:DistToSqr(debut + seg * t) <= r * r then Ajouter(ent) break end
        end
    end

    return liste
end
