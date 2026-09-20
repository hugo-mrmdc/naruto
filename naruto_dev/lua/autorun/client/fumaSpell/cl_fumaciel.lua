--========================================================
-- Fuma : Shuriken Céleste (CLIENT)
-- Lancement depuis la barre de techniques, et repère au sol pendant
-- l'incantation (sv_fumaciel.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local DUREE_REPERE = 0.6   -- = DUREE_MUDRA de sv_fumaciel.lua
local COULEUR      = Color(230, 220, 120)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.fuma_ciel = function()
    net.Start("fuma_ciel_cast")
    net.SendToServer()
end

-- même calcul que le serveur : le point visé, ramené au sol
local function PointVise(ply, portee)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut, endpos = debut + ply:GetAimVector() * portee,
        filter = ply, mask = MASK_SOLID,
    })
    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 16),
        endpos = tr.HitPos - Vector(0, 0, 4000),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or tr.HitPos
end

local function Cercle(centre, rayon, couleur)
    local precedent
    for i = 0, 48 do
        local a = (i / 48) * math.pi * 2
        local p = centre + Vector(math.cos(a) * rayon, math.sin(a) * rayon, 2)
        if precedent then render.DrawLine(precedent, p, couleur, true) end
        precedent = p
    end
end

hook.Add("PostDrawTranslucentRenderables", "FumaCiel_Repere", function(depth, sky)
    if sky then return end

    local dernier = NA_DernierLancer and NA_DernierLancer.fuma_ciel
    if not dernier or CurTime() - dernier > DUREE_REPERE then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local centre = PointVise(ply, GetGlobal2Float("NA_FumaCielPortee", 1000))
    local rayon = GetGlobal2Float("NA_FumaCielRayon", 260)
    local a = 255 * (1 - (CurTime() - dernier) / DUREE_REPERE)
    Cercle(centre, rayon, Color(COULEUR.r, COULEUR.g, COULEUR.b, a))
end)
