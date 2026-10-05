--========================================================
-- Hyoton : Pics de glace (CLIENT)
-- Lancement depuis la barre de techniques, puis affichage de chaque rangée envoyée par le serveur : les pics sont de
-- simples modèles clients (aucune entité serveur) qui poussent, restent `vie` secondes puis rétrécissent ; un seul hook
-- Think les gère tous et il disparaît quand il n'y en a plus.
--========================================================

local MODELE = "models/hyoton/cayzi_props_hyoton_2.mdl"
local POUSSE, FONTE = 0.15, 0.3
util.PrecacheModel(MODELE)

NA_Cast = NA_Cast or {}
NA_Cast.hyoton_pics = function()
    net.Start("hyoton_pics_cast")
    net.SendToServer()
end

-- Particule à chaque apparition d'un pic (particles/1izoxsolvenr.pcf)
game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem("izox_hyoton_hit")

net.Receive("hyoton_pics_touche", function()
    ParticleEffect("izox_hyoton_hit", net.ReadVector(), angle_zero)
end)

local pics = {}

local function Mettre()
    local now = CurTime()
    for i = #pics, 1, -1 do
        local c = pics[i]
        local e = c.e
        local t = now - c.debut
        if not IsValid(e) or t >= c.vie + FONTE then
            if IsValid(e) then e:Remove() end
            table.remove(pics, i)
        elseif t < POUSSE then
            e:SetModelScale(Lerp(t / POUSSE, 0.05, c.ech), 0)
        elseif t < c.vie then
            if not c.plein then c.plein = true e:SetModelScale(c.ech, 0) end
        else
            e:SetModelScale(Lerp((t - c.vie) / FONTE, c.ech, 0.05), 0)
        end
    end
    if #pics == 0 then hook.Remove("Think", "HyotonPics_Pics") end
end

net.Receive("hyoton_pics_rangee", function()
    local vie, decalage, n = net.ReadFloat(), net.ReadFloat(), net.ReadUInt(3)
    local debut = CurTime()
    for _ = 1, n do
        local p = net.ReadVector()
        local pitch, yaw, roll = net.ReadInt(6), net.ReadUInt(9), net.ReadInt(6)
        local ech = net.ReadFloat()
        local e = ClientsideModel(MODELE, RENDERGROUP_OPAQUE)
        if IsValid(e) then
            e:SetPos(p)
            e:SetAngles(Angle(-90 + pitch, yaw, roll))   -- le modèle est couché sur X : pointe vers le haut
            e:SetModelScale(0.05, 0)
            pics[#pics + 1] = { e = e, ech = ech, vie = vie, debut = debut }
        end
        ParticleEffect("izox_hyoton_hit", p - Vector(0, 0, decalage), angle_zero)
    end
    if #pics > 0 then hook.Add("Think", "HyotonPics_Pics", Mettre) end
end)
