if SERVER then
    AddCSLuaFile()
    -- ✅ Setup networking
    util.AddNetworkString("kabutowari_PlayAttack")
    util.AddNetworkString("kabutowari_special")
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

SWEP.PrintName = "katbutowari"
SWEP.Author = "katbutowari"
SWEP.Category = "Naruto"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "melee"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapon/kabutowari/atg_kabutowari_hache.mdl"
SWEP.WorldModel = "models/weapon/kabutowari/atg_kabutowari_hache.mdl"


SWEP.CustomHandModel = "models/weapon/kabutowari/atg_kabutowari_hache.mdl"
SWEP.CustomScale = 0.8
SWEP.CustomRot = Angle(-90, 0, 0)
SWEP.CustomPos = Vector(3, 2, -15)

SWEP.CustomHandModelLeft = "models/weapon/kabutowari/atg_kabutowari_marteau.mdl"
SWEP.CustomScaleLeft = 0.8
SWEP.CustomRotLeft = Angle(90, 0, 0)
SWEP.CustomPosLeft = Vector(3, 1, -5)

SWEP.BackAccessoryId   = "kabutowari_dos"
SWEP.BackAccessoryMdl  = "models/weapon/kabutowari/atg_kabutowari_dos.mdl"
SWEP.BackBone          = "ValveBiped.Bip01_Spine4" -- si ton modèle l'a pas, mets Spine2
SWEP.BackPos           = Vector(-5, -7, -5)
SWEP.BackAng           = Angle(45, 0, 180)
SWEP.BackScale         = 0.8 -- ⚠️ doit être NUMBER (float)

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
    "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl02_2",
    "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl03a_0",
    "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw03u01",
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
-- =========================
-- ACCESSOIRE DOS (SERVER)
-- =========================
if SERVER then
    hook.Add("PlayerDeath", "kabutowari_dos_RemoveBackAccessory_OnDeath", function(victim)
        if not IsValid(victim) then return end
        if RemoveAccessory then
            RemoveAccessory(victim, "kabutowari_dos") -- ton BackAccessoryId
        end
    end)
end
function SWEP:_AddBackAccessory(ply)
    if not SERVER then return end
    if not IsValid(ply) then return end
    if ply:GetNWBool("IsInvisible", false) then return end

    -- TES fonctions globales
    if GiveAccessory then
        GiveAccessory(
            ply,
            self.BackAccessoryId,
            self.BackAccessoryMdl,
            self.BackBone,
            self.BackPos,
            self.BackAng,
            self.BackScale -- ✅ float
        )
    end
end

function SWEP:_RemoveBackAccessory(ply)
    if not SERVER then return end
    if not IsValid(ply) then return end

    if RemoveAccessory then
        RemoveAccessory(ply, self.BackAccessoryId)
    end
end

-- Quand on sort l'arme = pas sur le dos
function SWEP:Deploy()
    if SERVER then
        self:_RemoveBackAccessory(self:GetOwner())
    end
    return true
end

-- Quand on range = sur le dos
function SWEP:Holster()
    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) then
            -- petit timer pour laisser le switch se faire
            timer.Simple(0, function()
                if IsValid(self) and IsValid(ply) then
                    -- si il n'a PLUS cette arme active, on la met dans le dos
                    local active = ply:GetActiveWeapon()
                    if not IsValid(active) or active:GetClass() ~= self:GetClass() then
                        self:_AddBackAccessory(ply)
                    end
                end
            end)
        end
    end

    if CLIENT then
        if self.RemoveClientModels then self:RemoveClientModels() end
    end
    return true
end

-- Drop / remove = on la remet sur le dos si le joueur l'a encore
function SWEP:OnRemove()
    if CLIENT then
        if self.RemoveClientModels then self:RemoveClientModels() end
    end

    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) then
            timer.Simple(0, function()
                if IsValid(ply) and ply:HasWeapon(self:GetClass()) then
                    local active = ply:GetActiveWeapon()
                    if not IsValid(active) or active:GetClass() ~= self:GetClass() then
                        self:_AddBackAccessory(ply)
                    end
                else
                    -- si plus d'arme, on clean l'accessoire
                    if IsValid(ply) then self:_RemoveBackAccessory(ply) end
                end
            end)
        end
    end
end

-- Optionnel: si le joueur meurt, tu peux clean (sinon ton système EntityRemoved le fera côté client)
function SWEP:OwnerChanged()
    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) then
            self:_RemoveBackAccessory(ply)
        end
    end
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
    net.Start("kabutowari_special")
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
        net.Start("kabutowari_PlayAttack")
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

        local timerName = "ShibukiHitbox_" .. owner:EntIndex() .. "_" .. CurTime()

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
    net.Receive("kabutowari_PlayAttack", function()
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
    net.Receive("kabutowari_special", function()
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
    hook.Add("CalcMainActivity", "kabutowari_ForceIdleRunSeq", function(ply, vel)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "kabutowari" then return end
        if ply:InVehicle() then return end

        local speed2d = vel:Length2D()

        -- RUN
        if speed2d > 120 then
            local seq = ply:LookupSequence("phalanx_r_run")
            if seq and seq >= 0 then return ACT_MP_RUN, seq end
            return ACT_MP_RUN
        end

        -- WALK
        if speed2d > 10 then
            local seq = ply:LookupSequence("phalanx_r_run")
            if seq and seq >= 0 then return ACT_MP_WALK, seq end
            return ACT_MP_WALK
        end

        -- IDLE (même pendant attaque)
        local seq = ply:LookupSequence("idle_all_angry")
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


if CLIENT then
    -- =========================
    -- 2 MAINS (WorldModel)
    -- =========================
    function SWEP:CreateClientModels()
        if not IsValid(self.ClientModelR) then
            self.ClientModelR = ClientsideModel(self.CustomHandModel, RENDERGROUP_OPAQUE)
            if IsValid(self.ClientModelR) then
                self.ClientModelR:SetNoDraw(true)
                self.ClientModelR:SetModelScale(self.CustomScale or 1, 0)
            end
        end

        if not IsValid(self.ClientModelL) then
            self.ClientModelL = ClientsideModel(self.CustomHandModelLeft, RENDERGROUP_OPAQUE)
            if IsValid(self.ClientModelL) then
                self.ClientModelL:SetNoDraw(true)
                self.ClientModelL:SetModelScale(self.CustomScaleLeft or 1, 0)
            end
        end
    end

    local function DrawAttached(mdl, owner, boneName, posOff, rotOff)
        if not IsValid(mdl) or not IsValid(owner) then return end

        local bone = owner:LookupBone(boneName)
        if not bone then return end

        local pos, ang = owner:GetBonePosition(bone)
        if not pos or not ang then return end

        local p = pos
            + ang:Forward() * (posOff.x or 0)
            + ang:Right()   * (posOff.y or 0)
            + ang:Up()      * (posOff.z or 0)

        local a = Angle(ang)
        rotOff = rotOff or angle_zero
        a:RotateAroundAxis(a:Right(),   rotOff.p)
        a:RotateAroundAxis(a:Up(),      rotOff.y)
        a:RotateAroundAxis(a:Forward(), rotOff.r)

        mdl:SetPos(p)
        mdl:SetAngles(a)
        mdl:DrawModel()
    end

    function SWEP:DrawWorldModel()
        local owner = self:GetOwner()
        if not IsValid(owner) then
            self:DrawModel()
            return
        end

        self:CreateClientModels()

        -- Main droite (hache)
        DrawAttached(self.ClientModelR, owner,
            "ValveBiped.Bip01_R_Hand",
            self.CustomPos or vector_origin,
            self.CustomRot or angle_zero
        )

        -- Main gauche (marteau)
        DrawAttached(self.ClientModelL, owner,
            "ValveBiped.Bip01_L_Hand",
            self.CustomPosLeft or vector_origin,
            self.CustomRotLeft or angle_zero
        )
    end

    function SWEP:RemoveClientModel()
        if IsValid(self.ClientModelR) then self.ClientModelR:Remove() self.ClientModelR = nil end
        if IsValid(self.ClientModelL) then self.ClientModelL:Remove() self.ClientModelL = nil end
    end

    function SWEP:OnRemove()
        self:RemoveClientModel()
    end

    function SWEP:Holster()
        self:RemoveClientModel()
        return true
    end
end
