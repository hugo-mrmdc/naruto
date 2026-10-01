--========================================================
-- Inkuton : éditeur du parchemin (CLIENT) - outil de réglage, à supprimer une fois les valeurs trouvées
--
-- Commande : inkuton_scroll_editeur
--   - "Lancer l'animation" joue l'animation de lancer sur toi et fait apparaître le parchemin dans ta main gauche ;
--   - "Pause" fige l'animation du joueur ET du parchemin, le curseur "Temps" les place à n'importe quel moment ;
--   - les curseurs Position / Rotation sont relatifs à l'os de la main gauche (comme un accessoire) ;
--   - "Copier les valeurs" met dans le presse-papiers les lignes à me donner (ou à coller dans cl_inkuton_chiens.lua).
-- Passe en vue 3e personne pour voir le résultat.
--========================================================

local ANIM = "m_throw_kunai_front"
local SLOT = GESTURE_SLOT_CUSTOM

concommand.Add("inkuton_scroll_editeur", function()
    local P = NA_InkutonParchemin
    local ply = LocalPlayer()
    if not P or not IsValid(ply) then return end

    if IsValid(NA_InkutonEditeur) then NA_InkutonEditeur:Remove() end

    local pause = false
    local debutAnim = CurTime()
    local dureeAnim = 1

    local f = vgui.Create("DFrame")
    NA_InkutonEditeur = f
    f:SetTitle("Éditeur du parchemin (main gauche)")
    f:SetSize(380, 560)
    f:SetPos(20, 60)
    f:SetDeleteOnClose(true)
    f:MakePopup()
    f:SetKeyboardInputEnabled(false)   -- les touches de jeu restent utilisables

    local function Curseur(titre, min, max, valeur, quand)
        local s = vgui.Create("DNumSlider", f)
        s:Dock(TOP)
        s:DockMargin(8, 0, 8, 0)
        s:SetText(titre)
        s:SetMin(min)
        s:SetMax(max)
        s:SetDecimals(1)
        s:SetValue(valeur)
        s.OnValueChanged = function(_, v) quand(v) end
        return s
    end

    local function Titre(txt)
        local l = vgui.Create("DLabel", f)
        l:Dock(TOP)
        l:DockMargin(8, 6, 8, 0)
        l:SetText(txt)
    end

    -- animation
    local function Lancer()
        local seq = ply:LookupSequence(ANIM)
        if not seq or seq < 0 then chat.AddText(Color(255, 120, 90), "[inkuton] animation introuvable : " .. ANIM) return end
        dureeAnim = math.max(ply:SequenceDuration(seq), 0.1)
        ply:AddVCDSequenceToGestureSlot(SLOT, seq, 0, true)
        ply:SetLayerPlaybackRate(SLOT, 1)
        local a = P.Demarrer(ply)
        if a then a.cycle = nil end
        debutAnim = CurTime()
        pause = false
    end

    local bLancer = vgui.Create("DButton", f)
    bLancer:Dock(TOP)
    bLancer:DockMargin(8, 4, 8, 0)
    bLancer:SetText("Lancer l'animation")
    bLancer.DoClick = Lancer

    local cPause = vgui.Create("DCheckBoxLabel", f)
    cPause:Dock(TOP)
    cPause:DockMargin(8, 8, 8, 0)
    cPause:SetText("Pause")

    local sTemps
    sTemps = Curseur("Temps (0 à 1)", 0, 1, 0, function(v)
        if not pause then return end
        ply:SetLayerCycle(SLOT, v)
        local a = P.Etat(ply)
        if a then a.cycle = math.Clamp(v, 0, 0.99) end
    end)
    sTemps:SetDecimals(2)

    cPause.OnChange = function(_, v)
        pause = v
        local a = P.Etat(ply)
        if v then
            ply:SetLayerPlaybackRate(SLOT, 0)
            local c = math.Clamp((CurTime() - debutAnim) / dureeAnim, 0, 0.99)
            sTemps:SetValue(c)   -- appelle OnValueChanged : fige les deux animations à cet instant
        else
            ply:SetLayerPlaybackRate(SLOT, 1)
            if a then a.cycle = nil end
            debutAnim = CurTime() - sTemps:GetValue() * dureeAnim
        end
    end

    -- position / rotation par rapport à l'os de la main gauche
    Titre("Position (avant / droite / haut, dans le repère de la main)")
    Curseur("Avant", -60, 60, P.pos.x, function(v) P.pos.x = v end)
    Curseur("Droite", -60, 60, P.pos.y, function(v) P.pos.y = v end)
    Curseur("Haut", -60, 60, P.pos.z, function(v) P.pos.z = v end)
    Titre("Rotation (degrés)")
    Curseur("Pitch", -180, 180, P.ang.p, function(v) P.ang.p = v end)
    Curseur("Yaw", -180, 180, P.ang.y, function(v) P.ang.y = v end)
    Curseur("Roll", -180, 180, P.ang.r, function(v) P.ang.r = v end)

    local bCopier = vgui.Create("DButton", f)
    bCopier:Dock(TOP)
    bCopier:DockMargin(8, 10, 8, 0)
    bCopier:SetText("Copier les valeurs")
    bCopier.DoClick = function()
        local txt = string.format("P.pos = Vector(%.1f, %.1f, %.1f)\nP.ang = Angle(%.1f, %.1f, %.1f)",
            P.pos.x, P.pos.y, P.pos.z, P.ang.p, P.ang.y, P.ang.r)
        SetClipboardText(txt)
        print("[inkuton] " .. txt)
        chat.AddText(Color(232, 196, 120), "[inkuton] valeurs copiées dans le presse-papiers (et dans la console)")
    end

    f.OnRemove = function() P.Arreter(ply) end
    Lancer()
end)
