-- ========================================
-- sv_accessory_handler.lua - CÔTÉ SERVEUR
-- ========================================
print("[SERVER] Accessory Handler chargé")

util.AddNetworkString("Accessory_Set")
util.AddNetworkString("Accessory_Remove")

local function EnsureAccTable(ply)
    ply._Accessories = ply._Accessories or {}
end

-- Donner / remplacer un accessoire à un joueur
function GiveAccessory(ply, id, modelPath, boneName, posOffset, angOffset, scale)
    if not IsValid(ply) then return end
    EnsureAccTable(ply)

    ply._Accessories[id] = {
        modelPath = modelPath,
        boneName = boneName or "ValveBiped.Bip01_Head1",
        posOffset = posOffset or Vector(0, 0, 0),
        angOffset = angOffset or Angle(0, 0, 0),
        scale = scale or Vector(1, 1, 1)
    }

    local data = ply._Accessories[id]

    net.Start("Accessory_Set")
        net.WriteEntity(ply)
        net.WriteString(id)
        net.WriteString(data.modelPath)
        net.WriteString(data.boneName)
        net.WriteVector(data.posOffset)
        net.WriteAngle(data.angOffset)
        net.WriteFloat(type(data.scale) == "number" and data.scale or 1)
    net.Broadcast()
    
    print("[SERVER] Accessoire '" .. id .. "' donné à " .. ply:Nick() .. " (" .. modelPath .. ")")
end

-- Retirer un accessoire
function RemoveAccessory(ply, id)
    if not IsValid(ply) then return end
    EnsureAccTable(ply)

    ply._Accessories[id] = nil

    net.Start("Accessory_Remove")
        net.WriteEntity(ply)
        net.WriteString(id)
    net.Broadcast()
    
    print("[SERVER] Accessoire '" .. id .. "' retiré de " .. ply:Nick())
end

-- ✅ IMPORTANT: Recevoir les demandes DEPUIS L'INVENTAIRE (client → serveur)
-- Emplacements acceptés et limites de placement (éditeur de cl_monmenu.lua)
local EMPLACEMENTS_OK = { masque = true, accessoire = true }
local DECALAGE_MAX = 40      -- unités, sur chaque axe
local ECHELLE_MIN, ECHELLE_MAX = 0.1, 3
local prochainSet = {}

net.Receive("Accessory_Set", function(len, ply)
    local id = net.ReadString()
    local modelPath = net.ReadString()
    local boneName = net.ReadString()
    local posOffset = net.ReadVector()
    local angOffset = net.ReadAngle()
    local scale = net.ReadFloat()

    if not IsValid(ply) then return end

    -- anti-spam (l'éditeur n'envoie qu'à la validation, mais on se protège)
    if (prochainSet[ply] or 0) > CurTime() then return end
    prochainSet[ply] = CurTime() + 0.25

    -- valeurs refusées ou ramenées dans des limites raisonnables
    if not EMPLACEMENTS_OK[id] then return end
    modelPath = string.lower(modelPath or "")
    if not string.StartWith(modelPath, "models/") or not util.IsValidModel(modelPath) then return end
    if boneName == "" or #boneName > 64 then boneName = "ValveBiped.Bip01_Head1" end

    posOffset = Vector(
        math.Clamp(posOffset.x, -DECALAGE_MAX, DECALAGE_MAX),
        math.Clamp(posOffset.y, -DECALAGE_MAX, DECALAGE_MAX),
        math.Clamp(posOffset.z, -DECALAGE_MAX, DECALAGE_MAX))
    angOffset = Angle(math.NormalizeAngle(angOffset.p), math.NormalizeAngle(angOffset.y), math.NormalizeAngle(angOffset.r))
    scale = math.Clamp(scale ~= scale and 1 or scale, ECHELLE_MIN, ECHELLE_MAX)   -- (NaN -> 1)

    GiveAccessory(ply, id, modelPath, boneName, posOffset, angOffset, scale)
end)

hook.Add("PlayerDisconnected", "Accessory_AntiSpamCleanup", function(ply)
    prochainSet[ply] = nil
end)

net.Receive("Accessory_Remove", function(len, ply)
    print("[SERVER] =====================================")
    print("[SERVER] Message Accessory_Remove reçu de: " .. ply:Nick())
    
    local id = net.ReadString()
    
    print("[SERVER] Retrait accessoire ID: " .. id)
    print("[SERVER] =====================================")
    
    -- Appeler la fonction pour retirer l'accessoire
    RemoveAccessory(ply, id)
end)

-- Quand un joueur rejoint, on lui envoie l'état des accessoires déjà présents
hook.Add("PlayerInitialSpawn", "Accessory_SyncOnJoin", function(newPly)
    timer.Simple(1, function()
        if not IsValid(newPly) then return end

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply._Accessories then
                for id, data in pairs(ply._Accessories) do
                    net.Start("Accessory_Set")
                        net.WriteEntity(ply)
                        net.WriteString(id)
                        net.WriteString(data.modelPath)
                        net.WriteString(data.boneName)
                        net.WriteVector(data.posOffset)
                        net.WriteAngle(data.angOffset)
                        net.WriteFloat(type(data.scale) == "number" and data.scale or 1)
                    net.Send(newPly)
                end
            end
        end
        
        print("[SERVER] Accessoires synchronisés pour " .. newPly:Nick())
    end)
end)

-- Commandes test
hook.Add("PlayerSay", "Accessory_TestCommands", function(ply, text)
    text = string.Trim(string.lower(text))

    if text == "!cone" then
        print("[SERVER] Commande !cone exécutée")
        GiveAccessory(
            ply,
            "cone",
            "models/accessory/mask_hanzou.mdl",
            "ValveBiped.Bip01_Head1",
            Vector(2, 0, 2),
            Angle(-90, -90, 0),
            1
        )
        return ""
    end

    if text == "!ncone" then
        print("[SERVER] Commande !ncone exécutée")
        RemoveAccessory(ply, "cone")
        return ""
    end
end)

print("[SERVER] =====================================")
print("[SERVER] Accessory Handler prêt!")
print("[SERVER] Commandes test:")
print("[SERVER]   !cone  - Équiper le masque")
print("[SERVER]   !ncone - Retirer le masque")
print("[SERVER] =====================================")