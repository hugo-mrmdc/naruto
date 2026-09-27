--========================================================
-- Hyuga : Byakugan (CLIENT)
-- Lancement / arrêt depuis la barre de techniques.
-- Tant qu'il est actif : les joueurs et PNJ proches (NA_ByakuganRayon) sont
-- surlignés à travers les murs (halo), et l'écran reçoit une légère teinte.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_OEIL = "byakugan_pat"   -- particles/patlick_atgparticules.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.hyuga_byakugan = function()
    net.Start("hyuga_byakugan_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_OEIL)

-- les yeux s'allument à l'activation (attache "eyes", sinon en haut du corps)
net.Receive("hyuga_byakugan_on", function()
    local ply = net.ReadEntity()
    if not IsValid(ply) then return end

    local att = ply:LookupAttachment("eyes")
    if att and att > 0 then
        CreateParticleSystem(ply, FX_OEIL, PATTACH_POINT_FOLLOW, att)
    else
        CreateParticleSystem(ply, FX_OEIL, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ply:OBBMaxs().z * 0.9))
    end
end)

----------------------------------------------------------
-- Vision à travers les murs (joueur local uniquement)
----------------------------------------------------------
local ALPHA_CIBLE = 60   -- transparence du modèle des cibles (0 = invisible, 255 = normal)

local cibles = {}
local transparents = {}   -- ent -> { couleur = Color, rendermode = number } (valeurs à restaurer)

local function AppliquerTransparence(ent)
    if transparents[ent] then return end
    transparents[ent] = { couleur = ent:GetColor(), rendermode = ent:GetRenderMode() }
    ent:SetRenderMode(RENDERMODE_TRANSALPHA)
    local c = transparents[ent].couleur
    ent:SetColor(Color(c.r, c.g, c.b, ALPHA_CIBLE))
end

local function RetirerTransparence(ent)
    local avant = transparents[ent]
    transparents[ent] = nil
    if not avant or not IsValid(ent) then return end
    ent:SetRenderMode(avant.rendermode)
    ent:SetColor(avant.couleur)
end

timer.Create("HyugaByakugan_Vision", 0.3, 0, function()
    local nouvelles = {}
    local actif = false

    local ply = LocalPlayer()
    if IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_Byakugan", false) then
        actif = true
        local rayon = ply:GetNW2Float("NA_ByakuganRayon", 1000)
        local origine = ply:GetPos()

        for _, ent in ipairs(ents.FindInSphere(origine, rayon)) do
            if ent ~= ply and ((ent:IsPlayer() and ent:Alive()) or ent:IsNPC()) then
                nouvelles[ent] = true
            end
        end
    end

    -- restaure les cibles qui ne le sont plus (ou Byakugan coupé)
    for ent in pairs(transparents) do
        if not nouvelles[ent] then RetirerTransparence(ent) end
    end
    -- rend transparentes les nouvelles cibles (des joueurs uniquement : les PNJ gardent leur modèle)
    if actif then
        for ent in pairs(nouvelles) do
            if ent:IsPlayer() then AppliquerTransparence(ent) end
        end
    end

    cibles = {}
    for ent in pairs(nouvelles) do cibles[#cibles + 1] = ent end
end)

hook.Add("PlayerDisconnected", "HyugaByakugan_TransparenceNettoyage", function(ply)
    transparents[ply] = nil
end)

hook.Add("PreDrawHalos", "HyugaByakugan_Halos", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Byakugan", false) or #cibles == 0 then return end

    local valides = {}
    for _, ent in ipairs(cibles) do
        if IsValid(ent) then valides[#valides + 1] = ent end
    end
    if #valides == 0 then return end

    halo.Add(valides, Color(100, 180, 255), 3, 3, 1, true, true)
end)

----------------------------------------------------------
-- Tenketsu : les points de chakra (squelette) des cibles, en ronds pleins
-- bleus (vrai cercle, materials/hyuga/tenketsu_dot.png, pas un glow additif
-- qui rend transparent ni un carré), à travers les murs.
--
-- On ne pose des points que sur les os qui portent une hitbox (tronc,
-- membres, tête...) : les os "techniques" du modèle (armes, IK...) n'ont pas
-- de hitbox et peuvent se retrouver à une position aberrante (ex : au sol)
-- quand ils ne sont pas animés.
----------------------------------------------------------
local MAT_TENKETSU = Material("hyuga/tenketsu_dot.png", "noclamp smooth")
local TAILLE_TENKETSU = 2.5
local COULEUR_TENKETSU = Color(70, 170, 255)

-- Os portant une hitbox pour cette entité (calculé une fois, mis en cache dessus)
local function OsValides(ent)
    if ent.NA_TenketsuOs then return ent.NA_TenketsuOs end

    local valides = {}
    for set = 0, (ent:GetHitBoxGroupCount() or 1) - 1 do
        for i = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
            local os = ent:GetHitBoxBone(i, set)
            if os and os >= 0 then valides[os] = true end
        end
    end
    ent.NA_TenketsuOs = valides
    return valides
end

hook.Add("PostDrawTranslucentRenderables", "HyugaByakugan_Tenketsu", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Byakugan", false) or #cibles == 0 then return end

    render.SetMaterial(MAT_TENKETSU)
    render.DepthRange(0, 0)   -- force le dessin tout devant : visible à travers les murs et les corps

    for _, ent in ipairs(cibles) do
        if IsValid(ent) then
            for os in pairs(OsValides(ent)) do
                local pos = ent:GetBonePosition(os)
                if pos then
                    render.DrawSprite(pos, TAILLE_TENKETSU, TAILLE_TENKETSU, COULEUR_TENKETSU)
                end
            end
        end
    end

    render.DepthRange(0, 1)   -- restaure la profondeur normale pour la suite du rendu
end)

local TEINTE = {
    ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "HyugaByakugan_Teinte", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Byakugan", false) then return end

    local force = 20 / 255
    TEINTE["$pp_colour_addr"] = 210 / 255 * force
    TEINTE["$pp_colour_addg"] = 215 / 255 * force
    TEINTE["$pp_colour_addb"] = 255 / 255 * force
    TEINTE["$pp_colour_colour"] = 1 - force
    DrawColorModify(TEINTE)
end)
