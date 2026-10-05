--========================================================
-- Suiton : Pluie suiton (CLIENT)
-- Lancement depuis la barre de techniques, puis affichage : le nuage (water_tornado_pat) et les bulles qui tombent,
-- avec les MÊMES particules que la technique Bulles (atg_bulle_eau, et jet_eau_hit_pat à l'impact). Rien n'est une entité :
-- ce sont des particules déplacées par un seul hook Think, qui se retire dès qu'il n'y en a plus.
--========================================================

game.AddParticles("particles/patlick_atgsuiton.pcf")   -- nuage
game.AddParticles("particles/atg_particules.pcf")       -- atg_bulle_eau (comme la technique Bulles)
game.AddParticles("particles/atg_particules2.pcf")      -- jet_eau_hit_pat (explosion, comme la technique Bulles)
local FX_NUAGE   = "water_tornado_pat"
local FX_BULLE   = "atg_bulle_eau"
local FX_EXPLO   = "jet_eau_hit_pat"
PrecacheParticleSystem(FX_NUAGE)
PrecacheParticleSystem(FX_BULLE)
PrecacheParticleSystem(FX_EXPLO)

NA_Cast = NA_Cast or {}
NA_Cast.suiton_pluie = function()
    net.Start("suiton_pluie_cast")
    net.SendToServer()
end

local bulles = {}   -- { fx, de, vers, debut, chute }
local nuages = {}   -- { fx, fin }

local function Animer()
    local now = CurTime()

    for i = #bulles, 1, -1 do
        local b = bulles[i]
        local t = (now - b.debut) / b.chute
        if t >= 1 then
            if b.fx and b.fx:IsValid() then b.fx:StopEmission(false, true) end
            ParticleEffect(FX_EXPLO, b.vers, Vector(0, 0, 1):Angle())   -- la bulle touche le sol : explosion
            table.remove(bulles, i)
        elseif b.fx and b.fx:IsValid() then
            b.fx:SetControlPoint(0, LerpVector(t, b.de, b.vers))
        else
            table.remove(bulles, i)
        end
    end

    for i = #nuages, 1, -1 do
        if now >= nuages[i].fin then
            if nuages[i].fx and nuages[i].fx:IsValid() then nuages[i].fx:StopEmission() end
            table.remove(nuages, i)
        end
    end

    if #bulles == 0 and #nuages == 0 then hook.Remove("Think", "SuitonPluie_Anim") end
end

net.Receive("suiton_pluie_nuage", function()
    local pos, duree = net.ReadVector(), net.ReadFloat()
    local fx = CreateParticleSystemNoEntity(FX_NUAGE, pos)
    if fx then
        nuages[#nuages + 1] = { fx = fx, fin = CurTime() + duree }
        hook.Add("Think", "SuitonPluie_Anim", Animer)
    end
end)

net.Receive("suiton_pluie_vague", function()
    local hauteur, chute = net.ReadFloat(), net.ReadFloat()
    local now = CurTime()
    for _ = 1, net.ReadUInt(6) do
        local sol = net.ReadVector()
        local depart = sol + Vector(0, 0, hauteur)
        local fx = CreateParticleSystemNoEntity(FX_BULLE, depart)
        if fx then
            bulles[#bulles + 1] = { fx = fx, de = depart, vers = sol, debut = now, chute = chute }
        end
    end
    if #bulles > 0 then hook.Add("Think", "SuitonPluie_Anim", Animer) end
end)
