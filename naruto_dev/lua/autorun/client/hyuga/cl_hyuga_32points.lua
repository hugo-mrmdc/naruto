--========================================================
-- Hyuga : 32 Points du Hakke (CLIENT)
-- Lancement depuis la barre de techniques (l'animation passe par
-- Jutsu_Anim_Play, jutsu_anim_cl.lua, sans code ici). Explosion de chakra
-- (aegvfc) sur la cible touchée ("hyuga_32points_fx", sv_hyuga_32points.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_IMPACT = "aegvfc"   -- particles/ctg_hyuga_nael.pcf
local ANIM_LOOP = "attack_hyuga_64poings_slow"   -- doit matcher ANIM_APPEL de sv_hyuga_32points.lua
--========================================================

-- Séquence à forcer sur "ply" tant que NA_Hakke32PoingsFin est dans le futur
-- (comme cl_etourdi_anim.lua / cl_hyuga_tourbillon.lua) : boucle sans
-- redémarrer sans arrêt tant que le stun (et donc la rafale) n'est pas fini.
local function SeqHakke32(ply)
    if ply:GetNW2Float("NA_Hakke32PoingsFin", 0) > CurTime() then
        local seq = ply:LookupSequence(ANIM_LOOP)
        if seq and seq >= 0 then return seq end
    end
end

hook.Add("CalcMainActivity", "NA_Hakke32Poings_Anim", function(ply)
    local seq = SeqHakke32(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne la remplace tant que ça dure
hook.Add("UpdateAnimation", "NA_Hakke32Poings_Anim_Force", function(ply)
    local seq = SeqHakke32(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

NA_Cast = NA_Cast or {}
NA_Cast.hyuga_32points = function()
    net.Start("hyuga_32points_cast")
    net.SendToServer()
end

game.AddParticles("particles/ctg_hyuga_nael.pcf")
PrecacheParticleSystem(FX_IMPACT)

net.Receive("hyuga_32points_fx", function()
    local ent = net.ReadEntity()
    local etourdi = net.ReadFloat()   -- durée réelle du stun (Niv, sv_hyuga_32points.lua) : la particule doit disparaître pile à ce moment
    if not IsValid(ent) then return end

    local fx = CreateParticleSystem(ent, FX_IMPACT, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ent:OBBMaxs().z * 0.5))
    if not fx or not fx:IsValid() then return end

    timer.Simple(etourdi, function()
        if IsValid(fx) then fx:StopEmissionAndDestroyImmediately() end
    end)
end)
