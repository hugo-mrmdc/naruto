local NET_SHARK = "shark_projectile_fire"

local wasDown = false

hook.Add("Think", "Shark_Fire_Key", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- 🔒 Bloque si le clavier est capturé par une UI (chat ouvert, console, etc.)
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or ply:IsTyping() or not ply:Alive() then
        wasDown = false -- évite de relancer quand tu refermes le chat en restant appuyé
        return
    end

    local down = input.IsKeyDown(KEY_R)

    -- Détection d'un SEUL appui
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("suiton_requin")
    end

    wasDown = down
end)

-- Lancement de la technique (appelé par la touche R ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.suiton_requin = function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply._SharkKeyCooldown then return end
    ply._SharkKeyCooldown = true

    Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")

    net.Start("Jutsu_PlaySound")
    net.SendToServer()

    timer.Simple(1, function()
        if not IsValid(ply) then return end
        net.Start(NET_SHARK)
        net.SendToServer()
    end)

    timer.Simple(5.3, function()
        if IsValid(ply) then
            ply._SharkKeyCooldown = nil
        end
    end)
end

PrecacheParticleSystem("water_splash_01_refract")

net.Receive("Swarm_EndFX", function()
    local pos = net.ReadVector()

    -- 💥 joue la particule plusieurs fois pour grossir l'effet
    for i = 1, 3 do
        ParticleEffect(
            "water_splash_01_refract",
            pos + VectorRand() * 20, -- petit spread
            Angle(0, 0, 0),
            nil
        )
    end

    -- 🔵 GROS glow bleu
    local dlight = DynamicLight(0)
    if dlight then
        dlight.pos = pos
        dlight.r = 40
        dlight.g = 120
        dlight.b = 255
        dlight.brightness = 5      -- 🔥 plus fort
        dlight.Decay = 1200        -- plus lent
        dlight.Size = 520          -- 🔥 beaucoup plus grand
        dlight.DieTime = CurTime() + 0.5
    end

    -- ⚡ effet énergie bleu (bonus, très visible)
  
end)

