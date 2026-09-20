--========================================================
-- Ailes de papier (CLIENT)
-- Touche d'activation + petit repère à l'écran pendant le vol.
--========================================================

local KEY    = KEY_H   -- touche des ailes de papier
local MODELE = "models/clan/ame/kami/wings.mdl"

-- Animation du joueur pendant le vol (nom exact : anim_extension_mod6.mdl)
local ANIM_VOL = "nrp_ninjutsu_heal_aerial_d51nj2_shadowclone_idle_type01"

-- Les props attachés au joueur n'avancent pas toujours leur animation tout seuls :
-- on demande au client de faire tourner leurs images.
hook.Add("NetworkEntityCreated", "NA_Wings_Anim", function(ent)
    if not IsValid(ent) then return end

    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetModel() ~= MODELE then return end

        ent.AutomaticFrameAdvance = true
        ent:SetPlaybackRate(1)

        local seq = ent:LookupSequence("idle")
        if seq and seq >= 0 and ent:GetSequence() ~= seq then
            ent:ResetSequence(seq)
        end
    end)
end)

surface.CreateFont("NA.Wings.Label", { font = "Roboto", size = 17, weight = 600 })

local wasDown = false

hook.Add("Think", "NA_Wings_Key", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("kami_ailes")
    end
    wasDown = down
end)

-- Lancement (appelé par la touche ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.kami_ailes = function()
    net.Start("kami_wings_toggle")
    net.SendToServer()
end

----------------------------------------------------------
-- Animation du joueur pendant le vol
----------------------------------------------------------
local function EnVol(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_Wings", false)
end

local function SeqVol(ply)
    if not ANIM_VOL or ANIM_VOL == "" then return -1 end
    local seq = ply:LookupSequence(ANIM_VOL)
    return seq or -1
end

hook.Add("CalcMainActivity", "NA_Wings_Anim", function(ply)
    if not EnVol(ply) then return end

    local seq = SeqVol(ply)
    if seq >= 0 then
        return ACT_INVALID, seq
    end
end)

hook.Add("UpdateAnimation", "NA_Wings_Anim_Update", function(ply)
    if not EnVol(ply) then return end

    local seq = SeqVol(ply)
    if seq < 0 then return end

    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

-- Vérifie que l'animation de vol existe sur ton modèle
concommand.Add("na_wings_anim_check", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    print(string.format("[Ailes] %s -> %d (modèle : %s)", ANIM_VOL, ply:LookupSequence(ANIM_VOL), ply:GetModel()))
end)

-- Rappel discret des commandes pendant le vol
hook.Add("HUDPaint", "NA_Wings_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Wings", false) then return end

    draw.SimpleText("AILES DE PAPIER  —  déplacement : ZQSD   monter : Espace   descendre : Ctrl   se poser : H",
        "NA.Wings.Label", ScrW() * 0.5,
        ScrH() - ((NA_SkillBar and NA_SkillBar.HauteurOccupee and NA_SkillBar.HauteurOccupee() or 88) + 70),
        Color(235, 235, 235, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
