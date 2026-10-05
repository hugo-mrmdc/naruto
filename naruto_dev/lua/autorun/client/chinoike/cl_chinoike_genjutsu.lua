--========================================================
-- Chinoike : Genjutsu du Ketsuryugan (CLIENT)
-- Lancement depuis la barre de techniques, Ketsuryugan sur la cible touchée,
-- sang autour d'elle et écran rouge pour la victime
-- (messages envoyés par sv_chinoike_genjutsu.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_OEIL    = "ketsuryugan_pat"      -- particles/patlick_atgparticules.pcf
local FX_CIBLE   = "[16]_shield"          -- particles/ctg_chinoike_nael.pcf
local HAUT_CIBLE = 0                     -- hauteur du sang autour de la cible (0 = aux pieds, 40 = milieu du corps)
local FONDU      = 0.6                    -- secondes pour que l'écran rouge disparaisse
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.chinoike_genjutsu = function()
    net.Start("chinoike_genjutsu_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/ctg_chinoike_nael.pcf")
PrecacheParticleSystem(FX_OEIL)
PrecacheParticleSystem(FX_CIBLE)

-- le Ketsuryugan s'allume sur la cible touchée (sur l'attache "eyes" du
-- modèle, sinon en haut du corps : certains PNJ n'ont pas d'attache "eyes")
net.Receive("chinoike_genjutsu_oeil", function()
    local cible = net.ReadEntity()
    if not IsValid(cible) then return end

    local att = cible:LookupAttachment("eyes")
    if att and att > 0 then
        CreateParticleSystem(cible, FX_OEIL, PATTACH_POINT_FOLLOW, att)
    else
        CreateParticleSystem(cible, FX_OEIL, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, cible:OBBMaxs().z * 0.9))
    end
end)

-- fin du genjutsu pour le joueur local (écran rouge)
local genjutsuDebut, genjutsuFin = 0, 0

net.Receive("chinoike_genjutsu_cible", function()
    local cible = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(cible) then return end

    -- sang qui tourne autour de la cible, arrêté à la fin du genjutsu
    local ps = CreateParticleSystem(cible, FX_CIBLE, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, HAUT_CIBLE))
    timer.Simple(duree, function()
        if ps and ps:IsValid() then ps:StopEmission() end
    end)

    if cible == LocalPlayer() then
        genjutsuDebut = CurTime()
        genjutsuFin = CurTime() + duree
        util.ScreenShake(cible:GetPos(), 3, 5, 0.6, 100)
        surface.PlaySound("naruto_sound/jutsu/mugen/1-01.wav")
    end
end)

-- écran rouge et flou pour la victime
hook.Add("RenderScreenspaceEffects", "ChinoikeGenjutsu_Ecran", function()
    local now = CurTime()
    if now > genjutsuFin + FONDU then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then genjutsuFin = 0 return end

    -- montée rapide au début, fondu à la fin
    local force = math.Clamp((now - genjutsuDebut) / 0.2, 0, 1)
    if now > genjutsuFin then force = 1 - (now - genjutsuFin) / FONDU end
    force = math.Clamp(force, 0, 1)

    DrawColorModify({
        ["$pp_colour_addr"]       = 0.25 * force,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = 0,
        ["$pp_colour_brightness"] = -0.08 * force,
        ["$pp_colour_contrast"]   = 1 + 0.2 * force,
        ["$pp_colour_colour"]     = 1 - 0.8 * force,
        ["$pp_colour_mulr"]       = 2 * force,
        ["$pp_colour_mulg"]       = 0,
        ["$pp_colour_mulb"]       = 0,
    })
    DrawMotionBlur(0.2, 0.8 * force, 0.01)
end)
