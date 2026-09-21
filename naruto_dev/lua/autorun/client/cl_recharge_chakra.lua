--========================================================
-- Recharge du chakra à la touche R (CLIENT)
--
-- Pendant la recharge (NW2Bool "NA_RechargeChakra", sv_sprint_chakra.lua),
-- vue par tout le monde :
--   - animation en boucle nrp_base_recoverychakra_loop ;
--   - particules chakra_recharge_pat (particles/patlick_chakra_rework.pcf).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local ANIM = "nrp_base_recoverychakra_loop"
local FX   = "chakra_recharge_pat"   -- variantes du fichier : chakra_recharge_pat_rouge, _bleu, _vert,
                                     -- _violet, _orange, _rose, _blanc, _noir
--========================================================

game.AddParticles("particles/patlick_chakra_rework.pcf")
PrecacheParticleSystem(FX)

----------------------------------------------------------
-- Animation (même principe que l'étourdissement, cl_etourdi_anim.lua)
----------------------------------------------------------
local function SeqRecharge(ply)
    if not IsValid(ply) or not ply:Alive() or not NA_EnRechargeChakra or not NA_EnRechargeChakra(ply) then return end
    local seq = ply:LookupSequence(ANIM)
    if seq and seq >= 0 then return seq end
end

hook.Add("CalcMainActivity", "NA_RechargeChakra_Anim", function(ply)
    local seq = SeqRecharge(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne la remplace pendant la recharge
hook.Add("UpdateAnimation", "NA_RechargeChakra_Anim_Force", function(ply)
    local seq = SeqRecharge(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

----------------------------------------------------------
-- Particules : créées au début de la recharge, arrêtées à la fin
----------------------------------------------------------
local actives = {}   -- joueur -> système de particules

hook.Add("Think", "NA_RechargeChakra_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local enRecharge = ply:Alive() and NA_EnRechargeChakra and NA_EnRechargeChakra(ply) and not ply:IsDormant()
        local ps = actives[ply]

        if enRecharge and not (ps and ps:IsValid()) then
            actives[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        elseif not enRecharge and ps then
            if ps:IsValid() then ps:StopEmission() end   -- les dernières particules finissent leur vie
            actives[ply] = nil
        end
    end

    for ply, ps in pairs(actives) do
        if not IsValid(ply) then
            if ps:IsValid() then ps:StopEmission() end
            actives[ply] = nil
        end
    end
end)

-- Vérifie que l'animation existe sur ton modèle : na_recharge_anim_check
concommand.Add("na_recharge_anim_check", function()
    local ply = LocalPlayer()
    local seq = ply:LookupSequence(ANIM)
    print(string.format("[Recharge chakra] %s sur %s : %s", ANIM, ply:GetModel(),
        (seq and seq >= 0) and ("OK (séquence " .. seq .. ")") or "ABSENTE"))
end)
