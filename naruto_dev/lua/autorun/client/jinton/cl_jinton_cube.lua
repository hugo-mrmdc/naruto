--========================================================
-- Jinton : Cube de confinement (CLIENT)
-- Lancement depuis la barre de techniques. Le cube est l'entité jinton_cube.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_cube = function()
    net.Start("jinton_cube_cast")
    net.SendToServer()
end

----------------------------------------------------------
-- Mode développeur (developer 1) : hitbox de visée du cube affichée en direct
--   verte = une cible serait touchée, rouge = aucune cible
----------------------------------------------------------
local cvDev = GetConVar("developer")

local function EstCible(ent, ply)
    if not IsValid(ent) or ent == ply then return false end
    if ent:IsPlayer() then return ent:Alive() end
    return ent:IsNPC() or ent:IsNextBot()   -- la vie des PNJ n'est pas envoyée aux clients
end

hook.Add("PostDrawTranslucentRenderables", "JintonCube_HitboxVisee", function(depth, sky)
    if sky or not cvDev or cvDev:GetInt() <= 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = GetGlobal2Float("NA_JintonCubePortee", 900)
    local taille = NA_Stat(ply, "jinton_cube", "hitbox", GetGlobal2Float("NA_JintonCubeVisee", 20))   -- hitbox par niveau
    local t = Vector(taille, taille, taille)

    -- même calcul que le serveur : boîte jusqu'au premier mur, cible valable la plus proche
    local oeil = ply:EyePos()
    local tr = util.TraceHull({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mins = -t, maxs = t, mask = MASK_SOLID_BRUSHONLY,
    })
    local cible, distMin = nil, math.huge
    for _, ent in ipairs(ents.FindAlongRay(oeil, tr.HitPos, -t, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end
    local couleur = cible and Color(0, 255, 0) or Color(255, 70, 70)

    -- boîte au bout de la visée + ligne du regard (la boîte de départ est dans la tête)
    render.DrawWireframeBox(tr.HitPos, angle_zero, -t, t, couleur, true)
    render.DrawLine(oeil + ply:GetAimVector() * 30, tr.HitPos, couleur, true)

    if cible then
        render.DrawWireframeBox(cible:GetPos(), angle_zero, cible:OBBMins(), cible:OBBMaxs(), Color(0, 255, 0), true)
    end
end)

-- Test : joue la particule du tick là où tu regardes
concommand.Add("jinton_fx_test", function(ply, _, args)
    local nom = args[1] or "solve_geams_01_j"
    ParticleEffect(nom, ply:GetEyeTrace().HitPos + Vector(0, 0, 36), Angle(0, 0, 0))
    print("[Jinton] effet '" .. nom .. "' lancé")
end)
