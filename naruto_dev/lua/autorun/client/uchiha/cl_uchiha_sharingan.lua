--========================================================
-- Uchiha : Sharingan (CLIENT)
-- Lancement / arrêt depuis la barre de techniques.
-- Tant qu'il est actif : les joueurs et PNJ proches (NA_SharinganRayon) sont
-- surlignés en rouge à travers les murs (halo), et l'écran reçoit une teinte
-- rouge d'autant plus forte que le nombre de tomoe est élevé.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.uchiha_sharingan = function()
    net.Start("uchiha_sharingan_cast")
    net.SendToServer()
end

-- les yeux s'allument à l'activation (attache "eyes", sinon en haut du corps)
local FX_OEIL = "sharingan_pat"   -- particles/patlick_atgparticules.pcf
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_OEIL)

net.Receive("uchiha_sharingan_on", function()
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
-- Vision des ennemis (joueur local uniquement)
----------------------------------------------------------
local cibles = {}

timer.Create("UchihaSharingan_Vision", 0.3, 0, function()
    cibles = {}

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or not ply:GetNW2Bool("NA_Sharingan", false) then return end

    local rayon = ply:GetNW2Float("NA_SharinganRayon", 800)
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), rayon)) do
        if ent ~= ply and ((ent:IsPlayer() and ent:Alive()) or ent:IsNPC()) then
            cibles[#cibles + 1] = ent
        end
    end
end)

hook.Add("PreDrawHalos", "UchihaSharingan_Halos", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Sharingan", false) or #cibles == 0 then return end

    local valides = {}
    for _, ent in ipairs(cibles) do
        if IsValid(ent) then valides[#valides + 1] = ent end
    end
    if #valides == 0 then return end

    halo.Add(valides, Color(230, 30, 40), 3, 3, 1, true, true)
end)

local TEINTE = {
    ["$pp_colour_addr"] = 0, ["$pp_colour_addg"] = 0, ["$pp_colour_addb"] = 0,
    ["$pp_colour_brightness"] = 0, ["$pp_colour_contrast"] = 1, ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0, ["$pp_colour_mulg"] = 0, ["$pp_colour_mulb"] = 0,
}

hook.Add("RenderScreenspaceEffects", "UchihaSharingan_Teinte", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Sharingan", false) then return end

    local tomoe = math.Clamp(ply:GetNW2Int("NA_SharinganTomoe", 1), 1, 3)
    local force = (10 + tomoe * 8) / 255
    TEINTE["$pp_colour_addr"] = 255 / 255 * force
    TEINTE["$pp_colour_addg"] = 20 / 255 * force
    TEINTE["$pp_colour_addb"] = 30 / 255 * force
    TEINTE["$pp_colour_colour"] = 1 - force * 0.5
    DrawColorModify(TEINTE)
end)
