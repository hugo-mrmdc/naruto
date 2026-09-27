--========================================================
-- Hyuga : Tourbillon Divin (CLIENT)
-- Lancement depuis la barre de techniques. Particule [0]_Tourbillon_Divin
-- attachée au lanceur pendant toute la rotation ("hyuga_tourbillon_fx",
-- sv_hyuga_tourbillon.lua). Animation : contrôle direct de la séquence
-- principale (comme cl_etourdi_anim.lua), pas Jutsu_Anim_Play/gestes : ça
-- ne redémarre qu'au changement de séquence, donc la boucle tourne en
-- continu sans redémarrer sans arrêt pendant toute la durée.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "[0]_Tourbillon_Divin"   -- particles/solve_hyuga_dome.pcf
local FX_INSIDE = "tourbillon_inside_pat"   -- particles/patlick_atgparticules.pcf
local ANIM_LOOP = "m_ni_def_ninjutsu_palmrotation_loop"
local ANIM_FIN  = "m_ni_def_ninjutsu_palmrotation_end"
--========================================================

-- Séquence à forcer sur "ply" en ce moment (boucle tant que NA_TourbillonFin
-- est dans le futur, puis animation de fin tant que NA_TourbillonFinAnim l'est)
local function SeqTourbillon(ply)
    if ply:GetNW2Float("NA_TourbillonFin", 0) > CurTime() then
        local seq = ply:LookupSequence(ANIM_LOOP)
        if seq and seq >= 0 then return seq end
    end
    if ply:GetNW2Float("NA_TourbillonFinAnim", 0) > CurTime() then
        local seq = ply:LookupSequence(ANIM_FIN)
        if seq and seq >= 0 then return seq end
    end
end

hook.Add("CalcMainActivity", "NA_Tourbillon_Anim", function(ply)
    local seq = SeqTourbillon(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne la remplace tant que ça dure
hook.Add("UpdateAnimation", "NA_Tourbillon_Anim_Force", function(ply)
    local seq = SeqTourbillon(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

NA_Cast = NA_Cast or {}
NA_Cast.hyuga_tourbillon = function()
    net.Start("hyuga_tourbillon_cast")
    net.SendToServer()
end

game.AddParticles("particles/solve_hyuga_dome.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)
PrecacheParticleSystem(FX_INSIDE)

net.Receive("hyuga_tourbillon_fx", function()
    local ply = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    local fx = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0, vector_origin)
    local fxInside = CreateParticleSystem(ply, FX_INSIDE, PATTACH_ABSORIGIN_FOLLOW, 0, vector_origin)
    if not fx or not fx:IsValid() then return end

    timer.Simple(duree, function()
        if IsValid(fx) then fx:StopEmissionAndDestroyImmediately() end
        if IsValid(fxInside) then fxInside:StopEmissionAndDestroyImmediately() end
    end)
end)
