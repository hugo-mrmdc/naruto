--========================================================
-- Dégâts affichés (SERVEUR)
-- À chaque dégât infligé par un joueur à un joueur / PNJ, on envoie le montant
-- à l'attaquant, qui l'affiche au-dessus de la cible (cl_degats_affiches.lua).
-- Toutes les sources passent par là : armes, poings, jutsus...
--========================================================

util.AddNetworkString("NA_Degats")

hook.Add("PostEntityTakeDamage", "NA_DegatsAffiches", function(cible, dmg, pris)
    if not pris or not IsValid(cible) then return end
    if not (cible:IsPlayer() or cible:IsNPC() or cible:IsNextBot()) then return end

    local attaquant = dmg:GetAttacker()
    if not IsValid(attaquant) or not attaquant:IsPlayer() or attaquant == cible then return end

    local montant = dmg:GetDamage()
    if montant < 0.5 then return end

    -- posé par sv_degats_type.lua (ou directement par NRP.Combat.Damage) juste avant TakeDamageInfo
    local estJutsu = cible.NRPTypeDegats == "jutsu"

    net.Start("NA_Degats")
        net.WriteUInt(cible:EntIndex(), 16)
        net.WriteVector(cible:GetPos() + Vector(0, 0, cible:OBBMaxs().z + 6))   -- au-dessus de la tête
        net.WriteUInt(math.min(math.Round(montant), 65535), 16)
        net.WriteBool(estJutsu)
    net.Send(attaquant)
end)
