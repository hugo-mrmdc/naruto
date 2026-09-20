-- ========================================
-- cl_accessory_display.lua - CÔTÉ CLIENT
-- Gestion des accessoires avec la classe Accessory
-- ========================================
print("[CLIENT] Accessory Display chargé")

-- Table pour stocker les instances d'accessoires par joueur
local PlayerAccessories = {}

-- Accès à un accessoire affiché (utilisé par l'éditeur de placement de cl_monmenu.lua
-- pour déplacer l'accessoire en direct, sans passer par le serveur)
function NA_AccessoireInstance(ply, id)
    return PlayerAccessories[ply] and PlayerAccessories[ply][id]
end

local function EnsureAccTable(ply)
    if not IsValid(ply) then return end
    PlayerAccessories[ply] = PlayerAccessories[ply] or {}
end

-- ✅ Recevoir un accessoire depuis le serveur
net.Receive("Accessory_Set", function()
    print("[CLIENT] =====================================")
    print("[CLIENT] Message Accessory_Set reçu")
    
    local ply = net.ReadEntity()
    local id = net.ReadString()
    local modelPath = net.ReadString()
    local boneName = net.ReadString()
    local posOffset = net.ReadVector()
    local angOffset = net.ReadAngle()
    local scale = net.ReadFloat()

    if not IsValid(ply) then 
        print("[CLIENT] ERREUR: Entité invalide reçue")
        print("[CLIENT] =====================================")
        return 
    end
    
    local playerName = ply:IsPlayer() and ply:Nick() or "Entité"
    print("[CLIENT] Joueur: " .. playerName)
    print("[CLIENT] ID: " .. id)
    print("[CLIENT] Model: " .. modelPath)
    print("[CLIENT] Bone: " .. boneName)
    print("[CLIENT] PosOffset: " .. tostring(posOffset))
    print("[CLIENT] AngOffset: " .. tostring(angOffset))
    print("[CLIENT] Scale: " .. scale)
    
    EnsureAccTable(ply)

    -- Retirer l'ancien accessoire s'il existe
    if PlayerAccessories[ply][id] then
        PlayerAccessories[ply][id]:Remove()
        print("[CLIENT] Ancien accessoire '" .. id .. "' retiré")
    end

    -- ✅ Créer une nouvelle instance d'Accessory
    if not Accessory then
        print("[CLIENT] ERREUR: La classe Accessory n'est pas chargée!")
        print("[CLIENT] Assure-toi que cl_accessory_class.lua est chargé AVANT ce fichier")
        print("[CLIENT] =====================================")
        return
    end
    
    local acc = Accessory:new(ply, modelPath, boneName, posOffset, angOffset, scale)
    
    if not acc:IsValid() then
        print("[CLIENT] ERREUR: Impossible de créer l'accessoire " .. modelPath)
        print("[CLIENT] =====================================")
        return
    end

    -- Stocker l'instance
    PlayerAccessories[ply][id] = acc

    print("[CLIENT] ✅ Accessoire '" .. id .. "' créé avec succès pour " .. playerName)
    print("[CLIENT] =====================================")
end)

-- ✅ Retirer un accessoire
net.Receive("Accessory_Remove", function()
    print("[CLIENT] =====================================")
    print("[CLIENT] Message Accessory_Remove reçu")
    
    local ply = net.ReadEntity()
    local id = net.ReadString()

    if not IsValid(ply) then 
        print("[CLIENT] ERREUR: Entité invalide")
        print("[CLIENT] =====================================")
        return 
    end
    
    EnsureAccTable(ply)

    if PlayerAccessories[ply][id] then
        PlayerAccessories[ply][id]:Remove()
        PlayerAccessories[ply][id] = nil
        
        local playerName = ply:IsPlayer() and ply:Nick() or "Entité"
        print("[CLIENT] ✅ Accessoire '" .. id .. "' retiré de " .. playerName)
    else
        print("[CLIENT] Accessoire '" .. id .. "' non trouvé")
    end
    print("[CLIENT] =====================================")
end)

-- ✅ Nettoyer quand un joueur part
hook.Add("EntityRemoved", "Accessory_CleanupOnLeave", function(ent)
    if not ent:IsPlayer() then return end
    
    if PlayerAccessories[ent] then
        for id, acc in pairs(PlayerAccessories[ent]) do
            if acc then
                acc:Remove()
            end
        end
        PlayerAccessories[ent] = nil
        print("[CLIENT] Accessoires nettoyés pour un joueur qui a quitté")
    end
end)

-- ✅ Dessiner les accessoires sur les joueurs (FIX boucle infinie)
hook.Add("PostPlayerDraw", "Accessory_Draw", function(ply)
    if not IsValid(ply) then return end
    if not PlayerAccessories[ply] then return end

    for id, acc in pairs(PlayerAccessories[ply]) do
        if acc and acc:IsValid() then
            acc:Draw()
        else
            -- Nettoyer les accessoires invalides
            PlayerAccessories[ply][id] = nil
        end
    end
end)

print("[CLIENT] =====================================")
print("[CLIENT] Accessory Display prêt!")
print("[CLIENT] Hook PostPlayerDraw enregistré")
print("[CLIENT] =====================================")