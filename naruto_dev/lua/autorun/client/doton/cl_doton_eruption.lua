--========================================================
-- Doton : Éruption de roche (CLIENT)
-- Lancement depuis la barre de techniques, puis affichage des roches : de simples modèles CÔTÉ CLIENT (le serveur
-- ne crée aucune entité). Un seul hook Think anime toutes les roches (jaillissement, puis disparition) et se
-- retire dès qu'il n'y en a plus.
--========================================================

game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_impact_floor_small")

local MODELES = {}
for i = 1, 5 do MODELES[i] = "models/nature/doton/nr_doton_debris" .. i .. ".mdl" end

local DEBUT     = 0.05   -- taille de départ (relative) : la roche jaillit du sol
local MONTEE    = 0.15   -- secondes pour atteindre la taille pleine
local DESCENTE  = 0.3    -- secondes pour s'enfoncer à la fin

NA_Cast = NA_Cast or {}
NA_Cast.doton_eruption = function()
    net.Start("doton_eruption_cast")
    net.SendToServer()
end

local roches = {}   -- { mdl, debut, vie, echelle }

local function Animer()
    local now = CurTime()
    for i = #roches, 1, -1 do
        local r = roches[i]
        local mdl = r.mdl
        if not IsValid(mdl) then
            table.remove(roches, i)
        else
            local t = now - r.debut
            if t >= r.vie + DESCENTE then
                mdl:Remove()
                table.remove(roches, i)
            elseif t >= r.vie then
                mdl:SetModelScale(Lerp((t - r.vie) / DESCENTE, r.echelle, DEBUT))
            elseif t < MONTEE then
                mdl:SetModelScale(Lerp(t / MONTEE, DEBUT, r.echelle))
            elseif r.pleine ~= true then
                r.pleine = true   -- taille pleine : plus aucun changement jusqu'à la descente
                mdl:SetModelScale(r.echelle)
            end
        end
    end
    if #roches == 0 then hook.Remove("Think", "DotonEruption_Anim") end
end

net.Receive("doton_eruption_rangee", function()
    local echelle, vie = net.ReadFloat(), net.ReadFloat()
    local particule = net.ReadBool()
    local n = net.ReadUInt(6)
    local now = CurTime()
    local milieu = vector_origin

    for _ = 1, n do
        local pos = net.ReadVector()
        milieu = milieu + pos

        -- recale la roche sur le sol local (le serveur n'a envoyé que la hauteur du milieu de la rangée)
        local tr = util.TraceLine({ start = pos + Vector(0, 0, 100), endpos = pos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then pos = tr.HitPos end

        local mdl = ClientsideModel(MODELES[math.random(#MODELES)], RENDERGROUP_OPAQUE)
        if IsValid(mdl) then
            mdl:SetPos(pos)
            mdl:SetAngles(Angle(math.Rand(-12, 12), math.random(0, 359), math.Rand(-12, 12)))
            mdl:SetModelScale(DEBUT)
            roches[#roches + 1] = { mdl = mdl, debut = now, vie = vie, echelle = echelle }
        end
    end

    -- une seule particule de poussière pour la rangée (si le serveur le demande)
    if particule and n > 0 then
        ParticleEffect("solve_doton_impact_floor_small", milieu / n, angle_zero)
    end

    if #roches > 0 then hook.Add("Think", "DotonEruption_Anim", Animer) end
end)
