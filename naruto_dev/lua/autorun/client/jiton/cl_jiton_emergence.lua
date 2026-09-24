--========================================================
-- Jiton : Émergence de sable (CLIENT)
-- Lancement depuis la barre de techniques, et affichage du sable autour du
-- lanceur ("jiton_emergence_zone", sv_jiton_emergence.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX      = "[1]_sand_emergence"   -- particles/atg_faris.pcf
local FONDU   = 1.5                    -- secondes avant de retirer l'ancre, une fois l'émission coupée
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jiton_emergence = function()
    net.Start("jiton_emergence_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem(FX)

-- zones en cours : ancre -> { lanceur = ent|nil (suit), fin = CurTime, coupe = bool }
local zones = {}

net.Receive("jiton_emergence_zone", function()
    local lanceur = net.ReadEntity()
    local pos = net.ReadVector()
    local suit = net.ReadBool()
    local duree = net.ReadFloat()

    -- ancre invisible : le sable reste posé sur la zone
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(pos)
    ancre:SetAngles(angle_zero)

    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
    zones[ancre] = { lanceur = suit and IsValid(lanceur) and lanceur or nil, fin = CurTime() + duree }
end)

hook.Add("Think", "NA_JitonEmergence_FX", function()
    local now = CurTime()
    for ancre, z in pairs(zones) do
        if not IsValid(ancre) then
            zones[ancre] = nil
        elseif now >= z.fin + FONDU then
            ancre:Remove()
            zones[ancre] = nil
        elseif now >= z.fin or (z.lanceur and (not IsValid(z.lanceur) or not z.lanceur:Alive())) then
            -- fin de la zone, ou lanceur mort : on coupe l'émission, le sable retombe
            if not z.coupe then
                ancre:StopParticles()
                z.coupe = true
                z.fin = math.min(z.fin, now)
            end
        elseif z.lanceur then
            ancre:SetPos(z.lanceur:GetPos())
        end
    end
end)
