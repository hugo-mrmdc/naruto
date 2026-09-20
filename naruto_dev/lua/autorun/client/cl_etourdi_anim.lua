--========================================================
-- Animation d'étourdissement (CLIENT)
-- Tant qu'un joueur est étourdi (NW2Bool "NA_Etourdi" : cube Jinton, arche
-- Mokuton...), il joue cette animation en boucle, vue par tout le monde.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local ANIM = "nrp_beaten_bellydown_large_loop"
--========================================================

local function SeqEtourdi(ply)
    if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("NA_Etourdi", false) then return end
    local seq = ply:LookupSequence(ANIM)
    if seq and seq >= 0 then return seq end
end

hook.Add("CalcMainActivity", "NA_Etourdi_Anim", function(ply)
    local seq = SeqEtourdi(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne la remplace pendant l'étourdissement
hook.Add("UpdateAnimation", "NA_Etourdi_Anim_Force", function(ply)
    local seq = SeqEtourdi(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)
