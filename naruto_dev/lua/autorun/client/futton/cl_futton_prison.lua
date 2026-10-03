--========================================================
-- Futton : Prison de vapeur (CLIENT)
-- Lancement depuis la barre de techniques, et particule cage_vapeur_pat sur chaque cible étourdie
-- (NW2Float "NA_FuttonPrisonFin", sv_futton_prison.lua).
--========================================================

local FX = "cage_vapeur_pat"   -- particles/patlick_atgparticules.pcf

NA_Cast = NA_Cast or {}
NA_Cast.futton_prison = function()
    net.Start("futton_prison_cast")
    net.SendToServer()
end

-- ancre invisible par cible (même méthode que cl_futton_vapeur.lua) : la particule reste droite, sans tourner avec la cible
local cages = {}   -- [entité] = ancre
local prochain = 0
local cibles = {}

local function Arreter(ent)
    local ancre = cages[ent]
    if IsValid(ancre) then
        ancre:StopParticles()
        ancre:Remove()
    end
    cages[ent] = nil
end

hook.Add("Think", "NA_FuttonPrison", function()
    local now = CurTime()
    if now >= prochain then
        prochain = now + 0.2
        cibles = ents.GetAll()   -- joueurs, PNJ et NextBots (mannequin) peuvent être étourdis
        for _, ent in ipairs(cibles) do
            local actif = ent:GetNW2Float("NA_FuttonPrisonFin", 0) > now
            if actif and not cages[ent] then
                local ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
                if IsValid(ancre) then
                    ancre:SetNoDraw(true)
                    ancre:SetPos(ent:GetPos())
                    ancre:SetAngles(angle_zero)
                    cages[ent] = ancre
                    ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
                end
            elseif not actif and cages[ent] then
                Arreter(ent)
            end
        end
    end
    for ent, ancre in pairs(cages) do   -- suit la cible ; entités disparues
        if IsValid(ent) then ancre:SetPos(ent:GetPos()) else Arreter(ent) end
    end
end)
