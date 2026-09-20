--========================================================
-- Typhon de poison de la salamandre (CLIENT)
--
-- Lancement depuis la barre de techniques. Le typhon et ses particules sont
-- gérés par l'entité salamandre_typhon (lua/entities).
-- Pendant l'incantation, un cercle au sol montre où il va apparaître.
--========================================================

-- Lancement (appelé par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.salamandre_tornade = function()
    RunConsoleCommand("spawn_tornado")
end

----------------------------------------------------------
-- Test : joue une particule de godio_salamandre.pcf là où tu regardes, 6 s
--   sala_fx_test                          -> godio_petite_zone_sala
--   sala_fx_test godio_tornado_sala       -> n'importe quel autre nom
----------------------------------------------------------
concommand.Add("sala_fx_test", function(ply, _, args)
    local nom = args[1] or "godio_petite_zone_sala"
    local tr = ply:GetEyeTrace()

    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(tr.HitPos)
    ancre:SetAngles(Angle(0, 0, 0))

    local fx = CreateParticleSystem(ancre, nom, PATTACH_ABSORIGIN_FOLLOW, 0)
    print("[Salamandre] test de '" .. nom .. "' à " .. tostring(tr.HitPos) .. " : " ..
        ((fx and fx:IsValid()) and "effet créé" or "ÉCHEC (nom inconnu ou .pcf non chargé)"))

    timer.Simple(6, function()
        if fx and fx:IsValid() then fx:StopEmission() end
        if IsValid(ancre) then ancre:Remove() end
    end)
end)

----------------------------------------------------------
-- Repère de visée pendant l'incantation
----------------------------------------------------------
local AFFICHER_REPERE = false   -- true = cercle vert au sol pendant l'incantation
local DUREE_REPERE = 1.0   -- = DUREE_MUDRA de sv_tornadopoison.lua
local COULEUR      = Color(120, 230, 90)

-- même calcul que le serveur (PointVise) pour afficher le bon endroit
local function PointVise(ply, portee)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut,
        endpos = debut + ply:GetAimVector() * portee,
        filter = ply,
        mask = MASK_SOLID,
    })

    local pos = tr.HitPos
    if tr.Hit and tr.HitNormal.z < 0.7 then
        pos = pos + tr.HitNormal * 24
    end

    local sol = util.TraceLine({
        start = pos + Vector(0, 0, 16),
        endpos = pos - Vector(0, 0, 2000),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or pos
end

local function Cercle(centre, rayon, couleur)
    local segments = 48
    local precedent
    for i = 0, segments do
        local a = (i / segments) * math.pi * 2
        local p = centre + Vector(math.cos(a) * rayon, math.sin(a) * rayon, 2)
        if precedent then render.DrawLine(precedent, p, couleur, true) end
        precedent = p
    end
end

hook.Add("PostDrawTranslucentRenderables", "SalamandreTyphon_Repere", function(depth, sky)
    if sky or not AFFICHER_REPERE then return end

    local dernier = NA_DernierLancer and NA_DernierLancer.salamandre_tornade
    if not dernier or CurTime() - dernier > DUREE_REPERE then return end

    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = GetGlobal2Float("NA_TyphonPortee", 900)
    local rayon = GetGlobal2Float("NA_TyphonRayon", 450)
    local centre = PointVise(ply, portee)

    local a = 255 * (1 - (CurTime() - dernier) / DUREE_REPERE)
    Cercle(centre, rayon, Color(COULEUR.r, COULEUR.g, COULEUR.b, a))
    Cercle(centre, 220, Color(COULEUR.r, COULEUR.g, COULEUR.b, a))
end)
