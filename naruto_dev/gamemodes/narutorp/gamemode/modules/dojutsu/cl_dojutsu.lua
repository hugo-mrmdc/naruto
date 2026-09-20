--[[
    Module : Dojutsu (client)
    - Yeux lumineux sur tous les joueurs ayant un dojutsu actif (distance limitée)
    - Teinte d'écran + vision spéciale pour le joueur local :
        "xray"  : contours des ninjas proches, à travers les murs
        "track" : contours des ninjas visibles + indicateur d'incantation
      La liste des cibles est rafraîchie par un timer (pas chaque frame).
]]

local Dojutsu = NRP.Dojutsu
local MAT_GLOW = Material("sprites/light_glow02_add")
local matCache = {}

local function EyeMaterial(path)
    if not path then return MAT_GLOW end
    matCache[path] = matCache[path] or Material(path)
    return matCache[path]
end

function Dojutsu.RequestPreferredStage(id, stage)
    if not NRP.Net.CanSend("SetDojutsuStage", 0.5) then return end
    NRP.Net.Start("SetDojutsuStage")
        net.WriteString(id)
        net.WriteUInt(stage, 4)
    net.SendToServer()
end

---------------------------------------------------------------------------
-- Yeux
---------------------------------------------------------------------------

hook.Add("PostPlayerDraw", "NRP.Dojutsu.Eyes", function(ply)
    local id, _, def = Dojutsu.GetActive(ply)
    if not id or not def or ply:IsDormant() then return end

    local maxDist = NRP.Config.DojutsuSettings.EyeDrawDistance
    if EyePos():DistToSqr(ply:EyePos()) > maxDist * maxDist then return end
    if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then return end

    local attachment = ply:LookupAttachment("eyes")
    if not attachment or attachment <= 0 then return end
    local att = ply:GetAttachment(attachment)
    if not att then return end

    local eye = def.eye or {}
    local offset = eye.offset or { 1.25, 0.6, 0 }
    local size = eye.size or 1.4
    local color = eye.color or Color(255, 50, 50)
    local right = att.Ang:Right()
    local fwd = att.Ang:Forward()
    local up = att.Ang:Up()
    local base = att.Pos + fwd * offset[2] + up * offset[3]

    render.SetMaterial(EyeMaterial(eye.material))
    render.DrawSprite(base + right * offset[1], size * 3, size * 3, color)
    render.DrawSprite(base - right * offset[1], size * 3, size * 3, color)
end)

---------------------------------------------------------------------------
-- Vision du joueur local
---------------------------------------------------------------------------

local targets = {}
local visionMode
local tintCM = {
    ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

timer.Create("NRP.Dojutsu.Vision", 0.3, 0, function()
    targets = {}
    visionMode = nil

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local id, stageIndex = Dojutsu.GetActive(ply)
    local stage = id and Dojutsu.GetStage(id, stageIndex)
    if not stage or not stage.hud.vision then return end

    visionMode = stage.hud.vision
    local radiusSqr = (stage.hud.radius or 1000) ^ 2
    local origin = ply:GetPos()
    local max = NRP.Config.DojutsuSettings.VisionMaxTargets

    for _, ent in ipairs(ents.FindInSphere(origin, stage.hud.radius or 1000)) do
        if #targets >= max then break end
        if ent ~= ply and ((ent:IsPlayer() and ent:Alive()) or ent:IsNPC())
            and origin:DistToSqr(ent:GetPos()) <= radiusSqr then
            targets[#targets + 1] = ent
        end
    end
end)

hook.Add("PreDrawHalos", "NRP.Dojutsu.Halos", function()
    if not visionMode or #targets == 0 then return end

    local valid = {}
    for _, ent in ipairs(targets) do
        if IsValid(ent) then valid[#valid + 1] = ent end
    end
    if #valid == 0 then return end

    if visionMode == "xray" then
        halo.Add(valid, Color(200, 210, 255), 2, 2, 1, true, true)
    else
        halo.Add(valid, Color(255, 60, 60), 1, 1, 1, true, false)
    end
end)

hook.Add("RenderScreenspaceEffects", "NRP.Dojutsu.Tint", function()
    local ply = LocalPlayer()
    local id, stageIndex = Dojutsu.GetActive(ply)
    local stage = id and Dojutsu.GetStage(id, stageIndex)
    local tint = stage and stage.hud.tint
    if not tint then return end

    local strength = (tint.a or 30) / 255
    tintCM["$pp_colour_addr"] = tint.r / 255 * strength
    tintCM["$pp_colour_addg"] = tint.g / 255 * strength
    tintCM["$pp_colour_addb"] = tint.b / 255 * strength
    tintCM["$pp_colour_colour"] = 1 - strength
    DrawColorModify(tintCM)
end)

-- Mode "track" : le Sharingan lit les incantations adverses
hook.Add("HUDPaint", "NRP.Dojutsu.Track", function()
    if visionMode ~= "track" then return end
    for _, ent in ipairs(targets) do
        if IsValid(ent) and ent:IsPlayer() then
            local jutsu = NRP.Jutsu.GetCasting(ent)
            if jutsu then
                local pos = (ent:GetPos() + Vector(0, 0, 90)):ToScreen()
                if pos.visible then
                    draw.SimpleTextOutlined(jutsu.name, "DermaDefaultBold", pos.x, pos.y,
                        Color(255, 90, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black)
                end
            end
        end
    end
end)
