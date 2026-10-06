--========================================================
-- Aucun transfert de force par les dégâts (SERVEUR)
-- Un dégât ne doit faire QUE des dégâts : la cible ne bouge pas à cause d'eux. Deux protections :
--   1) la "force de dégât" (SetDamageForce) est remise à zéro, quelle que soit la source ;
--   2) si malgré cela la cible a gagné de la vitesse PENDANT le dégât (le moteur déduit une poussée de la position
--      de l'inflicteur, un autre script réagit aux dégâts...), cette vitesse est retirée tout de suite.
-- Les poussées VOLONTAIRES des techniques (SetVelocity donné APRÈS TakeDamageInfo : bump des mains, de la roue...)
-- ne sont pas touchées : elles arrivent après ce contrôle.
--========================================================

if not SERVER then return end

local POUSSEE_MIN = 60   -- gain de vitesse (u/s) au-delà duquel on considère que c'est une poussée

local function Vitesse(ent)
    if ent.loco then return ent.loco:GetVelocity() end
    return ent:GetVelocity()
end

hook.Add("EntityTakeDamage", "NA_SansForce", function(ent, dmg)
    dmg:SetDamageForce(vector_origin)
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
        ent.NA_VitesseAvantDegat = Vitesse(ent)
    end
end)

hook.Add("PostEntityTakeDamage", "NA_SansForce_Annuler", function(ent)
    local v0 = IsValid(ent) and ent.NA_VitesseAvantDegat
    if not v0 then return end
    ent.NA_VitesseAvantDegat = nil

    local delta = Vitesse(ent) - v0
    if delta:Length() < POUSSEE_MIN then return end
    if ent.loco then
        ent.loco:SetVelocity(ent.loco:GetVelocity() - delta)
    else
        ent:SetVelocity(-delta)   -- joueur / PNJ : SetVelocity AJOUTE à la vitesse actuelle
    end
end)
