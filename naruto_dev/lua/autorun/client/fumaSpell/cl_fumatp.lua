--========================================================
-- Téléportation Fuma (CLIENT)
-- Lance le shuriken ; la téléportation sur le shuriken se fait avec E (sv_fumatp.lua).
--========================================================

local NET_FUMA    = "naruto_dev_fumaTp"
local NET_FUMA_FX = "naruto_dev_fumaTp_fx"

hook.Add("InitPostEntity", "Fuma_PrecacheParticles", function()
    game.AddParticles("particles/naruto_fw.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")

    PrecacheParticleSystem("smoke_orugi2")
end)

hook.Remove("Think", "FumaTpKey")
local lastState = false

hook.Add("Think", "FumaTpKey", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        lastState = false
        return
    end
    local pressed = input.IsKeyDown(KEY_G)

    if pressed and not lastState and NA_TouchesDirectes() then
        NA_Lancer("fuma_tp")
    end

    lastState = pressed
end)

-- Lancement de la technique (appelé par la touche G ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.fuma_tp = function()
    net.Start(NET_FUMA)
    net.SendToServer()
end

net.Receive(NET_FUMA_FX, function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    ParticleEffectAttach(
        "smoke_orugi2",
        PATTACH_ABSORIGIN_FOLLOW,
        ent,
        0
    )

    timer.Simple(1.2, function()
        if IsValid(ent) then
            ent:StopParticles()
        end
    end)
end)
