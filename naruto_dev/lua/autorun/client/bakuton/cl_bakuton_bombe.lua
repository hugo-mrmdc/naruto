--========================================================
-- Bakuton : Déflagration (CLIENT)
-- Lancement depuis la barre de techniques. Pendant la montée / l'attente dans le ciel, le lanceur
-- garde la pose de mudra (même pose que le dragon d'argile).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_bombe = function()
    net.Start("bakuton_bombe_cast")
    net.SendToServer()
end

local SEQ_POSE = "nrp_lobby_shikamaru_etc_team_type1_wait_loop"

local function EnMontee(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Float("NA_MonteVit", -1) >= 0
end

hook.Add("CalcMainActivity", "NA_BakutonBombe_Anim", function(ply)
    if not EnMontee(ply) then return end
    local seq = ply:LookupSequence(SEQ_POSE)
    if seq and seq >= 0 then return ACT_INVALID, seq end
    return ACT_HL2MP_IDLE, -1
end)

hook.Add("UpdateAnimation", "NA_BakutonBombe_Anim_Update", function(ply)
    if not EnMontee(ply) then return end
    local seq = ply:LookupSequence(SEQ_POSE)
    if seq and seq >= 0 and ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)
