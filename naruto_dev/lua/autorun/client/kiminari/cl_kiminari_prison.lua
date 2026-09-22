--========================================================
-- Kiminari : Prison noire (CLIENT)
-- Lancement depuis la barre de techniques, tornade électrique autour du
-- lanceur ("kiminari_prison_zone") et étincelles sur chaque ennemi étourdi
-- ("kiminari_prison_fx", sv_kiminari_prison.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX_ZONE  = "[3]_electric_tornado"   -- particles/atg_faris.pcf
local FX_STUN  = "[3]_electric_aura"      -- particles/atg_faris.pcf
local FONDU    = 1.5                      -- secondes de disparition après la fin
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kiminari_prison = function()
    net.Start("kiminari_prison_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem(FX_ZONE)
PrecacheParticleSystem(FX_STUN)

local function Ancre(pos)
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(pos)
    ancre:SetAngles(angle_zero)
    return ancre
end

-- tornades en cours : ancre -> { lanceur = ent|nil (suit), fin = CurTime }
local zones = {}

net.Receive("kiminari_prison_zone", function()
    local lanceur = net.ReadEntity()
    local pos = net.ReadVector()
    local suit = net.ReadBool()
    local duree = net.ReadFloat()

    local ancre = Ancre(pos)
    if not IsValid(ancre) then return end
    ParticleEffectAttach(FX_ZONE, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
    zones[ancre] = { lanceur = suit and IsValid(lanceur) and lanceur or nil, fin = CurTime() + duree }
end)

-- étincelles sur les ennemis étourdis : l'ancre suit leurs pieds
local actifs = {}   -- ent -> { ancre, fin }

net.Receive("kiminari_prison_fx", function()
    local ent = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ent) then return end

    local a = actifs[ent]
    if a and IsValid(a.ancre) then
        a.fin = math.max(a.fin, CurTime() + duree)
        return
    end

    local ancre = Ancre(ent:GetPos())
    if not IsValid(ancre) then return end
    ParticleEffectAttach(FX_STUN, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
    actifs[ent] = { ancre = ancre, fin = CurTime() + duree }
end)

hook.Add("Think", "NA_KiminariPrison_FX", function()
    local now = CurTime()

    for ancre, z in pairs(zones) do
        if not IsValid(ancre) then
            zones[ancre] = nil
        elseif now >= z.fin + FONDU then
            ancre:Remove()
            zones[ancre] = nil
        elseif now >= z.fin or (z.lanceur and (not IsValid(z.lanceur) or not z.lanceur:Alive())) then
            if not z.coupe then
                ancre:StopParticles()
                z.coupe = true
                z.fin = math.min(z.fin, now)
            end
        elseif z.lanceur then
            ancre:SetPos(z.lanceur:GetPos())
        end
    end
    for ent, a in pairs(actifs) do
        if now >= a.fin or not IsValid(ent) or (ent:IsPlayer() and not ent:Alive()) then
            if IsValid(a.ancre) then
                a.ancre:StopParticles()
                a.ancre:Remove()
            end
            actifs[ent] = nil
        elseif IsValid(a.ancre) then
            a.ancre:SetPos(ent:GetPos())
        end
    end
end)
