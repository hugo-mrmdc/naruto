-- CLIENT: garrysmod/lua/autorun/client/mokuton_dragon_cl.lua

local NET_SPAWN = "mokuton_dragon_spawn"
local NET_KILL  = "mokuton_dragon_kill"

print("[MOKUTON CL] Loaded")

-- Touche : B = spawn, L = remove
local lastB, lastL, lastE = false, false, false

-- Caméra : on recule pendant le vol (le dragon est énorme), puis on remet la
-- distance d'avant. Avant : deux valeurs en dur, et mourir en vol laissait la
-- caméra bloquée à 500 pour toujours (la convar est sauvegardée).
local RIDE_DIST = 300
local savedDist = nil

local function SetTPSDist(v)
    RunConsoleCommand("na_tps_dist_cl", tostring(v))
end

local function EnterRideView()
    if savedDist then return end
    local c = GetConVar("na_tps_dist_cl")
    savedDist = (c and c:GetInt()) or 150
    SetTPSDist(RIDE_DIST)
end

local function LeaveRideView()
    if not savedDist then return end
    SetTPSDist(savedDist)
    savedDist = nil
end

-- La vue suit l'état réel envoyé par le serveur, pas l'appui sur la touche :
-- ainsi la caméra revient aussi quand le vol s'arrête sans toi (mort, dragon perdu).
hook.Add("Think", "MokutonDragon_CameraState", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:Alive() and lp:GetNWBool("MokutonRide", false) then
        EnterRideView()
    else
        LeaveRideView()
    end
end)

-- Une seule détection de touches (avant : PlayerButtonDown ET Think envoyaient chaque appui deux fois)
hook.Add("Think", "MokutonDragon_KeyFallback", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() then
        lastB, lastL, lastE = false, false, false
        return
    end
    if not lp:Alive() then
        lastB, lastL, lastE = false, false, false
        return
    end

    local direct = NA_TouchesDirectes()

    local pressedB = input.IsKeyDown(KEY_B)
    if pressedB and not lastB and direct then
        net.Start("mokuton_dragon_spawn")
        net.SendToServer()
    end
    lastB = pressedB

    local pressedL = input.IsKeyDown(KEY_L)
    if pressedL and not lastL and direct then
        net.Start("mokuton_dragon_kill")
        net.SendToServer()
    end
    lastL = pressedL

    -- E pour attraper reste actif en vol, même sans touches directes
    local pressedE = input.IsKeyDown(KEY_E)
    if pressedE and not lastE and lp:GetNWBool("MokutonRide", false) then
        net.Start("mokuton_dragon_grab")
        net.SendToServer()
    end
    lastE = pressedE
end)

-- Barre de techniques : un seul emplacement pour le dragon.
-- Invoque le dragon, ou le renvoie si tu es déjà dessus.
NA_Cast = NA_Cast or {}
NA_Cast.mokuton_dragon = function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    net.Start(lp:GetNWBool("MokutonRide", false) and "mokuton_dragon_kill" or "mokuton_dragon_spawn")
    net.SendToServer()
end

-- ✅ Force l'animation de handseal côté CLIENT
hook.Add("CalcMainActivity", "Mokuton_ForceHandseal_CL", function(ply, vel)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end -- ✅ AJOUT
    if not ply:GetNWBool("MokutonRide", false) then return end

    local seqId = ply:LookupSequence("nrp_lobby_shikamaru_etc_team_type1_wait_loop")
    if seqId and seqId >= 0 then
        return ACT_INVALID, seqId
    end

    return ACT_HL2MP_IDLE, -1
end)

hook.Add("UpdateAnimation", "Mokuton_ForceHandseal_Update_CL", function(ply, vel, maxSeqGroundSpeed)
    if not IsValid(ply) then return end
    if not ply:Alive() then return end -- ✅ AJOUT
    if not ply:GetNWBool("MokutonRide", false) then return end

    local seqId = ply:LookupSequence("nrp_lobby_shikamaru_etc_team_type1_wait_loop")
    if seqId and seqId >= 0 then
        if ply:GetSequence() ~= seqId then
            ply:SetSequence(seqId)
            ply:SetCycle(0)
        end
        ply:SetPlaybackRate(1)
    end

    return true
end)


-- ✅ Reset l'animation quand le joueur meurt ou se déconnecte
local function ResetPlayerAnim(ply)
    if not IsValid(ply) then return end
    ply:SetSequence(ply:LookupSequence("idle_all_01"))
    ply:SetCycle(0)
    ply:SetPlaybackRate(1)
end

-- (PlayerDeath n'existe que côté serveur : l'ancien hook client ne s'exécutait jamais)


hook.Add("EntityRemoved", "Mokuton_ResetAnim_Disconnect", function(ent)
    if ent:IsPlayer() then
        ResetPlayerAnim(ent)
    end
end)
