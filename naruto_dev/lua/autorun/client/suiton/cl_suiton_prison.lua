--========================================================
-- Suiton : Prison aqueuse (CLIENT)
--
-- Envoie l'appui au serveur (sv_suiton_prison.lua, qui décide de tout) et
-- affiche la prison d'eau sur la cible pendant la durée envoyée par le serveur.
--========================================================

local FX = "atg_prison_aqueuse"   -- particles/atg_particules_prison_aqueuse.pcf (copie de atg_particules.pcf de l'addon ATG)

game.AddParticles("particles/atg_particules_prison_aqueuse.pcf")
PrecacheParticleSystem(FX)

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.suiton_prison = function()
    net.Start("suiton_prison_cast")
    net.SendToServer()
end

-- Bulle d'eau autour de la cible, en plus de la particule.
-- Le modèle a un rayon d'environ 104,6 unités (mesuré dans son .vvd), centré sur son origine.
local MODELE       = "models/nature/bubble_solve_geams_opaque.mdl"
local RAYON_MODELE = 104.6
local REDUCTION    = 0.85   -- 1 = juste assez grande pour contenir la cible ; plus petit = plus serrée
local ALPHA        = 255    -- transparence de la bulle (255 = celle de son matériau)

local prisons = {}   -- cible -> { fx = particule, mdl = sphère, fin = fin de la prison }

local function Fin(cible)
    local p = prisons[cible]
    if not p then return end
    if IsValid(p.fx) then p.fx:StopEmission() end
    if IsValid(p.mdl) then p.mdl:Remove() end
    prisons[cible] = nil
end

net.Receive("suiton_prison_fx", function()
    local cible = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(cible) then return end

    Fin(cible)

    local mdl = ClientsideModel(MODELE, RENDERGROUP_TRANSLUCENT)
    if IsValid(mdl) then
        -- assez grosse pour contenir la cible
        local haut = cible:OBBMaxs().z - cible:OBBMins().z
        mdl:SetModelScale((math.max(haut, 60) / 2 + 12) * REDUCTION / RAYON_MODELE, 0)
        mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
        mdl:SetColor(Color(255, 255, 255, ALPHA))
        mdl:SetPos(cible:WorldSpaceCenter())
    end

    prisons[cible] = {
        fx = CreateParticleSystem(cible, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, cible:OBBCenter().z)),
        mdl = mdl,
        fin = CurTime() + duree,
    }
end)

hook.Add("Think", "suiton_prison_fx", function()
    for cible, p in pairs(prisons) do
        if not IsValid(cible) or not IsValid(p.fx) or CurTime() > p.fin then
            Fin(cible)
        elseif IsValid(p.mdl) then
            p.mdl:SetPos(cible:WorldSpaceCenter())   -- la sphère suit la cible (et son élévation)
        end
    end
end)
