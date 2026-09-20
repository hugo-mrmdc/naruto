local KEY      = KEY_O
local COOLDOWN = 1.5

local appuiFleur = false

hook.Add("Think", "MokutonSpawn_KeyListener", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or ply:IsTyping() or not ply:Alive() then
        return
    end
    -- un appui = un lancement (maintenir la touche ne relance plus en boucle)
    local down = input.IsKeyDown(KEY)
    if down and not appuiFleur and NA_TouchesDirectes() then
        NA_Lancer("mokuton_fleur")
    end
    appuiFleur = down
end)

-- Lancement de la technique (appelé par la touche O ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.mokuton_fleur = function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    ply._mokuton_next = ply._mokuton_next or 0
    if ply._mokuton_next > CurTime() then return end
    ply._mokuton_next = CurTime() + COOLDOWN

    net.Start("MokutonSpawn_fleur")
    net.SendToServer()
end

net.Receive("Mokuton_FlowerFX", function()
    local pos = net.ReadVector()
    local ang = net.ReadAngle()

    -- Décale la position de 20 unités vers le haut
    pos = pos + Vector(0, 0, 300)

    -- Crée une entité invisible pour faire durer la particule
    local emitter = ents.CreateClientProp()
    emitter:SetModel("models/hunter/plates/plate.mdl")
    emitter:SetPos(pos)
    emitter:SetAngles(ang)
    emitter:SetNoDraw(true) -- Invisible
    emitter:Spawn()

    -- Attache la particule à l'entité
    ParticleEffectAttach("mokuton_flower", PATTACH_ABSORIGIN_FOLLOW, emitter, 0)

    print("[MOKUTON] ✨ Particule jouée à:", pos)

    -- Supprime après 10 secondes
    timer.Simple(10, function()
        if IsValid(emitter) then
            emitter:StopParticles()
            emitter:Remove()
            print("[MOKUTON] 🗑️ Particule supprimée après 10s")
        end
    end)
end)
