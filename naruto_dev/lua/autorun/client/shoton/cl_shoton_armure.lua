--========================================================
-- Shoton : Armure de cristal (CLIENT)
-- solve_custom_bone_pink_emeraude s'accroche lui-même à tous les os du modèle ("Position on Model Random" +
-- "Movement Lock to Bone") : il suffit de l'attacher au joueur, une seule fois.
--========================================================

local FX = "solve_custom_bone_pink_emeraude"   -- particles/solve_shoton_emeraude.pcf

NA_Cast = NA_Cast or {}
NA_Cast.shoton_armure = function()
    net.Start("shoton_armure_cast")
    net.SendToServer()
end

local actifs = {}   -- joueur -> système de particules

local function Arreter(ply)
    if IsValid(actifs[ply]) then actifs[ply]:StopEmission() end
    actifs[ply] = nil
end

hook.Add("Think", "NA_ShotonArmure_Particules", function()
    for _, ply in ipairs(player.GetAll()) do
        local veut = ply:Alive() and ply:GetNW2Bool("NA_ShotonArmure", false) and not ply:GetNWBool("IsInvisible", false)
        if veut and not IsValid(actifs[ply]) then
            actifs[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW)
        elseif not veut and actifs[ply] then
            Arreter(ply)
        end
    end
end)

hook.Add("EntityRemoved", "NA_ShotonArmure_Nettoyage", function(ent)
    if ent:IsPlayer() then Arreter(ent) end
end)
