--========================================================
-- Katon : Nuée ardente (CLIENT)
-- Lancement depuis la barre de techniques, et affichage de la particule solve_katon_nuee_smoke_fire (particles/
-- solve_new_katon.pcf) au point envoyé par le serveur (sv_katon_nuee.lua).
--
-- La particule jaillit sur une couche de 350 à 400 unités autour de son POINT DE CONTRÔLE 1 (et pas du 0) : on pose donc
-- les deux points de contrôle au même endroit, sinon elle apparaîtrait autour de l'origine de la carte.
--========================================================

game.AddParticles("particles/solve_new_katon.pcf")
local FX = "solve_katon_nuee_smoke_fire"
PrecacheParticleSystem(FX)
local FIL = "solve_katon_fil_link"   -- fil de feu entre la bouche du lanceur (point 0) et la nuée (point 1)
PrecacheParticleSystem(FIL)

NA_Cast = NA_Cast or {}
NA_Cast.katon_nuee = function()
    net.Start("katon_nuee_cast")
    net.SendToServer()
end

net.Receive("katon_nuee_fx", function()
    local pos = net.ReadVector()
    local fx = CreateParticleSystemNoEntity(FX, pos)
    if fx then
        fx:SetControlPoint(0, pos)
        fx:SetControlPoint(1, pos)
    end
end)

-- fil bouche -> nuée : le point 0 suit la bouche du lanceur tant que le fil dure
local fils = {}

local function Bouche(ply)
    local ang = ply:EyeAngles()
    return ply:EyePos() + ang:Forward() * 6 - ang:Up() * 4
end

net.Receive("katon_nuee_fil", function()
    local ply, pos, duree = net.ReadEntity(), net.ReadVector(), net.ReadFloat()
    if not IsValid(ply) then return end
    local fx = CreateParticleSystemNoEntity(FIL, pos)
    if not fx then return end
    fx:SetControlPoint(0, Bouche(ply))
    fx:SetControlPoint(1, pos)
    fils[#fils + 1] = { fx = fx, ply = ply, pos = pos, fin = CurTime() + duree }
    hook.Add("Think", "KatonNuee_Fil", function()
        local now = CurTime()
        for i = #fils, 1, -1 do
            local f = fils[i]
            if now >= f.fin or not IsValid(f.ply) then
                f.fx:StopEmission()
                table.remove(fils, i)
            else
                f.fx:SetControlPoint(0, Bouche(f.ply))
            end
        end
        if #fils == 0 then hook.Remove("Think", "KatonNuee_Fil") end
    end)
end)
