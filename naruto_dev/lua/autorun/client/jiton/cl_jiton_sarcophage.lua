--========================================================
-- Jiton : Sarcophage de sable (CLIENT)
-- Lancement depuis la barre de techniques, et sarcophage de sable sur la cible
-- (message "jiton_sarcophage_fx", sv_jiton_sarcophage.lua).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX       = "[1]_sand_sarcophag"   -- particles/atg_faris.pcf
local HAUTEUR  = 0                      -- hauteur de la particule sur la cible (0 = aux pieds)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jiton_sarcophage = function()
    net.Start("jiton_sarcophage_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem(FX)

-- sarcophages en cours : cible -> { ps = particule, fin = CurTime }
local actifs = {}

local function Arreter(ent)
    local a = actifs[ent]
    if a and a.ps and a.ps:IsValid() then a.ps:StopEmission() end
    actifs[ent] = nil
end

net.Receive("jiton_sarcophage_fx", function()
    local cible = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(cible) then return end

    Arreter(cible)   -- un seul sarcophage par cible
    local ps = CreateParticleSystem(cible, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, HAUTEUR))
    if not ps then return end
    actifs[cible] = { ps = ps, fin = CurTime() + duree }
end)

-- le sable se retire à la fin de l'étourdissement, ou si la cible meurt
hook.Add("Think", "NA_JitonSarcophage_FX", function()
    local now = CurTime()
    for ent, a in pairs(actifs) do
        if now >= a.fin or not IsValid(ent) or (ent:IsPlayer() and not ent:Alive()) then
            Arreter(ent)
        end
    end
end)
