--========================================================
-- Animation d'étourdissement (CLIENT)
-- Tant qu'un joueur est étourdi (NW2Bool "NA_Etourdi" : cube Jinton, arche
-- Mokuton...), il joue cette animation en boucle, vue par tout le monde.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local ANIM = "act_stunning"
--========================================================

local function SeqEtourdi(ply)
    if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("NA_Etourdi", false) then return end
    -- une technique peut imposer sa propre animation (NW2String "NA_EtourdiAnim", ex : prison aqueuse)
    local perso = ply:GetNW2String("NA_EtourdiAnim", "")
    local seq = ply:LookupSequence(perso ~= "" and perso or ANIM)
    if (not seq or seq < 0) and perso ~= "" then seq = ply:LookupSequence(ANIM) end
    if seq and seq >= 0 then return seq end
end

hook.Add("CalcMainActivity", "NA_Etourdi_Anim", function(ply)
    local seq = SeqEtourdi(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- Diagnostic : liste les joueurs (bots compris) étourdis et dit pourquoi leur animation se joue ou non.
-- Console : na_etourdi_check
concommand.Add("na_etourdi_check", function()
    local n = 0
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNW2Bool("NA_Etourdi", false) then
            n = n + 1
            local perso = ply:GetNW2String("NA_EtourdiAnim", "")
            print(string.format("[Etourdi] %s | modèle %s | vivant %s | anim imposée '%s' -> séquence %d | anim par défaut '%s' -> séquence %d | séquence actuelle %d",
                ply:Nick(), ply:GetModel(), tostring(ply:Alive()), perso, perso ~= "" and ply:LookupSequence(perso) or -2,
                ANIM, ply:LookupSequence(ANIM), ply:GetSequence()))
        end
    end
    if n == 0 then print("[Etourdi] aucun joueur étourdi en ce moment (lance la commande pendant la prison)") end
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
