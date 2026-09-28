--========================================================
-- Course et course de chakra (CLIENT)
-- Jauge de chakra + repère visuel quand la course de chakra est active.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local CHAKRA_MAX  = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local LARGEUR     = 260
local HAUTEUR     = 14
local MARGE_BAS   = 118    -- distance depuis le bas de l'écran (au-dessus de la barre de techniques)
local CACHER_PLEIN = true  -- masquer la jauge quand le chakra est plein

-- Animations jouées en courant, selon la direction réelle du déplacement.
-- Une animation absente du modèle retombe sur "avant".
-- Mets ANIM_ACTIVE = false pour laisser les animations d'origine.
local ANIM_ACTIVE = true

-- false : on garde l'animation "avant" même en courant sur le côté ou en arrière.
--         (les animations latérales de certains packs glissent ou partent de travers)
-- true  : chaque direction a son animation, d'après les tables ci-dessous.
local UTILISER_LATERALES = false

-- Si les côtés sont inversés (tu vas à droite, l'animation part à gauche), mets true.
local INVERSER_COTES = false

-- Course normale (Shift) : table vide = on ne touche à rien, Garry's Mod garde
-- ses propres animations de course (et ses transitions dans toutes les directions).
local ANIMS_COURSE = {}

-- Course de chakra (double Shift)
local ANIMS_CHAKRA = {
    avant = "nrp_base_run_loop",
    -- nrp_base n'a pas de course latérale : les autres directions reprennent "avant"
}

-- Armes qui ont leur propre animation de course (course normale seulement :
-- en course de chakra, c'est l'animation de chakra qui passe).
-- Les armes basées sur naruto_arme_base sont reconnues automatiquement.
local ARMES_IGNOREES = {
}
--========================================================

local COL_FOND   = Color(20, 20, 26, 200)
local COL_BORD   = Color(0, 0, 0, 220)
local COL_CHAKRA = Color(60, 140, 255)
local COL_ACTIF  = Color(120, 200, 255)
local COL_VIDE   = Color(230, 70, 70)
local COL_TEXTE  = Color(235, 235, 235)

surface.CreateFont("NA.Chakra.Label", { font = "Roboto", size = 16, weight = 600 })

local shown = 0

hook.Add("HUDPaint", "NA_Chakra_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    -- Le gamemode Naruto RP a déjà sa propre jauge de chakra
    if NRP and NRP.Config then return end
    -- Le HUD de vie et de chakra (cl_hud_vie.lua) affiche déjà le chakra
    if NA_HUD_VIE_ACTIF then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local running = ply:GetNW2Bool("NA_ChakraRun", false)
    local frac = math.Clamp(chakra / CHAKRA_MAX, 0, 1)

    -- apparition / disparition en douceur
    local want = (CACHER_PLEIN and frac >= 1 and not running) and 0 or 1
    shown = math.Approach(shown, want, FrameTime() * 4)
    if shown <= 0.01 then return end

    local x = ScrW() * 0.5 - LARGEUR * 0.5
    -- toujours juste au-dessus de la barre de techniques, quelle que soit sa taille
    local marge = MARGE_BAS
    if NA_SkillBar and NA_SkillBar.HauteurOccupee then
        marge = NA_SkillBar.HauteurOccupee() + 30
    end
    local y = ScrH() - marge
    local a = 255 * shown

    surface.SetDrawColor(COL_BORD.r, COL_BORD.g, COL_BORD.b, a)
    surface.DrawRect(x - 2, y - 2, LARGEUR + 4, HAUTEUR + 4)

    surface.SetDrawColor(COL_FOND.r, COL_FOND.g, COL_FOND.b, a)
    surface.DrawRect(x, y, LARGEUR, HAUTEUR)

    local col = COL_CHAKRA
    if frac <= 0.15 then
        col = COL_VIDE
    elseif running then
        -- légère pulsation quand la course de chakra est active
        col = LerpVector(math.abs(math.sin(CurTime() * 6)), COL_CHAKRA:ToVector(), COL_ACTIF:ToVector()):ToColor()
    end

    surface.SetDrawColor(col.r, col.g, col.b, a)
    surface.DrawRect(x, y, LARGEUR * frac, HAUTEUR)

    draw.SimpleText(running and "COURSE DE CHAKRA" or "CHAKRA", "NA.Chakra.Label",
        x + LARGEUR * 0.5, y - 10, Color(COL_TEXTE.r, COL_TEXTE.g, COL_TEXTE.b, a),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

----------------------------------------------------------
-- Animation de course
----------------------------------------------------------

-- Le joueur court-il vraiment ? (touche maintenue + il avance + au sol)
local function EstEnCourse(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:InVehicle() or ply:GetMoveType() ~= MOVETYPE_WALK then return false end
    if ply:GetNWBool("MokutonRide", false) then return false end
    if not ply:GetNW2Bool("NA_Run", false) and not ply:GetNW2Bool("NA_ChakraRun", false) then return false end
    if not ply:OnGround() then return false end
    if ply:GetVelocity():Length2D() < 60 then return false end

    local wep = ply:GetActiveWeapon()
    if IsValid(wep) and (wep.NA_Arme or ARMES_IGNOREES[wep:GetClass()])
        and not ply:GetNW2Bool("NA_ChakraRun", false) then
        return false
    end

    return true
end

-- Direction du déplacement par rapport au regard, en huitièmes de tour
local function Direction(ply)
    local vel = ply:GetVelocity()
    vel.z = 0
    if vel:Length() < 1 then return "avant" end

    local diff = math.NormalizeAngle(vel:Angle().y - ply:EyeAngles().y)
    if INVERSER_COTES then diff = -diff end

    if diff > -22.5 and diff <= 22.5 then return "avant" end
    if diff > 22.5 and diff <= 67.5 then return "avantgauche" end
    if diff > 67.5 and diff <= 112.5 then return "gauche" end
    if diff > 112.5 and diff <= 157.5 then return "arrieregauche" end
    if diff < -22.5 and diff >= -67.5 then return "avantdroite" end
    if diff < -67.5 and diff >= -112.5 then return "droite" end
    if diff < -112.5 and diff >= -157.5 then return "arrieredroite" end
    return "arriere"
end

local function SequenceCourse(ply)
    if not ANIM_ACTIVE then return -1 end

    local chakra = ply:GetNW2Bool("NA_ChakraRun", false)
    -- en arrière / sur le côté la course de chakra est suspendue : animation normale
    if chakra and NA_SprintChakra and not NA_SprintChakra.MouvementVersLAvant(ply) then
        chakra = false
    end
    local set = chakra and ANIMS_CHAKRA or ANIMS_COURSE
    local dir = UTILISER_LATERALES and Direction(ply) or "avant"

    -- la direction voulue, sinon l'animation avant en secours
    for _, name in ipairs({ set[dir], set.avant }) do
        if name and name ~= "" then
            local seq = ply:LookupSequence(name)
            if seq and seq >= 0 then return seq end
        end
    end

    return -1
end

hook.Add("CalcMainActivity", "NA_Sprint_Anim", function(ply, vel)
    if not EstEnCourse(ply) then return end

    local seq = SequenceCourse(ply)
    if seq >= 0 then
        return ACT_MP_RUN, seq
    end
end)

-- Course de chakra sur le côté : le corps se tourne vers la direction de la course
-- (même animation que la course droite, pas d'animation latérale à glisser)
local function OrienterCorps(ply, vel)
    local C = NA_SprintChakra
    if not C or not C.TOURNER_CORPS or ply.NA_SouffleActif then ply.NA_CorpsYaw = nil return end   -- pas de rotation vers la course pendant le souffle katon

    local cible = vel:Angle().y
    if ply.NA_CorpsYaw then
        ply.NA_CorpsYaw = math.ApproachAngle(ply.NA_CorpsYaw, cible, FrameTime() * (C.VITESSE_ROTATION or 720))
    else
        ply.NA_CorpsYaw = ply:EyeAngles().y
    end
    ply:SetRenderAngles(Angle(0, ply.NA_CorpsYaw, 0))
end

hook.Add("UpdateAnimation", "NA_Sprint_Anim_Update", function(ply, vel, maxSeqGroundSpeed)
    if not EstEnCourse(ply) then ply.NA_CorpsYaw = nil return end

    local seq = SequenceCourse(ply)
    if seq < 0 then ply.NA_CorpsYaw = nil return end

    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)

    if ply:GetNW2Bool("NA_ChakraRun", false) then
        OrienterCorps(ply, vel)
    else
        ply.NA_CorpsYaw = nil
    end
    return true
end)

-- réappliqué juste avant l'affichage : le moteur recalcule l'orientation du corps entre-temps
hook.Add("PrePlayerDraw", "NA_Sprint_Orientation", function(ply)
    -- en l'air (saut, dash...), un autre hook UpdateAnimation peut passer avant celui de la course et
    -- laisser un cap périmé : le corps restait figé dans la direction de la course jusqu'au sol
    if ply.NA_CorpsYaw and not ply:OnGround() then ply.NA_CorpsYaw = nil end

    if ply.NA_CorpsYaw then
        ply:SetRenderAngles(Angle(0, ply.NA_CorpsYaw, 0))
        ply:InvalidateBoneCache()
    end
end)

-- Vérifie que les animations existent bien sur ton modèle
concommand.Add("na_run_anim_check", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    print("[Course] modèle : " .. ply:GetModel())
    for label, set in pairs({ ["course"] = ANIMS_COURSE, ["chakra"] = ANIMS_CHAKRA }) do
        for dir, name in SortedPairs(set) do
            local seq = ply:LookupSequence(name)
            print(string.format("[%s] %-14s %-30s %s", label, dir, name,
                (seq and seq >= 0) and ("ok (" .. seq .. ")") or "INTROUVABLE"))
        end
    end
end)

-- (Le flou de vitesse pendant la course de chakra a été retiré.)
