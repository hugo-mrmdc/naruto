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

-- La DERNIÈRE animation demandée est prioritaire :
--  * une nouvelle animation de stun (NW2Int "NA_EtourdiAnimId" change) relance l'anim, même si c'est la même
--  * une animation de jutsu jouée sur un joueur étourdi (Jutsu_Anim_Play, jutsu_anim_cl.lua) prend la main
--    pendant sa durée (ply.NA_JutsuPrioFin), sauf si un stun a redemandé la sienne après
local function Prioritaire(ply)
    local id = ply:GetNW2Int("NA_EtourdiAnimId", 0)
    if ply.NA_EtourdiAnimIdVu ~= id then
        ply.NA_EtourdiAnimIdVu = id
        ply.NA_EtourdiReqT = CurTime()
        ply.NA_EtourdiDebut = nil   -- repart de zéro
    end
    return (ply.NA_JutsuPrioFin or 0) > CurTime() and (ply.NA_JutsuPrioT or 0) >= (ply.NA_EtourdiReqT or 0)
end

local function SeqEtourdi(ply)
    if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("NA_Etourdi", false) then return end
    if Prioritaire(ply) then return end   -- une animation de jutsu plus récente passe devant
    -- une technique peut imposer sa propre animation (NW2String "NA_EtourdiAnim", ex : prison aqueuse)
    local perso = ply:GetNW2String("NA_EtourdiAnim", "")
    local seq = ply:LookupSequence(perso ~= "" and perso or ANIM)
    if (not seq or seq < 0) and perso ~= "" then seq = ply:LookupSequence(ANIM) end
    if seq and seq >= 0 then
        -- animation "une fois" terminée : on rend la main à l'animation normale (pas de figeage)
        -- (le début mémorisé doit être celui de CETTE séquence : sinon une anim imposée en plein stun,
        -- par ex. taijutsu pendant un cube Jinton, serait vue comme déjà terminée)
        if ply.NA_EtourdiDebut and ply.NA_EtourdiSeq == seq and ply:GetNW2Bool("NA_EtourdiUneFois", false)
            and CurTime() - ply.NA_EtourdiDebut >= ply:SequenceDuration(seq) then return end
        return seq
    end
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
    if not seq then
        -- le début n'est oublié qu'à la fin du stun (sinon l'anim "une fois" repartirait)
        if not ply:GetNW2Bool("NA_Etourdi", false) then ply.NA_EtourdiDebut = nil end
        return
    end
    if ply:GetSequence() ~= seq or not ply.NA_EtourdiDebut then
        ply:SetSequence(seq)
        ply:SetCycle(0)
        ply.NA_EtourdiDebut = CurTime()
        ply.NA_EtourdiSeq = seq
    end
    if ply:GetNW2Bool("NA_EtourdiUneFois", false) then
        -- animation imposée : jouée UNE fois (puis SeqEtourdi rend la main)
        local duree = ply:SequenceDuration(seq)
        local cycle = duree > 0 and (CurTime() - ply.NA_EtourdiDebut) / duree or 0
        ply:SetCycle(math.min(cycle, 1))
        ply:SetPlaybackRate(0)
    else
        ply:SetPlaybackRate(1)
    end
    return true
end)
