--========================================================
-- Suiton : Requin d'eau (CLIENT)
-- Lancement (touche R ou barre de techniques), puis particules envoyées par le serveur :
--   "Shark_HitFX" : le requin touche sa cible -> explosion d'eau (shark_explo_pat)
--   "Swarm_EndFX" : un requin de la nuée disparaît -> éclaboussure + lueur bleue
-- Le serveur crée les requins et décide de tout (sv_suiton_shark.lua).
--========================================================

local NET_TIR = "shark_projectile_fire"
local DELAI_MUDRA = 0.4     -- secondes entre l'animation et le tir
local DELAI_RELANCE = 5.3   -- secondes avant de pouvoir relancer côté client (le serveur a sa propre recharge)

game.AddParticles("particles/patlick_atgsuiton.pcf")
PrecacheParticleSystem("water_splash_01_refract")
PrecacheParticleSystem("shark_explo_pat")

-- Touche R : un seul appui = un lancement
local enfoncee = false

hook.Add("Think", "Shark_Fire_Key", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- clavier capturé par une UI (chat, console...) ou mort : on ignore, et on oublie l'appui
    -- (sinon un appui maintenu relancerait la technique à la fermeture du chat)
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or ply:IsTyping() or not ply:Alive() then
        enfoncee = false
        return
    end

    local appuyee = input.IsKeyDown(KEY_R)
    if appuyee and not enfoncee and NA_TouchesDirectes() then
        NA_Lancer("suiton_requin")
    end
    enfoncee = appuyee
end)

-- Lancement de la technique (appelé par la touche R ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.suiton_requin = function()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply._SharkKeyCooldown then return end
    ply._SharkKeyCooldown = true

    Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")
    net.Start("Jutsu_PlaySound")
    net.SendToServer()

    timer.Simple(DELAI_MUDRA, function()
        if not IsValid(ply) then return end
        net.Start(NET_TIR)
        net.SendToServer()
    end)

    timer.Simple(DELAI_RELANCE, function()
        if IsValid(ply) then ply._SharkKeyCooldown = nil end
    end)
end

-- le requin touche sa cible
net.Receive("Shark_HitFX", function()
    ParticleEffect("shark_explo_pat", net.ReadVector(), angle_zero)
end)

-- un requin de la nuée disparaît
net.Receive("Swarm_EndFX", function()
    local pos = net.ReadVector()

    -- la particule est jouée 3 fois, légèrement décalée, pour grossir l'effet
    for _ = 1, 3 do
        ParticleEffect("water_splash_01_refract", pos + VectorRand() * 20, angle_zero)
    end

    -- grosse lueur bleue
    local lumiere = DynamicLight(0)
    if lumiere then
        lumiere.pos = pos
        lumiere.r, lumiere.g, lumiere.b = 40, 120, 255
        lumiere.brightness = 5
        lumiere.Decay = 1200
        lumiere.Size = 520
        lumiere.DieTime = CurTime() + 0.5
    end
end)
