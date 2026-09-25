--========================================================
-- Suiton : Bulles (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_suiton_bulle.lua, qui décide de tout).
-- Les bulles sont affichées par l'entité suiton_bulle (lua/entities).
--========================================================

-- particule des bulles (atg_bulle_eau), créée par l'entité
game.AddParticles("particles/atg_particules.pcf")
game.AddParticles("particles/atg_particules2.pcf")   -- jet_eau_hit_pat : explosion des bulles
PrecacheParticleSystem("atg_bulle_eau")
PrecacheParticleSystem("jet_eau_hit_pat")

-- Animation du lanceur pendant la salve : la même que le souffle katon (cl_katon_souffle.lua).
-- Lancée tout de suite (elle remplace l'animation d'incantation), sans "autokill" : elle boucle seule.
-- Relancée ensuite seulement si elle a disparu ET qu'aucune autre animation de jutsu (mudras d'une
-- autre technique) n'est en cours.
local SEQ = "nrp_ninjutsu_attack_d53nj2_handseal_loop"
local PROLONGE = 0.6   -- la pose reste un peu après la dernière bulle (la salve ne dure que 0,7 s)
local poses = {}   -- lanceur -> { seq, fin, prochain }

local function EnCours(ply, seq)
    for i = 0, 13 do
        if ply:GetLayerSequence(i) == seq and ply:GetLayerWeight(i) > 0 then return true end
    end
    return false
end

net.Receive("suiton_bulle_pose", function()
    local ply   = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    local seq = ply:LookupSequence(SEQ)
    if not seq or seq < 0 then
        if ply == LocalPlayer() then
            MsgC(Color(255, 80, 80), "[Bulles] animation introuvable sur ", ply:GetModel(), " : ", SEQ, "\n")
        end
        return
    end
    poses[ply] = { seq = seq, fin = CurTime() + duree + PROLONGE, prochain = 0, premiere = true }
end)

hook.Add("Think", "suiton_bulle_pose", function()
    for ply, p in pairs(poses) do
        if not IsValid(ply) or not ply:Alive() or CurTime() > p.fin then
            if IsValid(ply) then ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM) end
            poses[ply] = nil
        elseif p.premiere then
            -- première fois : tout de suite, sans attendre la fin de l'animation d'incantation
            p.premiere = false
            p.prochain = CurTime() + 0.3
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, p.seq, 0, false)
        elseif CurTime() >= p.prochain and CurTime() >= (ply.NA_AnimFin or 0) and not EnCours(ply, p.seq) then
            p.prochain = CurTime() + 0.3
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, p.seq, 0, false)
        end
    end
end)

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.suiton_bulle = function()
    net.Start("suiton_bulle_cast")
    net.SendToServer()
end
