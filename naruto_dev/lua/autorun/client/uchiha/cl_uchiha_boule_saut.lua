local NET_FIRE = "naruto_dev_uchih1"
local NET_POS  = "naruto_dev_uchih1_pos"

-- durée de l'incantation (mudras) et du saut : 1 = ancien rythme, 0.5 = deux fois plus rapide
-- (garder la même valeur que VITESSE dans server/uchiha/sv_uchiha_boule_saut.lua)
local VITESSE = 0.5

-- le modèle regarde vers l'arrière : demi-tour horizontal (yaw 180). Mets Angle(0, 0, 0) pour annuler.
local CORRECTION_ANGLE = Angle(0, 180, 0)   -- rotation autour de l'axe du modèle (pitch, yaw, roll LOCAUX)

local MODEL_BOULE = "models/clan/konoha/uchiha/fireball.mdl" -- la boule en vol (plus de particule de vol)

print("[KATON CL] Loaded (follow fx)")

local PCF_HIT = "particles/solve_new_katon.pcf"
local FX_HIT  = "solve_katon_floor_impact" -- explosion à l'impact (posée au sol)

hook.Add("InitPostEntity", "uchih1_followfx_precache", function()
    game.AddParticles(PCF_HIT)
    util.PrecacheModel(MODEL_BOULE)
    PrecacheParticleSystem(FX_HIT)
    print("[UCHIHA CL] precache ok:", MODEL_BOULE)
end)

-- touche 1
local last = false
hook.Add("Think", "uchih1_followfx_key", function()
    -- pas de technique en tapant dans le chat / un menu, ni mort
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = input.IsKeyDown(KEY_J)
    if pressed and not last and NA_TouchesDirectes() then
        NA_Lancer("katon_saut")
    end
    last = pressed
end)

-- Lancement de la technique (appelé par la touche J ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.katon_saut = function()
    do
        Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")

        net.Start("Jutsu_PlaySound")
        net.SendToServer()

        -- démarre le loop tôt
        timer.Simple(0.5 * VITESSE, function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            Jutsu.Play("nrp_base_chakrajump_charge_loop")
        end)

        -- switch très vite après (0.06–0.12 est généralement parfait)
        timer.Simple(0.58 * VITESSE, function()
            local ply = LocalPlayer()
            if not IsValid(ply) then return end
            Jutsu.Play("nrp_base_chakrajump_vertical_charge_loop", { blend = 0.15 })
        end)



        timer.Simple(1.0 * VITESSE, function()
            Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_end")
        end)
        timer.Simple(2.0 * VITESSE, function()
            Jutsu.Play("nrp_base_dashstep_behind")
        end)
        timer.Simple(1.0 * VITESSE, function()
            net.Start(NET_FIRE)
            net.SendToServer()
        end)
    end
end

-- stockage des "boules FX"
local balls = balls or {}

local function EnsureBall(id)
    if balls[id] and IsValid(balls[id].mdl) then return balls[id] end

    local mdl = ClientsideModel(MODEL_BOULE)
    mdl:Spawn()

    -- SCALE DE LA BOULE : 1.0 = normal, 2.0 = 2x, 3.0 = très gros, etc.
    mdl:SetModelScale(2.5, 0) -- <-- augmente ici (ex: 2.0 / 3.0)

    balls[id] = { mdl = mdl, last = CurTime() }
    return balls[id]
end


-- nettoyage auto
hook.Add("Think", "uchih1_followfx_cleanup", function()
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
        if net.ReadBool() then
            -- l'explosion apparaît au sol : on projette le point d'impact vers le bas
            local sol = util.TraceLine({
                start  = pos + Vector(0, 0, 30),
                endpos = pos - Vector(0, 0, 400),
                mask   = MASK_SOLID_BRUSHONLY,
            })
            ParticleEffect(FX_HIT, sol.Hit and sol.HitPos or pos, angle_zero)
        end
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
        -- rotation dans le repère du modèle (et pas en additionnant les angles du monde,
        -- ce qui inversait la montée/descente quand tu visais en haut ou en bas)
        local a = Angle(ang.p, ang.y, ang.r)
        a:RotateAroundAxis(a:Up(),      CORRECTION_ANGLE.y)
        a:RotateAroundAxis(a:Right(),   CORRECTION_ANGLE.p)
        a:RotateAroundAxis(a:Forward(), CORRECTION_ANGLE.r)
        b.mdl:SetAngles(a)
    end
end)
