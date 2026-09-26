--========================================================
-- Kiminari : Frappe noire (CLIENT)
-- Lancement depuis la barre de techniques, et particule de la frappe sur le
-- point visé (rien sur les ennemis étourdis)
-- (message "kiminari_frappe_fx", sv_kiminari_frappe.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX = "[19]_kiminari_charge"   -- particles/atg_farisv2.pcf
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kiminari_frappe = function()
    net.Start("kiminari_frappe_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem(FX)

-- ancre invisible par effet : la particule reste aux pieds de l'entité (ou sur
-- le point visé), sans tourner avec la caméra
-- clé = entité suivie, ou une table { pos = Vector } pour un point du monde
local actifs = {}   -- clé -> { ancre = modèle, fin = CurTime, pos = Vector|nil }

local function Arreter(cle)
    local a = actifs[cle]
    if a and IsValid(a.ancre) then
        a.ancre:StopParticles()
        a.ancre:Remove()
    end
    actifs[cle] = nil
end

local function Demarrer(cle, pos, duree)
    local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(ancre) then return end
    ancre:SetNoDraw(true)
    ancre:SetPos(pos)
    ancre:SetAngles(angle_zero)
    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
    actifs[cle] = { ancre = ancre, fin = CurTime() + duree, pos = not isentity(cle) and pos or nil }
end

net.Receive("kiminari_frappe_fx", function()
    local surEntite = net.ReadBool()
    local ent = surEntite and net.ReadEntity() or nil
    local pos = not surEntite and net.ReadVector() or nil
    local duree = net.ReadFloat()

    if surEntite then return end   -- rien sur les ennemis étourdis : la frappe ne s'affiche qu'au point visé

    if not surEntite then
        Demarrer({}, pos, duree)
        return
    end
    if not IsValid(ent) then return end

    local a = actifs[ent]
    if a and IsValid(a.ancre) then
        a.fin = math.max(a.fin, CurTime() + duree)   -- déjà chargé : on prolonge
        return
    end
    Demarrer(ent, ent:GetPos(), duree)
end)

hook.Add("Think", "NA_KiminariFrappe_FX", function()
    local now = CurTime()
    for cle, a in pairs(actifs) do
        if now >= a.fin then
            Arreter(cle)
        elseif not a.pos then
            if not IsValid(cle) or (cle:IsPlayer() and not cle:Alive()) then
                Arreter(cle)
            elseif IsValid(a.ancre) then
                a.ancre:SetPos(cle:GetPos())
            end
        end
    end
end)
