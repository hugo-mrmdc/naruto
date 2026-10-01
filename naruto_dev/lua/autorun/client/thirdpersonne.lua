-- CLIENT: garrysmod/lua/autorun/client/na_thirdperson.lua

--========================================================
-- RÉGLAGES DE LA CAMÉRA -> c'est ICI qu'on change les valeurs
--========================================================

-- Distance derrière le joueur. PLUS GRAND = PLUS RECULÉ.
-- Repères : 60 = très proche (épaule), 120 = proche, 180 = normal, 300 = large.
local DISTANCE = 150

-- Hauteur de la caméra par rapport aux yeux (négatif = plus bas)
local HAUTEUR  = 10

-- Décalage latéral : positif = caméra à droite du joueur (vue par-dessus l'épaule),
-- négatif = à gauche, 0 = pile derrière lui.
local DECALAGE_COTE = 0

-- true  : les deux valeurs ci-dessus s'appliquent à chaque lancement du jeu.
-- false : la valeur enregistrée (console / client.vdf) est gardée.
local FORCER_VALEURS_DU_CODE = true

-- Garde-fous : une valeur en dehors est ramenée dans ces bornes
local DIST_MIN, DIST_MAX = 30, 1000

--========================================================

local enabled  = true
local camFront = false

-- ConVars CLIENT : réglables aussi en jeu avec  na_tps_dist_cl 120
CreateClientConVar("na_tps_dist_cl",   tostring(DISTANCE), true, false, "Distance thirdperson (client)")
CreateClientConVar("na_tps_height_cl", tostring(HAUTEUR),  true, false, "Hauteur thirdperson (client)")

local wasDownV = false

hook.Add("Think", "NA_TPS_ToggleV", function()
    if not enabled then return end

    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or (IsValid(lp) and lp:IsTyping()) then
        wasDownV = false
        return
    end

    local down = (NA_ToucheBas and NA_ToucheBas("camera") or input.IsKeyDown(KEY_V))
    if down and not wasDownV then
        camFront = not camFront
    end
    wasDownV = down
end)

-- Caméra plus reculée et plus haute pendant le Tourbillon Divin (hyuga), pour voir par-dessus la particule
local DISTANCE_TOURBILLON_BONUS = 80
local HAUTEUR_TOURBILLON_BONUS = 60

local function GetDist(ply)
    local c = GetConVar("na_tps_dist_cl")
    local v = (c and c:GetInt()) or DISTANCE
    if IsValid(ply) and ply:GetNW2Float("NA_TourbillonFin", 0) > CurTime() then
        v = v + DISTANCE_TOURBILLON_BONUS
    end
    return math.Clamp(v, DIST_MIN, DIST_MAX)
end

local function GetHeight(ply)
    local c = GetConVar("na_tps_height_cl")
    local h = math.Clamp((c and c:GetInt()) or HAUTEUR, -100, 200)
    if IsValid(ply) and ply:GetNW2Float("NA_TourbillonFin", 0) > CurTime() then
        h = h + HAUTEUR_TOURBILLON_BONUS
    end
    return h
end

-- Remet les valeurs écrites en haut de ce fichier
concommand.Add("na_tps_reset", function()
    RunConsoleCommand("na_tps_dist_cl", tostring(DISTANCE))
    RunConsoleCommand("na_tps_height_cl", tostring(HAUTEUR))
    print("[TPS] caméra remise à " .. DISTANCE)
end)

-- Une valeur enregistrée l'emporte sur le code : on la réécrit au chargement,
-- sinon changer DISTANCE en haut du fichier ne changerait rien à l'écran.
hook.Add("InitPostEntity", "NA_TPS_ApplyCodeValues", function()
    local c = GetConVar("na_tps_dist_cl")
    if not c then return end

    if FORCER_VALEURS_DU_CODE then
        RunConsoleCommand("na_tps_dist_cl", tostring(DISTANCE))
        RunConsoleCommand("na_tps_height_cl", tostring(HAUTEUR))
        return
    end

    -- sinon, on ne corrige que les valeurs aberrantes
    local v = c:GetInt()
    if v < DIST_MIN or v > DIST_MAX then
        RunConsoleCommand("na_tps_dist_cl", tostring(DISTANCE))
    end
end)

hook.Add("CalcView", "NA_TPS_CalcView", function(ply, pos, ang, fov)
    if not enabled then return end
    -- l'éditeur de placement des accessoires prend la main sur la caméra
    if NA_EditeurCameraActive then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if ply ~= LocalPlayer() then return end

    local dist   = GetDist(ply)
    local height = GetHeight(ply)

    local view = {}
    view.fov = NA_FovPerso and NA_FovPerso(fov) or fov
    view.drawviewer = true

    local wanted
    if camFront then
        wanted = pos + ang:Forward() * dist + ang:Up() * height + ang:Right() * DECALAGE_COTE
    else
        wanted = pos - ang:Forward() * dist + ang:Up() * height + ang:Right() * DECALAGE_COTE
    end

    -- La caméra se rapproche quand un mur la sépare du joueur (avant : elle passait
    -- au travers et on voyait l'intérieur du décor).
    local tr = util.TraceHull({
        start  = pos,
        endpos = wanted,
        mins   = Vector(-8, -8, -8),
        maxs   = Vector(8, 8, 8),
        filter = ply,
        mask   = MASK_SOLID_BRUSHONLY,
    })

    if tr.Hit then
        wanted = tr.HitPos + tr.HitNormal * 4
    end

    view.origin = wanted
    view.angles = camFront and (pos - wanted):Angle() or ang

    return view
end)
