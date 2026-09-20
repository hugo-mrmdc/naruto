--========================================================
-- Jinton : Rayon de dissolution (CLIENT)
-- Lancement depuis la barre de techniques. Le laser est l'entité jinton_laser,
-- le vol celui des ailes de papier (NW2Bool "NA_Vol").
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
-- Animation jouée pendant le laser ("" = animations normales)
local ANIM_LASER = "nrp_ninjutsu_attack_aerial_d45nj1_loop"
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_laser = function()
    net.Start("jinton_laser_cast")
    net.SendToServer()
end

local function EnLaser(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_Vol", false)
        and not ply:GetNW2Bool("NA_Wings", false)
end

local function SeqLaser(ply)
    if ANIM_LASER == "" or not EnLaser(ply) then return end
    local seq = ply:LookupSequence(ANIM_LASER)
    if seq and seq >= 0 then return seq end
end

hook.Add("CalcMainActivity", "JintonLaser_Anim", function(ply)
    local seq = SeqLaser(ply)
    if seq then return ACT_MP_STAND_IDLE, seq end
end)

-- forcée à chaque image : aucune autre animation ne peut la remplacer pendant le laser
hook.Add("UpdateAnimation", "JintonLaser_Anim_Force", function(ply)
    local seq = SeqLaser(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then ply:SetSequence(seq) end
    ply:SetPlaybackRate(1)
    return true
end)
