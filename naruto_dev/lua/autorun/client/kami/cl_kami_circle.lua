--========================================================
-- Kami Circle (CLIENT)
-- Touche de lancement + affichage de la particule autour du joueur.
--========================================================

local KEY      = KEY_X
local PCF_PATH = "particles/atg_faris.pcf"
-- Nom exact tel qu'il est écrit dans le .pcf (vérifié dans le fichier)
local FX_NAME  = "[2]_paper_tornado"

game.AddParticles(PCF_PATH)
PrecacheParticleSystem(FX_NAME)

local function PlayEffect(ent)
    if not IsValid(ent) then return end
    ParticleEffectAttach(FX_NAME, PATTACH_ABSORIGIN_FOLLOW, ent, 0)
end

-- Test isolé : joue la particule sur toi, sans passer par le serveur.
-- Si ça ne montre rien, le problème vient de la particule ou de son matériau,
-- pas de la technique.
concommand.Add("kami_circle_test", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- texture principale de la tornade de papier (addon « ATG 1 »)
    local mat = Material("effects/papertrail/papertrail")
    print("[KamiCircle] matériau papertrail : " ..
        (mat and mat:IsError() and "INTROUVABLE (particule invisible)" or "ok"))

    -- posée au sol, sans attache : elle ne suit pas le joueur et ne tourne pas
    ParticleEffect(FX_NAME, ply:GetPos(), Angle(0, 0, 0))
    print("[KamiCircle] effet '" .. FX_NAME .. "' lancé à " .. tostring(ply:GetPos()))
end)

----------------------------------------------------------
-- Lancement (appelé par la touche ET par la barre de techniques)
----------------------------------------------------------
NA_Cast = NA_Cast or {}
NA_Cast.kami_circle = function()
    -- animation de mudras si le système d'animation est chargé
    if Jutsu and Jutsu.Play then
        Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")
    end

    net.Start("kami_circle_cast")
    net.SendToServer()
end

----------------------------------------------------------
-- Touche
----------------------------------------------------------
local wasDown = false

hook.Add("Think", "KamiCircle_KeyListener", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("kami_circle")
    end
    wasDown = down
end)

----------------------------------------------------------
-- Effets
----------------------------------------------------------
local anchors = {}

local function Stop(caster)
    local anchor = anchors[caster]
    if IsValid(anchor) then
        anchor:StopParticles()
        anchor:Remove()
    end
    anchors[caster] = nil

    if IsValid(caster) then
        caster:StopParticles()
    end
end

net.Receive("kami_circle_fx", function()
    local caster = net.ReadEntity()
    local duration = net.ReadFloat()
    local follow = net.ReadBool()
    local origin = net.ReadVector()

    if not IsValid(caster) then return end
    print("[KamiCircle] effet reçu pour " .. caster:GetName() .. " (" .. FX_NAME .. ")")
    Stop(caster)

    if follow then
        -- attachée au joueur : la zone le suit
        PlayEffect(caster)
    else
        -- Point fixe : petite entité invisible qui porte la particule.
        -- Angles remis à zéro : sans ça l'effet tournait avec la caméra du lanceur.
        local anchor = ClientsideModel("models/props_junk/PopCan01a.mdl")
        if not IsValid(anchor) then return end
        anchor:SetNoDraw(true)
        anchor:SetPos(origin)
        anchor:SetAngles(Angle(0, 0, 0))
        anchor:SetMoveType(MOVETYPE_NONE)
        anchor:SetParent(nil)
        anchors[caster] = anchor
        PlayEffect(anchor)
    end

    -- filet de sécurité si le message d'arrêt se perd
    timer.Simple(duration + 0.5, function()
        Stop(caster)
    end)
end)

net.Receive("kami_circle_stop", function()
    local caster = net.ReadEntity()
    if IsValid(caster) then
        Stop(caster)
    end
end)
