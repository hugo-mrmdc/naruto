--[[
    Module : combat - effets de statut à l'écran et sur les joueurs (client)
]]

local Status = NRP.Status
local MAT_GLOW = Material("sprites/light_glow02_add")

local genjutsuCM = {
    ["$pp_colour_addr"] = 0.08,
    ["$pp_colour_addg"] = 0,
    ["$pp_colour_addb"] = 0.12,
    ["$pp_colour_brightness"] = -0.05,
    ["$pp_colour_contrast"] = 1.1,
    ["$pp_colour_colour"] = 0.4,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0,
}

local stunCM = {
    ["$pp_colour_addr"] = 0.05,
    ["$pp_colour_addg"] = 0.05,
    ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 0.5,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "NRP.Status.Screen", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    if Status.Has(ply, "genjutsu") then
        DrawColorModify(genjutsuCM)
        DrawMotionBlur(0.15, 0.8, 0.02)
    elseif Status.Has(ply, "stun") then
        DrawColorModify(stunCM)
    end
end)

-- Pas de hook CalcView ici : il remplacerait la caméra troisième personne de l'addon naruto_dev.
-- Le genjutsu se voit par la teinte et le flou ci-dessus.

-- Flammes sur les joueurs en feu, étoiles au-dessus des joueurs étourdis
-- La brûlure est une particule attachée au joueur (atg_reworkpvp.pcf), coupée quand le statut se termine
local FX_BURN = "katon_brulureatg"
game.AddParticles("particles/atg_reworkpvp.pcf")
PrecacheParticleSystem(FX_BURN)
local burning = setmetatable({}, { __mode = "k" })

hook.Add("PostPlayerDraw", "NRP.Status.PlayerFX", function(ply)
    if ply:IsDormant() then return end
    local now = CurTime()

    local onFire = Status.Has(ply, "burn")
    if onFire and not burning[ply] then
        burning[ply] = true
        ParticleEffectAttach(FX_BURN, PATTACH_ABSORIGIN_FOLLOW, ply, 0)
    elseif not onFire and burning[ply] then
        burning[ply] = nil
        ply:StopParticlesNamed(FX_BURN)
    end

    if Status.Has(ply, "stun") then
        local head = ply:GetPos() + Vector(0, 0, 80)
        render.SetMaterial(MAT_GLOW)
        for i = 0, 2 do
            local a = now * 5 + i * 2.09
            render.DrawSprite(head + Vector(math.cos(a) * 10, math.sin(a) * 10, 0), 8, 8, Color(255, 230, 90))
        end
    end

    if ply:GetNW2Bool("NRP_Block", false) then
        render.SetMaterial(MAT_GLOW)
        render.DrawSprite(ply:WorldSpaceCenter() + ply:GetForward() * 18, 40, 50, Color(120, 180, 255, 40))
    end
end)
