local KEY      = KEY_K
game.AddParticles("particles/patlick_atgparticules.pcf")   -- kenjutsu_zone_pat : chute d'une arche
PrecacheParticleSystem("hit_2_arche")
PrecacheParticleSystem("kenjutsu_zone_pat")

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

    -- la recharge est gérée par le serveur (valeur du niveau) et vérifiée par NA_Lancer
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

----------------------------------------------------------
-- Mode développeur (developer 1) : hitbox de visée affichée en direct (comme le Cube Jinton)
--   verte = une cible serait touchée, rouge = aucune cible
----------------------------------------------------------
local cvDev = GetConVar("developer")

local function EstCible(ent, ply)
    if not IsValid(ent) or ent == ply then return false end
    if ent:IsPlayer() then return ent:Alive() end
    return ent:IsNPC() or ent:IsNextBot()   -- la vie des PNJ n'est pas envoyée aux clients
end

hook.Add("PostDrawTranslucentRenderables", "MokutonArche_HitboxVisee", function(depth, sky)
    if sky or not cvDev or cvDev:GetInt() <= 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = NA_Stat(ply, "mokuton_arche", "trace_range", GetGlobal2Float("NA_MokutonArchePortee", 1000))
    local taille = NA_Stat(ply, "mokuton_arche", "hitbox", GetGlobal2Float("NA_MokutonArcheVisee", 40))   -- hitbox par niveau
    local t = Vector(taille, taille, taille)

    -- même calcul que le serveur : boîte jusqu'au premier mur, cible valable la plus proche
    local oeil = ply:EyePos()
    local tr = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mask = MASK_SOLID_BRUSHONLY,
    })
    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, tr.HitPos, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end
    local couleur = cible and Color(0, 255, 0) or Color(255, 70, 70)

    -- boîte au bout de la visée + ligne du regard
    render.DrawWireframeBox(tr.HitPos, angle_zero, -t, t, couleur, true)
    render.DrawLine(oeil + ply:GetAimVector() * 30, tr.HitPos, couleur, true)

    if cible then
        render.DrawWireframeBox(cible:GetPos(), angle_zero, cible:OBBMins(), cible:OBBMaxs(), Color(0, 255, 0), true)
    end
end)
