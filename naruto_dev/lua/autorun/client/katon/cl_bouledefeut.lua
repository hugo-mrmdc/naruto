local NET_FIRE = "naruto_dev_katon"
local NET_POS  = "naruto_dev_katon_pos"

local PCF_PATH = "particles/orugi_atg_particle.pcf"
local FX_NAME  = "[1]_katon_boule_feu_orugi" -- le vrai nom

print("[KATON CL] Loaded (follow fx)")

hook.Add("InitPostEntity", "katon_followfx_precache", function()
    game.AddParticles(PCF_PATH)
    PrecacheParticleSystem(FX_NAME)
    print("[KATON CL] precache ok:", FX_NAME)
end)

-- touche 1
local last = false
-- Lancement de la technique (appelé par la touche Y ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.katon_boule = function()
    Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")

    timer.Simple(1, function()
        Jutsu.Play("nrp_ninjutsu_trow_fireball_lv3")
    end)
    timer.Simple(1.5, function()
        net.Start(NET_FIRE)
        net.SendToServer()
    end)
    timer.Simple(2, function()
        Jutsu.Play("nrp_ninjutsu_trow_fireball_lv3")
    end)
    timer.Simple(2.5, function()
        net.Start(NET_FIRE)
        net.SendToServer()
    end)
end

hook.Add("Think", "katon_followfx_key", function()
    -- pas de technique en tapant dans le chat / un menu, ni mort
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = input.IsKeyDown(KEY_Y)
    if pressed and not last and NA_TouchesDirectes() then
        NA_Lancer("katon_boule")
    end
    last = pressed
end)

-- stockage des "boules FX"
local balls = balls or {}

local function EnsureBall(id)
    if balls[id] and IsValid(balls[id].mdl) then return balls[id] end

    local mdl = ClientsideModel("models/hunter/misc/sphere025x025.mdl")
    mdl:SetNoDraw(true) -- invisible support
    mdl:Spawn()

    -- attache UNE FOIS
    mdl:StopParticles()
    ParticleEffectAttach(FX_NAME, PATTACH_ABSORIGIN_FOLLOW, mdl, 0)

    balls[id] = { mdl = mdl, last = CurTime() }
    return balls[id]
end

-- nettoyage auto
hook.Add("Think", "katon_followfx_cleanup", function()
    local now = CurTime()
    for id, b in pairs(balls) do
        if not b or not IsValid(b.mdl) then
            balls[id] = nil
        elseif (b.last or 0) + 1.0 < now then
            b.mdl:StopParticles()
            b.mdl:Remove()
            balls[id] = nil
        end
    end
end)

net.Receive(NET_POS, function()
    local id    = net.ReadUInt(16)
    local alive = net.ReadBool()
    local pos   = net.ReadVector()
    local ang   = net.ReadAngle()

    if not alive then
        local b = balls[id]
        if b and IsValid(b.mdl) then
            b.mdl:StopParticles()
            b.mdl:Remove()
        end
        balls[id] = nil
        return
    end

    local b = EnsureBall(id)
    b.last = CurTime()

    if IsValid(b.mdl) then
        b.mdl:SetPos(pos)
        b.mdl:SetAngles(ang)
    end
end)
