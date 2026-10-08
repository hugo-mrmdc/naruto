--========================================================
-- HUD des recharges (CLIENT), en bas à droite
--
--   Double saut, Dash et Permutation : une icône chacune.
--     - prête            : icône claire ;
--     - en recharge      : icône sombre qui se rallume du bas vers le haut, avec les secondes restantes ;
--     - double saut / dash en l'air déjà utilisé : icône sombre jusqu'à ce que tu retouches le sol.
-- Images : materials/ui/hud/ (icon_double_jump, icon_dash, icon_permutation)
--========================================================

--========================================================
-- RÉGLAGES (tailles à 1080p, tout est mis à l'échelle de l'écran)
--========================================================
local MARGE_X   = 24     -- distance au bord droit
local MARGE_BAS = 22     -- distance au bord bas
local TAILLE    = 84     -- côté d'une icône
local ECART     = 10
--========================================================

local ICONES   -- défini plus bas (CalculerMise en a besoin)

-- couleurs créées une seule fois (pas de Color() à chaque image)
local C_TEMPS        = Color(255, 235, 190)
local C_TOUCHE       = Color(255, 215, 120)
local C_CONTOUR_TXT  = Color(0, 0, 0, 220)

-- mise en page recalculée seulement quand la résolution change
local mise = {}
local function CalculerMise()
    local k = ScrH() / 1080
    local t, e = math.Round(TAILLE * k), math.Round(ECART * k)
    mise.t, mise.e = t, e
    mise.x = ScrW() - math.Round(MARGE_X * k) - (#ICONES * t + (#ICONES - 1) * e)
    mise.y = ScrH() - math.Round(MARGE_BAS * k) - t
end

local function CreerPolices()
    local k = ScrH() / 1080
    surface.CreateFont("NA.Recharge.Temps", { font = "Roboto", size = math.Round(22 * k), weight = 800 })
    surface.CreateFont("NA.Recharge.Touche", { font = "Roboto", size = math.Round(13 * k), weight = 800 })
end
CreerPolices()
hook.Add("OnScreenSizeChanged", "NA_HudRecharges_Polices", function()
    CreerPolices()
    CalculerMise()
end)

-- Chaque entrée renvoie (reste, total, bloque) : secondes restantes, durée totale, utilisable ou non
ICONES = {
    {   -- Double saut : une fois par saut, de nouveau prêt en retouchant le sol
        mat = Material("ui/hud/icon_double_jump.png", "smooth mips"),
        etat = function(ply)
            return 0, 0, not ply:IsOnGround() and ply.NA_DoubleSautFait ~= nil
        end,
    },
    {   -- Dash : recharge entre deux dashs, et un seul dash en l'air par saut
        mat = Material("ui/hud/icon_dash.png", "smooth mips"),
        touche = function() return "Q" end,   -- touche du dash (TOUCHE dans sh_dash.lua)
        etat = function(ply)
            local reste = math.max(ply:GetNW2Float("NA_DashPret", 0) - CurTime(), 0)
            return reste, ply:GetNW2Float("NA_DashTotal", 3), reste <= 0 and ply:GetNW2Bool("NA_DashLairUtilise", false) and not ply:IsOnGround()
        end,
    },
    {   -- Permutation
        mat = Material("ui/hud/icon_permutation.png", "smooth mips"),
        touche = function() return NA_NomTouche and NA_NomTouche("permutation") or "V" end,
        etat = function(ply)
            local reste = NA_CD and NA_CD.Reste(ply, "permutation") or 0
            return reste, (NA_CD and NA_CD.Total(ply, "permutation") or 0), false
        end,
    },
}

local function Icone(x, y, t, def, ply)
    local reste, total, bloque = def.etat(ply)
    local prete = reste <= 0 and not bloque

    -- icône seule (garde ses proportions, centrée dans sa case) : sombre tant qu'elle n'est pas prête
    local mat = def.mat
    local w, h = mat:Width(), mat:Height()
    local k = t / math.max(w, h)
    local iw, ih = w * k, h * k
    local ix, iy = x + (t - iw) / 2, y + (t - ih) / 2
    surface.SetMaterial(mat)
    local a = prete and 255 or 90
    surface.SetDrawColor(a, a, a, 255)
    surface.DrawTexturedRect(ix, iy, iw, ih)

    if reste > 0 then
        -- recharge : l'icône se rallume du bas vers le haut à mesure qu'elle avance
        local avance = 1 - math.Clamp(reste / math.max(total, reste), 0, 1)
        local hv = math.Round(ih * avance)
        render.SetScissorRect(ix, iy + ih - hv, ix + iw, iy + ih, true)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(ix, iy, iw, ih)
        render.SetScissorRect(0, 0, 0, 0, false)

        local txt = math.ceil(reste)
        if reste < 10 then
            txt = math.ceil(reste * 10) / 10
            if txt == math.floor(txt) then txt = txt .. ".0" end
        end
        draw.SimpleTextOutlined(txt, "NA.Recharge.Temps", x + t / 2, y + t / 2, C_TEMPS, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, C_CONTOUR_TXT)
    end

    -- touche
    local nom = def.touche and def.touche()
    if nom then
        draw.SimpleTextOutlined(nom, "NA.Recharge.Touche", x + t - 2, y + t, C_TOUCHE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, 1, C_CONTOUR_TXT)
    end
end

hook.Add("HUDPaint", "NA_HudRecharges", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    if not mise.t then CalculerMise() end
    local t, e, x, y = mise.t, mise.e, mise.x, mise.y

    for i = 1, #ICONES do
        Icone(x + (i - 1) * (t + e), y, t, ICONES[i], ply)
    end
end)
