local pressed = false
local pending = false
-- TOUCHE F
hook.Add("Think", "Invis_Key_F", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        pressed = false
        return
    end
    if input.IsKeyDown(KEY_F) then
        if not pressed then
            pressed = true
            if NA_TouchesDirectes() then
                NA_Lancer("fuma_invisibilite")
            end
        end
    else
        pressed = false
    end
end)

-- Lancement de la technique (appelé par la touche F ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.fuma_invisibilite = function()
    local lp = LocalPlayer()
    if not IsValid(lp) or pending then return end

    -- l'état réel vient du serveur (avant : variable locale désynchronisée après une mort)
    if lp:GetNWBool("IsInvisible", false) then
        net.Start("Invis_F_Toggle")
        net.SendToServer()
        return
    end

    Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")

    -- 2️⃣ Son immédiat
    net.Start("Jutsu_PlaySound")
    net.SendToServer()

    pending = true
    timer.Simple(1, function()
        pending = false
        net.Start("Invis_F_Toggle")
        net.SendToServer()
    end)
end

-- CACHE PAC3 (cheveux / tête)
net.Receive("Invis_PAC", function()
    local state = net.ReadBool()

    if not pac or not pac.TogglePartDrawing then return end

    pac.TogglePartDrawing(not state)
end)

-- Cache les hands (vue FPS)
hook.Add("PreDrawPlayerHands", "Invis_HideHands", function(hands, ply)
    if ply:GetNWBool("IsInvisible", false) then
        return true
    end
end)

-- Pendant l'invisibilité, AUCUNE particule ne reste accrochée au joueur (brûlure, aura, poison, ailes,
-- effets de technique...) : sans ça elles dessinaient sa silhouette. Elles sont coupées à chaque image,
-- donc même une particule lancée pendant l'invisibilité disparaît tout de suite.
hook.Add("Think", "Invis_CoupeParticules", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNWBool("IsInvisible", false) then
            ply:StopParticles()
            ply:StopParticleEmission()
        end
    end
end)
