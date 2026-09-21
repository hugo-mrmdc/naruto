util.AddNetworkString("MokutonSpawn_fleur")
util.AddNetworkString("Mokuton_FlowerFX")

local MODEL = "models/mokuton/flower.mdl"
local DAMAGE_RADIUS = 500
local DAMAGE_AMOUNT = 50
local SPAWN_DISTANCE = 20

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "mokuton_fleur", stat, base) end

print("[MOKUTON] =================================")
print("[MOKUTON] sv_mokuton chargé ✅")
print("[MOKUTON] =================================")

local cooldown = 1.5

-- Fonction de dégâts (définie AVANT SpawnFlowerAndDamage)
local function ApplyFlowerDamage(flowerEnt, pos, caller)
    local targets = ents.FindInSphere(pos, Niv(caller, "damage_radius", DAMAGE_RADIUS))
    print("[MOKUTON] Entités dans le rayon:", #targets)
    
    local damaged = 0
    for _, target in ipairs(targets) do
        if not IsValid(target) then continue end
        
        if (target:IsPlayer() or target:IsNPC()) and target ~= caller then
            local dmg = DamageInfo()
            dmg:SetDamage(NA_Stat(caller, "mokuton_fleur", "degats", DAMAGE_AMOUNT))
            dmg:SetAttacker(caller)
            dmg:SetInflictor(flowerEnt)
            dmg:SetDamageType(DMG_BLAST)
            
            target:TakeDamageInfo(dmg)
            damaged = damaged + 1
            print("[MOKUTON] ✅ Dégâts infligés à:", target:IsPlayer() and target:Nick() or target:GetClass())
        end
    end
    
    print("[MOKUTON] Total ennemis touchés:", damaged)
end

local function SpawnFlowerAndDamage(caller)
    print("[MOKUTON] >> SpawnFlowerAndDamage appelée")
    
    if not IsValid(caller) then 
        print("[MOKUTON] ❌ Caller invalide")
        return 
    end

    -- Position devant le joueur (légèrement sous le sol pour l'animation de croissance)
    local spawnPos = caller:GetPos() + caller:GetForward() * Niv(caller, "spawn_distance", SPAWN_DISTANCE)
    spawnPos.z = spawnPos.z - 200 -- Démarre sous terre
    local spawnAng = caller:GetAngles()
    
    print("[MOKUTON] Position spawn:", spawnPos)
    
    -- Spawn la fleur
    local ent = ents.Create("prop_physics")
    if not IsValid(ent) then 
        print("[MOKUTON] ❌ Impossible de créer l'entité")
        return 
    end

    -- SetModel ne provoque pas d'erreur si le modèle manque : on vérifie avant
    if util.IsValidModel(MODEL) then
        ent:SetModel(MODEL)
    else
        print("[MOKUTON] ❌ Modèle introuvable, utilisation d'un prop par défaut")
        ent:SetModel("models/props_c17/oildrum001.mdl")
    end
    
    ent:SetPos(spawnPos)
    ent:SetAngles(spawnAng)
    ent:Spawn()
    ent:Activate()
    ent:SetModelScale(0.1, 0) -- Commence minuscule
    ent:SetCollisionGroup(COLLISION_GROUP_WORLD)

    -- la fleur est déplacée à la main : pas de physique qui la fait tomber
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
    
    print("[MOKUTON] ✅ Fleur créée, début de l'animation!")

    -- 🌸 ENVOIE LA PARTICULE À TOUS LES JOUEURS
    net.Start("Mokuton_FlowerFX")
        net.WriteVector(spawnPos + Vector(0, 0, 200))
        net.WriteAngle(spawnAng)
    net.Broadcast()
    
    print("[MOKUTON] ✨ Particule envoyée à tous les clients")

    -- 🎬 ANIMATION DE CROISSANCE (2 secondes)
    local startTime = CurTime()
    local growDuration = 2
    local finalPos = spawnPos + Vector(0, 0, 200)
    
    local growTimer = "MokutonGrow_" .. ent:EntIndex()
    timer.Create(growTimer, 0.02, 0, function()
        if not IsValid(ent) then
            timer.Remove(growTimer)
            return
        end
        
        local elapsed = CurTime() - startTime
        local progress = math.min(elapsed / growDuration, 1)
        
        -- Courbe de croissance (ease-out)
        local easeProgress = 1 - math.pow(1 - progress, 3)
        
        -- Fait pousser la fleur du sol
        local currentPos = LerpVector(easeProgress, spawnPos, finalPos)
        ent:SetPos(currentPos)
        
        -- Fait grandir la taille progressivement
        local currentScale = Lerp(easeProgress, 0.1, 50)
        ent:SetModelScale(currentScale, 0)
        
        -- Rotation douce pendant la croissance
        local currentAng = Angle(spawnAng.p, spawnAng.y + (easeProgress * 180), spawnAng.r)
        ent:SetAngles(currentAng)
        
        -- Fin de l'animation
        if progress >= 1 then
            timer.Remove(growTimer)
            print("[MOKUTON] 🌸 Croissance terminée!")
            
            -- Applique les dégâts une fois la fleur complètement sortie
            ApplyFlowerDamage(ent, finalPos, caller)
        end
    end)

    -- Auto remove après 15 secondes
    timer.Simple(15, function()
        if IsValid(ent) then 
            ent:Remove() 
            print("[MOKUTON] Fleur supprimée")
        end
    end)
end

net.Receive("MokutonSpawn_fleur", function(_, caller)
    if not NA_Debloquee(caller, "mokuton_fleur") then return end   -- technique pas encore débloquée (F6)
    print("[MOKUTON] ========================================")
    print("[MOKUTON] 📨 SIGNAL REÇU!")
    print("[MOKUTON] ========================================")
    
    if not IsValid(caller) or not caller:IsPlayer() or not caller:Alive() then 
        print("[MOKUTON] ❌ Caller invalide")
        return 
    end

    print("[MOKUTON] Caller:", caller:Nick())

    -- Anti-spam
    caller.__mokutonNext = caller.__mokutonNext or 0
    if caller.__mokutonNext > CurTime() then 
        print("[MOKUTON] ⏱️ Cooldown actif")
        return 
    end
    caller.__mokutonNext = CurTime() + NA_Stat(caller, "mokuton_fleur", "recharge", cooldown)
    if NA_CD then NA_CD.Set(caller, "mokuton_fleur", NA_Stat(caller, "mokuton_fleur", "recharge", cooldown)) end -- recharge visible dans la barre

    SpawnFlowerAndDamage(caller)
end)