-- CLIENT: garrysmod/lua/autorun/client/inkuton_dragon_cl.lua

local NET_SPAWN = "inkuton_dragon_spawn"

game.AddParticles("particles/patlick_atgparticules.pcf")   -- golem_encre_impact_pat : impact du dragon projectile
PrecacheParticleSystem("golem_encre_impact_pat")

-- Impact du dragon projectile : la particule est coupée au bout de DUREE_FX_IMPACT secondes
local DUREE_FX_IMPACT = 1

net.Receive("inkuton_dragon_impact_fx", function()
    local pos = net.ReadVector()
    local fx = CreateParticleSystemNoEntity("golem_encre_impact_pat", pos, angle_zero)
    if not fx then return end
    timer.Simple(DUREE_FX_IMPACT, function()
        if fx and fx:IsValid() then fx:StopEmission(false, true) end   -- true = disparaît tout de suite (pas de fondu)
    end)
end)
local NET_KILL  = "inkuton_dragon_kill"

print("[INKUTON CL] Loaded")

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
hook.Add("Think", "InkutonDragon_CameraState", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp:Alive() and lp:GetNWBool("InkutonRide", false) then
        EnterRideView()
    else
        LeaveRideView()
    end
end)

-- Barre de techniques : un seul emplacement pour le dragon.
-- Invoque le dragon ; s'il est déjà sous toi, LANCE la charge (le clic droit de la barre passe par ici : le
-- serveur ne voit alors pas de vrai clic droit). Pour renvoyer le dragon sans charge : touche L.
NA_Cast = NA_Cast or {}
NA_Cast.inkuton_dragon = function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    net.Start(lp:GetNWBool("InkutonRide", false) and "inkuton_dragon_charge" or "inkuton_dragon_spawn")
    net.SendToServer()
end

-- ✅ Force l'animation de handseal côté CLIENT
-- Ces deux hooks tournent pour TOUS les joueurs à chaque image : le test du ride vient en premier,
-- donc un joueur qui ne vole pas sort tout de suite.
-- (L'index de la séquence n'est PAS mis en cache : wOS DynaBase ajoute les séquences nrp_* après coup et peut
-- en changer l'index.)
local SEQ_HANDSEAL = "nrp_lobby_shikamaru_etc_team_type1_wait_loop"

local function SeqHandseal(ply)
    return ply:LookupSequence(SEQ_HANDSEAL) or -1
end

hook.Add("CalcMainActivity", "Inkuton_ForceHandseal_CL", function(ply, vel)
    if not ply:GetNWBool("InkutonRide", false) then return end
    if not IsValid(ply) or not ply:Alive() then return end -- ✅ AJOUT

    local seqId = SeqHandseal(ply)
    if seqId >= 0 then
        return ACT_INVALID, seqId
    end

    return ACT_HL2MP_IDLE, -1
end)

hook.Add("UpdateAnimation", "Inkuton_ForceHandseal_Update_CL", function(ply, vel, maxSeqGroundSpeed)
    if not ply:GetNWBool("InkutonRide", false) then return end
    if not IsValid(ply) or not ply:Alive() then return end -- ✅ AJOUT

    local seqId = SeqHandseal(ply)
    if seqId >= 0 then
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


hook.Add("EntityRemoved", "Inkuton_ResetAnim_Disconnect", function(ent)
    if ent:IsPlayer() then
        ResetPlayerAnim(ent)
    end
end)

----------------------------------------------------------
-- Éclairage fixe du dragon : sans ça il devient NOIR quand le cavalier (donc le dragon) est dans le sol ou
-- dans un mur, parce que la lumière est lue à l'origine du modèle, qui se retrouve dans la géométrie.
-- Le dragon est un prop_dynamic sans classe Lua : on lui pose un RenderOverride côté client.
----------------------------------------------------------
local MODELE_DRAGON = "models/inkuton/dragoninkuton.mdl"

local function DessinerDragon(self)
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(0.6, 0.6, 0.6)
    render.SetModelLighting(BOX_TOP, 1, 1, 1)
    self:DrawModel()
    render.SuppressEngineLighting(false)
end

timer.Create("InkutonDragon_Eclairage", 0.5, 0, function()
    for _, ent in ipairs(ents.FindByClass("prop_dynamic")) do
        if ent.RenderOverride ~= DessinerDragon and string.lower(ent:GetModel() or "") == MODELE_DRAGON then
            ent.RenderOverride = DessinerDragon
        end
    end
end)
