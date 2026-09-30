--========================================================
-- Senju : Frappe terrestre (CLIENT)
--
-- Envoie seulement l'appui au serveur (sv_senju_frappe.lua, qui décide de tout).
-- La particule d'impact est lancée par le serveur.
--========================================================

game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_pics_floor")

-- Animation du coup forcée sur la séquence de base tant que NA_FrappeFin est dans le futur
-- (comme cl_hyuga_32points.lua) : jouée en entier, même en l'air ou si le joueur atterrit pendant.
local ANIM = "m_attack_cmb09"   -- doit matcher ANIM_APPEL de sv_senju_frappe.lua

local function SeqFrappe(ply)
    local fin = ply:GetNW2Float("NA_FrappeFin", 0)
    if fin <= CurTime() then return end
    local seq = ply:LookupSequence(ANIM)
    if seq and seq >= 0 then return seq, fin end
end

hook.Add("CalcMainActivity", "NA_SenjuFrappe_Anim", function(ply)
    local seq = SeqFrappe(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

hook.Add("UpdateAnimation", "NA_SenjuFrappe_Anim_Force", function(ply)
    local seq, fin = SeqFrappe(ply)
    if not seq then return end
    local debut = ply:GetNW2Float("NA_FrappeDebut", 0)
    if ply:GetSequence() ~= seq then ply:SetSequence(seq) end
    -- cycle réglé à la main d'après le temps écoulé : une seule lecture, sans boucle
    ply:SetCycle(math.Clamp((CurTime() - debut) / math.max(fin - debut, 0.01), 0, 0.999))
    ply:SetPlaybackRate(0)
    return true
end)

NA_Cast = NA_Cast or {}
NA_Cast.senju_frappe = function()
    net.Start("senju_frappe_cast")
    net.SendToServer()
end
