local KEY      = KEY_K
local COOLDOWN = 2

PrecacheParticleSystem("hit_2_arche")

local appuiArche = false

hook.Add("Think", "MokutonArche_KeyListener", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or ply:IsTyping() or not ply:Alive() then
        return
    end
    -- un appui = un lancement (maintenir la touche ne relance plus en boucle)
    local down = input.IsKeyDown(KEY)
    if down and not appuiArche and NA_TouchesDirectes() then
        NA_Lancer("mokuton_arche")
    end
    appuiArche = down
end)

-- Lancement de la technique (appelé par la touche K ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.mokuton_arche = function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    ply._mokutonArcheNext = ply._mokutonArcheNext or 0
    if ply._mokutonArcheNext > CurTime() then return end
    ply._mokutonArcheNext = CurTime() + COOLDOWN

    net.Start("KSpawn_Request")
    net.SendToServer()
end

net.Receive("Mokuton_ImpactFX", function()
    local pos = net.ReadVector()
    local ang = net.ReadAngle()
    ParticleEffect("hit_2_arche", pos, ang)
end)

net.Receive("Mokuton_PlaySound", function()
    local pos = net.ReadVector()
    sound.Play("mokuton/wood3.wav", pos, 140, math.random(90, 100), 1)
end)
