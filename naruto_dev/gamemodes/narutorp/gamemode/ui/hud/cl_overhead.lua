--[[
    HUD : informations au-dessus des joueurs (nom RP, grade, village, clan, vie)
    La liste des joueurs visibles est calculée 4 fois par seconde, pas à chaque frame.
]]

local UI = NRP.UI
local S = UI.S

local RANGE = 700
local visible = {}

timer.Create("NRP.Overhead.Scan", 0.25, 0, function()
    visible = {}
    local me = LocalPlayer()
    if not IsValid(me) then return end

    local eye = me:EyePos()
    local rangeSqr = RANGE * RANGE
    for _, ply in NRP.Util.PlayerIterator() do
        if ply ~= me and ply:Alive() and not ply:IsDormant() and not ply:GetNoDraw()
            and ply:GetNW2Bool("NRP_Loaded", false) and eye:DistToSqr(ply:EyePos()) < rangeSqr then
            local tr = util.TraceLine({ start = eye, endpos = ply:EyePos(), filter = { me, ply }, mask = MASK_VISIBLE })
            if not tr.Hit then
                visible[#visible + 1] = ply
            end
        end
    end
end)

hook.Add("HUDPaint", "NRP.Overhead", function()
    if #visible == 0 then return end
    local theme = UI.Theme()
    local eye = EyePos()

    for _, ply in ipairs(visible) do
        if IsValid(ply) and ply:Alive() then
            local headPos = ply:GetPos() + Vector(0, 0, ply:OBBMaxs().z + 12)
            local screen = headPos:ToScreen()
            if screen.visible then
                local dist = eye:Distance(headPos)
                local alpha = math.Clamp(255 * (1 - (dist - RANGE * 0.6) / (RANGE * 0.4)), 0, 255)
                local x, y = screen.x, screen.y

                local village = NRP.Villages:Get(NRP.Char.GetVillage(ply))
                local nameColor = village and village.color or theme.Text
                UI.Text(NRP.Char.GetName(ply), "NRP.BodyBold", x, y, UI.Alpha(nameColor, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, true)

                local rank = NRP.Ranks.Get(NRP.Char.GetRank(ply))
                local line = (rank and rank.name or "") .. "  •  Niv. " .. NRP.Char.GetLevel(ply)
                local clan = NRP.Clans.Get(NRP.Char.GetClan(ply))
                if clan then line = line .. "  •  " .. clan.name end
                UI.Text(line, "NRP.Tiny", x, y + S(2), UI.Alpha(theme.TextDim, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, true)

                if NRP.Char.IsDeserter(ply) then
                    UI.Text("NUKENIN", "NRP.Tiny", x, y + S(16), UI.Alpha(theme.Error, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, true)
                end

                if ply:Health() < ply:GetMaxHealth() then
                    local bw = S(80)
                    UI.Bar(x - bw / 2, y - S(28), bw, S(5), ply:Health() / math.max(1, ply:GetMaxHealth()), UI.Alpha(theme.Health, alpha))
                end
            end
        end
    end
end)
