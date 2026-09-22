-- salamandre_spawn.lua
-- Place dans garrysmod/lua/autorun/server/

if CLIENT then return end

local SALAMANDRE_MODEL = "models/salamandre/salamandre.mdl"

-- Table pour stocker les salamandres de chaque joueur
local PlayerSalamandres = {}

-- Fonction pour spawn la salamandre
local function SpawnSalamandre(ply)
    if not IsValid(ply) then return nil end
    
    -- Trouver une position devant le joueur
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 200,
        filter = ply
    })
    
    local spawnPos = tr.HitPos + Vector(0, 0, 10)
    
    -- Créer l'entité salamandre
    local salamandre = ents.Create("npc_salamandre_ride")
    if not IsValid(salamandre) then
        ply:ChatPrint("Erreur: Impossible de créer la salamandre!")
        return nil
    end
    
    salamandre:SetPos(spawnPos)
    salamandre:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    salamandre:SetOwner(ply)
    salamandre.SpawnOwner = ply
    salamandre:Spawn()
    salamandre:Activate()
    
    PlayerSalamandres[ply] = salamandre
    
    return salamandre
end

-- Fonction pour despawn la salamandre
local function DespawnSalamandre(ply)
    if not IsValid(ply) then return false end
    
    if IsValid(PlayerSalamandres[ply]) then
        PlayerSalamandres[ply]:Remove()
        PlayerSalamandres[ply] = nil
        return true
    end
    return false
end

-- Touche U pour spawn/despawn (E sert au bouclier Jinton ; E sur la salamandre = monter/descendre)
hook.Add("PlayerButtonDown", "SalamandreKeyPress", function(ply, button)
    if button ~= KEY_U then return end
    if not ply:Alive() then return end
    -- sur le dragon Mokuton ou sur une monture (salamandre...) : pas d'invocation
    if ply:GetNWBool("MokutonRide", false) then return end
    if IsValid(ply:GetParent()) then return end
    if (ply.NA_NextSalamandre or 0) > CurTime() then return end
    ply.NA_NextSalamandre = CurTime() + 1

    if IsValid(PlayerSalamandres[ply]) then
        DespawnSalamandre(ply)
        ply:ChatPrint("Salamandre renvoyée!")
    else
        local sala = SpawnSalamandre(ply)
        if sala then
            ply:ChatPrint("Salamandre invoquée! Regardez-la et appuyez sur E pour monter.")
        end
    end
end)

-- Nettoyer quand le joueur se déconnecte
hook.Add("PlayerDisconnected", "SalamandreCleanup", function(ply)
    if IsValid(PlayerSalamandres[ply]) then
        PlayerSalamandres[ply]:Remove()
        PlayerSalamandres[ply] = nil
    end
end)

print("[Salamandre] Script chargé! U = spawn/despawn, E sur salamandre = monter/descendre")