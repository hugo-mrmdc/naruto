--========================================================
-- Shoton : Pics de cristal (CLIENT)
-- Lancement depuis la barre de techniques, puis affichage de chaque rangée envoyée par le serveur : les cristaux sont de
-- simples modèles clients (aucune entité serveur) qui poussent, restent `vie` secondes puis rétrécissent ; un seul hook
-- Think les gère tous et il disparaît quand il n'y en a plus. Particules au centre de chaque rangée.
--========================================================

local MODELE = "models/shoton/solve_crystal01_kg_geams.mdl"
local POUSSE, FONTE = 0.15, 0.3
util.PrecacheModel(MODELE)

NA_Cast = NA_Cast or {}
NA_Cast.shoton_pics = function()
    net.Start("shoton_pics_cast")
    net.SendToServer()
end

local cristaux = {}

local function Mettre()
    local now = CurTime()
    for i = #cristaux, 1, -1 do
        local c = cristaux[i]
        local e = c.e
        local t = now - c.debut
        if not IsValid(e) or t >= c.vie + FONTE then
            if IsValid(e) then e:Remove() end
            table.remove(cristaux, i)
        elseif t < POUSSE then
            e:SetModelScale(Lerp(t / POUSSE, 0.05, c.ech), 0)
        elseif t < c.vie then
            if not c.plein then c.plein = true e:SetModelScale(c.ech, 0) end
        else
            e:SetModelScale(Lerp((t - c.vie) / FONTE, c.ech, 0.05), 0)
        end
    end
    if #cristaux == 0 then hook.Remove("Think", "ShotonPics_Cristaux") end
end

net.Receive("shoton_pics_touche", function()
    local pos, vie, n = net.ReadVector(), net.ReadFloat(), net.ReadUInt(6)
    local debut = CurTime()
    for _ = 1, n do
        local p = net.ReadVector()
        local yaw, pitch, roll = net.ReadUInt(9), net.ReadInt(7), net.ReadInt(7)
        local ech = net.ReadFloat()
        local col = Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8))
        local e = ClientsideModel(MODELE, RENDERGROUP_OPAQUE)
        if IsValid(e) then
            e:SetPos(p)
            e:SetAngles(Angle(pitch, yaw, roll))
            e:SetColor(col)
            e:SetModelScale(0.05, 0)
            cristaux[#cristaux + 1] = { e = e, ech = ech, vie = vie, debut = debut }
        end
    end
    if #cristaux > 0 then hook.Add("Think", "ShotonPics_Cristaux", Mettre) end

    local sol = util.TraceLine({ start = pos + Vector(0, 0, 100), endpos = pos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
    ParticleEffect("solve_custom_explo_pink_pikes_emeraude", sol.Hit and sol.HitPos or pos, angle_zero)
end)
