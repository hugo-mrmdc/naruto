--========================================================
-- Kiminari : Boulets noirs (CLIENT)
-- Lancement depuis la barre de techniques ; boules noires dans le dos du
-- lanceur ("kiminari_boulets_boules"), qui partent une par une vers leur cible
-- ("kiminari_boulets_tir") et explosent à l'impact. "kiminari_boulets_fin"
-- retire celles qui restent (sv_kiminari_boulets.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_BOULE  = "frappe_noir_pat"          -- particles/patlick_atgparticules.pcf
local FX_IMPACT = "impact_frappe_noir_pat"   -- particles/patlick_atgparticules.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kiminari_boulets = function()
    net.Start("kiminari_boulets_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX_BOULE)
PrecacheParticleSystem(FX_IMPACT)

local function Boule(pos)
    local fx = CreateParticleSystemNoEntity(FX_BOULE, pos)
    if fx and fx:IsValid() then
        fx:SetControlPoint(0, pos)
        return fx
    end
end

local function Detruire(fx, net)
    if not fx or not fx:IsValid() then return end
    if net then fx:StopEmissionAndDestroyImmediately() else fx:StopEmission() end
end

local dos = {}    -- lanceur -> { n = total, [i] = effet de la boule n° i }
local vols = {}   -- boules en route : { fx, depart, arrivee, debut, duree }

net.Receive("kiminari_boulets_boules", function()
    local ply = net.ReadEntity()
    local n = net.ReadUInt(6)
    if not IsValid(ply) then return end

    if dos[ply] then
        for i = 1, dos[ply].n do Detruire(dos[ply][i], true) end
    end

    local liste = { n = n }
    for i = 1, n do liste[i] = Boule(NA_KiminariBoulePos(ply, i, n)) end
    dos[ply] = liste
end)

net.Receive("kiminari_boulets_tir", function()
    local ply = net.ReadEntity()
    local i = net.ReadUInt(6)
    local depart = net.ReadVector()
    local arrivee = net.ReadVector()
    local duree = net.ReadFloat()

    -- la boule quitte le dos : elle part de là où on la voit
    local liste = IsValid(ply) and dos[ply]
    if liste and liste[i] then
        depart = NA_KiminariBoulePos(ply, i, liste.n)
        Detruire(liste[i], true)
        liste[i] = nil
    end

    local fx = Boule(depart)
    if not fx then return end
    vols[#vols + 1] = { fx = fx, depart = depart, arrivee = arrivee, debut = CurTime(), duree = math.max(duree, 0.01) }
end)

net.Receive("kiminari_boulets_fin", function()
    local ply = net.ReadEntity()
    local liste = dos[ply]
    if not liste then return end
    for i = 1, liste.n do Detruire(liste[i], true) end
    dos[ply] = nil
end)

hook.Add("Think", "NA_KiminariBoulets_FX", function()
    -- les boules restées dans le dos suivent le lanceur
    for ply, liste in pairs(dos) do
        if not IsValid(ply) or not ply:Alive() then
            for i = 1, liste.n do Detruire(liste[i], true) end
            dos[ply] = nil
        else
            for i = 1, liste.n do
                local fx = liste[i]
                if fx and fx:IsValid() then fx:SetControlPoint(0, NA_KiminariBoulePos(ply, i, liste.n)) end
            end
        end
    end

    -- les boules tirées avancent jusqu'à l'impact
    local now = CurTime()
    for k = #vols, 1, -1 do
        local v = vols[k]
        local t = (now - v.debut) / v.duree
        if t >= 1 then
            Detruire(v.fx)
            local imp = CreateParticleSystemNoEntity(FX_IMPACT, v.arrivee)
            if imp and imp:IsValid() then
                imp:SetControlPoint(0, v.arrivee)
                imp:SetControlPoint(1, v.arrivee)
            end
            table.remove(vols, k)
        elseif v.fx and v.fx:IsValid() then
            v.fx:SetControlPoint(0, LerpVector(t, v.depart, v.arrivee))
        end
    end
end)
