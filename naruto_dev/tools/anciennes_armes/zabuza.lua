if SERVER then
    AddCSLuaFile()
    -- ✅ Setup networking
    util.AddNetworkString("zabuza_PlayAttack")
    util.AddNetworkString("zabuza_special")
    game.AddParticles("particles/naruto_fw.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")
    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
    PrecacheParticleSystem("smoke_orugi2")
end

-- ✅ CLIENT aussi a besoin des particules
if CLIENT then
    game.AddParticles("particles/naruto_fw.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")
    PrecacheParticleSystem("smoke_orugi2")
    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
end

SWEP.PrintName = "zabuza"
SWEP.Author = "zabuza"
SWEP.Category = "Naruto"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "melee"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapon/kubikiribocho/kubikiribocho.mdl"
SWEP.WorldModel = "models/weapon/kubikiribocho/kubikiribocho.mdl"

SWEP.CustomHandModel = "models/weapon/kubikiribocho/kubikiribocho.mdl"
SWEP.CustomScale = 0.5
SWEP.CustomRot = Angle(100, 160, 0)
SWEP.CustomPos = Vector(3, 2, -3)

SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.8
SWEP.Primary.Damage = 40
SWEP.Primary.Range = 80
SWEP.Primary.Sound = Sound("fuma/swing1.wav")

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

-- ✅ Liste des animations de combo
SWEP.ComboAnims = {
    "nrp_sword_slashhorizon",
    "nrp_sword_turnslashingshoulder",
    "nrp_sword_slashing",
}

SWEP.ComboResetTime = 2.0 -- Temps avant reset du combo

-- ✅ Durée de chaque animation de combo (en secondes)
SWEP.ComboAnimDurations = {
    1,   -- nrp_sword_slashhorizon
    1.1, -- nrp_sword_turnslashingshoulder
    1.3, -- nrp_sword_slashing
}

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.ComboIndex = 0
    self.LastAttackTime = 0
    self.IsAttacking = false
end

function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- ✅ Bloque si une attaque est en cours
    if self.IsAttacking then return end

    -- ✅ Vérifie le cooldown
    self.NextShurikenThrow = self.NextShurikenThrow or 0
    if CurTime() < self.NextShurikenThrow then
        if SERVER then
            local remaining = math.ceil(self.NextShurikenThrow - CurTime())
            owner:ChatPrint(self.PrintName .. " disponible dans " .. remaining .. " secondes")
        end
        return
    end

    if CLIENT then return end

    -- ✅ Bloque les attaques pendant le lancer
    self.IsAttacking = true
    timer.Simple(1.5, function()
        if IsValid(self) then
            self.IsAttacking = false
        end
    end)

    -- ✅ Active le cooldown
    self.NextShurikenThrow = CurTime() + 5
    self:SetNextSecondaryFire(CurTime() + 1.5)

    -- ✅ Joue l'animation de lancer
    net.Start("zabuza_special")
    net.WriteEntity(owner)
    net.Broadcast()

    print("[SERVER] Animation throw envoyée pour", owner:Nick())

    -- ✅ Première explosion à 80 unités
    timer.Simple(0.3, function()
        if not IsValid(owner) or not owner:Alive() then return end

        local pos = owner:GetShootPos() + owner:GetAimVector() * 80

        -- Crée l'effet de particules
        local particle = ents.Create("info_particle_system")
        if IsValid(particle) then
            particle:SetKeyValue("effect_name", "[2]_concasse_blast")
            particle:SetPos(pos)
            particle:SetAngles(owner:EyeAngles())
            particle:Spawn()
            particle:Activate()
            particle:Fire("Start")
            if IsValid(self) then self:EmitSound("bakuton/solve_bakuton_explosion.wav") end

            timer.Simple(3, function()
                if IsValid(particle) then
                    particle:Fire("Stop")
                    SafeRemoveEntity(particle)
                end
            end)

            print("[SERVER] Particule [2]_concasse_blast spawn devant", owner:Nick(), "à", pos)
        end

        -- ✅ HITBOX ET DÉGÂTS - Rayon 150 unités
        local radius = 150
        local damage = 60

        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
                -- Calcul des dégâts selon la distance
                local distance = ent:GetPos():Distance(pos)
                local damageFalloff = 1 - math.Clamp(distance / radius, 0, 1)
                local finalDamage = damage * damageFalloff

                -- Applique les dégâts
                local dmg = DamageInfo()
                dmg:SetDamage(finalDamage)
                dmg:SetAttacker(owner)
                dmg:SetInflictor(IsValid(self) and self or owner)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)

                -- Force de projection (knockback)
                if ent:IsPlayer() then
                    local direction = (ent:GetPos() - pos):GetNormalized()
                    local force = 300 * damageFalloff
                    ent:SetVelocity(direction * force + Vector(0, 0, 200))
                end

                print("[SERVER] Dégâts infligés:", finalDamage, "à", (ent:IsPlayer() and ent:Nick() or ent:GetClass()))
            end
        end

        -- ✅ DEBUG VISUEL (hitbox rouge)
        debugoverlay.Sphere(pos, radius, 1, Color(255, 0, 0, 50), true)
    end)

    -- ✅ Deuxième explosion à 140 unités
    timer.Simple(0.6, function()
        if not IsValid(owner) or not owner:Alive() then return end

        local pos = owner:GetShootPos() + owner:GetAimVector() * 140

        -- Crée l'effet de particules
        local particle = ents.Create("info_particle_system")
        if IsValid(particle) then
            particle:SetKeyValue("effect_name", "[2]_concasse_blast")
            particle:SetPos(pos)
            particle:SetAngles(owner:EyeAngles())
            particle:Spawn()
            particle:Activate()
            particle:Fire("Start")
            if IsValid(self) then self:EmitSound("bakuton/solve_bakuton_explosion.wav") end

            timer.Simple(3, function()
                if IsValid(particle) then
                    particle:Fire("Stop")
                    SafeRemoveEntity(particle)
                end
            end)

            print("[SERVER] Particule [2]_concasse_blast spawn devant", owner:Nick(), "à", pos)
        end

        -- ✅ HITBOX ET DÉGÂTS - Rayon 150 unités
        local radius = 150
        local damage = 60

        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
                -- Calcul des dégâts selon la distance
                local distance = ent:GetPos():Distance(pos)
                local damageFalloff = 1 - math.Clamp(distance / radius, 0, 1)
                local finalDamage = damage * damageFalloff

                -- Applique les dégâts
                local dmg = DamageInfo()
                dmg:SetDamage(finalDamage)
                dmg:SetAttacker(owner)
                dmg:SetInflictor(IsValid(self) and self or owner)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)

                -- Force de projection (knockback)
                if ent:IsPlayer() then
                    local direction = (ent:GetPos() - pos):GetNormalized()
                    local force = 300 * damageFalloff
                    ent:SetVelocity(direction * force + Vector(0, 0, 200))
                end

                print("[SERVER] Dégâts infligés:", finalDamage, "à", (ent:IsPlayer() and ent:Nick() or ent:GetClass()))
            end
        end

        -- ✅ DEBUG VISUEL (hitbox rouge)
        debugoverlay.Sphere(pos, radius, 1, Color(255, 0, 0, 50), true)
    end)
end

function SWEP:PrimaryAttack()
    -- ✅ Bloque si une attaque est déjà en cours
    if self.IsAttacking then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- ✅ Initialisation
    self.ComboIndex = self.ComboIndex or 0
    self.LastAttackTime = self.LastAttackTime or 0

    -- ✅ Gestion du système de combo
    if CurTime() - self.LastAttackTime > self.ComboResetTime then
        self.ComboIndex = 0
    end

    self.ComboIndex = self.ComboIndex + 1
    if self.ComboIndex > #self.ComboAnims then
        self.ComboIndex = 1
    end

    self.LastAttackTime = CurTime()

    -- ✅ Récupère la durée de l'animation actuelle
    local animDuration = self.ComboAnimDurations[self.ComboIndex] or 1.0

    -- ✅ Définit le délai avant la prochaine attaque
    self:SetNextPrimaryFire(CurTime() + animDuration)

    -- ✅ Marque qu'une attaque est en cours
    self.IsAttacking = true

    -- ✅ Débloque après la durée exacte de l'animation
    timer.Simple(animDuration, function()
        if IsValid(self) then
            self.IsAttacking = false
        end
    end)

    -- ✅ Joue l'animation du combo actuel
    local animName = self.ComboAnims[self.ComboIndex]

    -- Envoie l'info aux clients
    if SERVER then
        net.Start("zabuza_PlayAttack")
        net.WriteString(animName)
        net.WriteEntity(owner)
        net.WriteFloat(animDuration)
        net.Broadcast()
    end

    self:EmitSound(self.Primary.Sound)

    -- ✅ Hitbox continue qui se met à jour pendant toute l'attaque
    if SERVER then
        local hitEntities = {}     -- Table pour éviter de frapper plusieurs fois la même entité
        local startTime = CurTime()
        local hitboxDuration = 0.6 -- Durée pendant laquelle la hitbox est active

        local timerName = "zabuzaHitbox_" .. owner:EntIndex() .. "_" .. CurTime()

        timer.Create(timerName, 0, 0, function()
            if not IsValid(self) or not IsValid(owner) then
                timer.Remove(timerName)
                return
            end

            -- Arrête la hitbox après la durée définie
            if CurTime() - startTime > hitboxDuration then
                timer.Remove(timerName)
                return
            end

            local startPos = owner:GetShootPos()
            local endPos = startPos + owner:GetAimVector() * self.Primary.Range
            local mins = Vector(-15, -35, -40)
            local maxs = Vector(15, 35, 40)

            local tr = util.TraceHull({
                start  = startPos,
                endpos = endPos,
                filter = owner,
                mins   = mins,
                maxs   = maxs
            })

            -- ✅ DEBUG VISUEL
            debugoverlay.SweptBox(startPos, endPos, mins, maxs, angle_zero, 0.03, Color(0, 255, 0, 100))
            debugoverlay.Line(startPos, endPos, 0.03, Color(255, 0, 0), true)

            if tr.Hit then
                debugoverlay.Cross(tr.HitPos, 15, 0.03, Color(255, 0, 0), true)

                if IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then
                    -- Vérifie si l'entité n'a pas déjà été touchée dans cette attaque
                    if not hitEntities[tr.Entity] then
                        hitEntities[tr.Entity] = true

                        debugoverlay.Text(tr.HitPos + Vector(0, 0, 10), tostring(tr.Entity) .. " - HIT!", 0.5)

                        local dmg = DamageInfo()
                        dmg:SetDamage(self.Primary.Damage)
                        dmg:SetAttacker(owner)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_SLASH)
                        tr.Entity:TakeDamageInfo(dmg)

                        print("[SERVER] Hit détecté sur:", (tr.Entity:IsPlayer() and tr.Entity:Nick() or tr.Entity:GetClass()))
                    end
                end
            else
                debugoverlay.Cross(endPos, 10, 0.03, Color(0, 255, 255), true)
            end
        end)
    end
end

-- ========================
-- CLIENT
-- ========================
if CLIENT then
    -- ✅ Networking pour les animations d'attaque
    net.Receive("zabuza_PlayAttack", function()
        local animName = net.ReadString()
        local ply = net.ReadEntity()
        local animDuration = net.ReadFloat()

        if not IsValid(ply) then return end

        local seq = ply:LookupSequence(animName)
        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        end

        ply._FumaSwordAttacking = true
        timer.Simple(animDuration, function()
            if IsValid(ply) then
                ply._FumaSwordAttacking = false
            end
        end)
    end)

    -- ✅ Networking pour l'animation de lancer
    net.Receive("zabuza_special", function()
        local ply = net.ReadEntity()

        if not IsValid(ply) then return end

        local seq = ply:LookupSequence("nrp_sword_swordturnkickupperslash")
        print("[CLIENT] Animation throw seq:", seq)

        ply._FumaSwordThrowing = true

        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        else
            print("[CLIENT] ERREUR: Animation introuvable!")
        end

        timer.Simple(1.5, function()
            if IsValid(ply) then
                ply._FumaSwordThrowing = false
            end
        end)
    end)

    function SWEP:CreateClientModel()
        if IsValid(self.ClientModel) then return end

        self.ClientModel = ClientsideModel(self.CustomHandModel, RENDERGROUP_OPAQUE)
        if IsValid(self.ClientModel) then
            self.ClientModel:SetNoDraw(true)
            self.ClientModel:SetModelScale(self.CustomScale or 1, 0)
        end
    end

    -- ✅ Animations idle/run custom
    hook.Add("CalcMainActivity", "zabuza_ForceIdleRunSeq", function(ply, vel)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "zabuza" then return end
        if ply:InVehicle() then return end

        if ply._FumaSwordAttacking or ply._FumaSwordThrowing then
            return
        end

        local speed2d = vel:Length2D()

        if speed2d > 120 then
            local seq = ply:LookupSequence("ryoku_r_run")
            if seq and seq >= 0 then
                return ACT_MP_RUN, seq
            end
            return
        end

        if speed2d > 10 then
            return
        end

        local seq = ply:LookupSequence("ryoku_h_idle")
        if seq and seq >= 0 then
            return ACT_MP_STAND_IDLE, seq
        end
    end)

    function SWEP:RemoveClientModel()
        if IsValid(self.ClientModel) then
            self.ClientModel:Remove()
            self.ClientModel = nil
        end
    end

    function SWEP:OnRemove()
        self:RemoveClientModel()
    end

    function SWEP:Holster()
        self:RemoveClientModel()
        return true
    end

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        self:CreateClientModel()
        if not IsValid(self.ClientModel) then return end

        local bone = owner:LookupBone("ValveBiped.Bip01_R_Hand")
        if not bone then return end

        local pos, handAng = owner:GetBonePosition(bone)
        if not pos or not handAng then return end

        local p = pos
            + handAng:Forward() * (self.CustomPos.x or 0)
            + handAng:Right() * (self.CustomPos.y or 0)
            + handAng:Up() * (self.CustomPos.z or 0)

        local a = Angle(handAng)
        local r = self.CustomRot or Angle(0, 0, 0)
        a:RotateAroundAxis(a:Right(), r.p)
        a:RotateAroundAxis(a:Up(), r.y)
        a:RotateAroundAxis(a:Forward(), r.r)

        self.ClientModel:SetPos(p)
        self.ClientModel:SetAngles(a)
        self.ClientModel:DrawModel()
    end
end

-- ========================
-- CLIENT - Modèle dans le dos
-- ========================
if CLIENT then
    local WEAPON_CLASS = "zabuza"
    local MODEL = "models/weapon/kubikiribocho/kubikiribocho.mdl"

    local offsetPos = Vector(10, 14, 10)
    local offsetAng = Angle(160, 35, 10)

    local function RemoveBack(ply)
        if IsValid(ply._ZabuzaBackCS) then
            ply._ZabuzaBackCS:Remove()
            ply._ZabuzaBackCS = nil
        end
    end

    hook.Add("PostPlayerDraw", "kubikiribocho_Draw_FixedToBone", function(ply)
        if not IsValid(ply) then return end
        if not ply:Alive() then
            RemoveBack(ply)
            return
        end

        if ply:GetNWBool("IsInvisible", false) then
            RemoveBack(ply)
            return
        end

        if not ply:HasWeapon(WEAPON_CLASS) then
            RemoveBack(ply)
            return
        end

        local active = ply:GetActiveWeapon()
        if IsValid(active) and active:GetClass() == WEAPON_CLASS then
            RemoveBack(ply)
            return
        end

        if not IsValid(ply._ZabuzaBackCS) then
            ply._ZabuzaBackCS = ClientsideModel(MODEL, RENDERGROUP_TRANSLUCENT)
            if not IsValid(ply._ZabuzaBackCS) then return end
            ply._ZabuzaBackCS:SetNoDraw(true)
            ply._ZabuzaBackCS:SetModelScale(0.5, 0)
        end

        local mdl = ply._ZabuzaBackCS
        if not IsValid(mdl) then return end

        ply:SetupBones()

        local boneId =
            ply:LookupBone("ValveBiped.Bip01_UpperChest") or
            ply:LookupBone("ValveBiped.Bip01_Neck1") or
            ply:LookupBone("ValveBiped.Bip01_Spine4") or
            ply:LookupBone("ValveBiped.Bip01_Spine2")
        if not boneId then return end

        local m = ply:GetBoneMatrix(boneId)
        if not m then return end

        local pos, ang = LocalToWorld(offsetPos, offsetAng, m:GetTranslation(), m:GetAngles())

        mdl:SetPos(pos)
        mdl:SetAngles(ang)
        mdl:DrawModel()
    end)

    hook.Add("EntityRemoved", "kubikiribocho_Cleanup", function(ent)
        if ent:IsPlayer() then
            RemoveBack(ent)
        end
    end)
end
