-- garrysmod/lua/autorun/server/na_thirdperson_sv.lua
if not SERVER then return end

-- ConVar globale contrôlée par le serveur et répliquée aux clients
CreateConVar(
    "na_tps_dist",
    "500",
    { FCVAR_REPLICATED, FCVAR_NOTIFY },
    "Distance de la camera thirdperson (controle serveur)."
)

CreateConVar(
    "na_tps_height",
    "10",
    { FCVAR_REPLICATED, FCVAR_NOTIFY },
    "Hauteur de la camera thirdperson (controle serveur)."
)

-- Commande serveur (console) pour changer la distance
-- Utilisation: na_tps_setdist 350
concommand.Add("na_tps_setdist", function(ply, cmd, args)
    -- Autoriser console serveur ou admins
    if IsValid(ply) and not ply:IsAdmin() then return end

    local v = tonumber(args[1] or "")
    if not v then return end

    v = math.Clamp(math.floor(v), 50, 3000)
    GetConVar("na_tps_dist"):SetInt(v)
end)

-- Commande serveur (console) pour changer la hauteur
-- Utilisation: na_tps_setheight 20
concommand.Add("na_tps_setheight", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local v = tonumber(args[1] or "")
    if not v then return end

    v = math.Clamp(math.floor(v), -200, 500)
    GetConVar("na_tps_height"):SetInt(v)
end)
