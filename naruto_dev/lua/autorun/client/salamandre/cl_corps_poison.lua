--========================================================
-- Corps de poison de la salamandre (CLIENT)
--
-- Lancement depuis la barre de techniques (pas de touche dédiée : toutes les
-- lettres sont déjà prises). L'aura godio_aura_sala suit l'état réseau
-- "NA_CorpsPoison" de chaque joueur : tout le monde la voit, y compris un
-- joueur qui arrive en cours de route.
--========================================================

local FX = "godio_aura_sala"   -- particles/godio_salamandre.pcf (chargé par salamandre_init.lua)

-- Lancement (appelé par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.salamandre_corps = function()
    net.Start("salamandre_corps_cast")
    net.SendToServer()
end

----------------------------------------------------------
-- Aura
----------------------------------------------------------
local auras = {}   -- joueur -> effet de particules

local function Retirer(ply)
    local fx = auras[ply]
    if fx and fx:IsValid() then fx:StopEmission() end
    auras[ply] = nil
end

local prochain = 0
hook.Add("Think", "SalamandreCorps_Aura", function()
    if CurTime() < prochain then return end
    prochain = CurTime() + 0.2

    for _, ply in ipairs(player.GetAll()) do
        -- pas d'aura sur un joueur mort ou invisible (Fuma)
        local actif = ply:Alive() and ply:GetNW2Bool("NA_CorpsPoison", false) and not ply:GetNoDraw()
        local fx = auras[ply]

        if actif and not (fx and fx:IsValid()) then
            auras[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        elseif not actif and fx then
            Retirer(ply)
        end
    end

    for ply in pairs(auras) do
        if not IsValid(ply) then Retirer(ply) end
    end
end)
