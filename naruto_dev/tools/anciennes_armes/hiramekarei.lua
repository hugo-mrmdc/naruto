if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("hiramekarei_PlayAttack")
    util.AddNetworkString("hiramekarei_special")

    game.AddParticles("particles/naruto_fw.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")
    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
    PrecacheParticleSystem("smoke_orugi2")
end

if CLIENT then
    game.AddParticles("particles/naruto_fw.pcf")
    game.AddParticles("particles/atg_orugi_particle.pcf")
    game.AddParticles("particles/julio.pcf")
    PrecacheParticleSystem("[2]_concasse_blast")
    PrecacheParticleSystem("smoke_orugi2")
end

SWEP.PrintName = "hiramekarei"
SWEP.Author = "hiramekarei"
SWEP.Category = "Naruto"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "melee"
SWEP.UseHands = true

SWEP.ViewModel  = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"
SWEP.WorldModel = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"

-- 2 mains (WorldModel custom)
SWEP.CustomHandModel     = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"
SWEP.CustomScale         = 0.8
SWEP.CustomRot           = Angle(-90, 0, 0)
SWEP.CustomPos           = Vector(4, 0, 0)

SWEP.CustomHandModelLeft = "models/weapon/hiramekarei/atg_hiramekarei_solo.mdl"
SWEP.CustomScaleLeft     = 0.8
SWEP.CustomRotLeft       = Angle(90, 0, 0)
SWEP.CustomPosLeft       = Vector(4, 0, 0)

-- Accessoire dos (réseau)
SWEP.BackAccessoryId   = "hiramekarei_back"
SWEP.BackAccessoryMdl  = "models/weapon/hiramekarei/atg_hiramekarei_dos.mdl"
SWEP.BackBone          = "ValveBiped.Bip01_Spine4" -- si ton modèle l'a pas, mets Spine2
SWEP.BackPos           = Vector(-15, -7, 0)
SWEP.BackAng           = Angle(-135, 0, 180)
SWEP.BackScale         = 0.8 -- ⚠️ doit être NUMBER (float)

SWEP.Primary.Damage = 100
SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.8
SWEP.Primary.Range = 80
SWEP.Primary.Sound = Sound("fuma/swing1.wav")

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ComboAnims = {
    "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw03",
    "oldjimmy_tengen_a_p0013_v00_c00_atkcmbw04",
    "oldjimmy_tanjiro_a_p0001_v00_c00_atkskl02_2",
}

SWEP.ComboResetTime = 2.0
SWEP.ComboAnimDurations = { 1, 0.7, 1 }

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.ComboIndex = 0
    self.LastAttackTime = 0
    self.IsAttacking = false
    self.FirstHitUsed = false
end
if SERVER then
    hook.Add("PlayerDeath", "hiramekarei_RemoveBackAccessory_OnDeath", function(victim)
        if not IsValid(victim) then return end
        if RemoveAccessory then
            RemoveAccessory(victim, "hiramekarei_back") -- ton BackAccessoryId
        end
    end)
end

-- =========================
-- ACCESSOIRE DOS (SERVER)
-- =========================
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

-- =========================
-- TON CODE: SecondaryAttack
-- =========================
function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if self.IsAttacking then return end

    self.NextShurikenThrow = self.NextShurikenThrow or 0
    if CurTime() < self.NextShurikenThrow then
        if SERVER then
            local remaining = math.ceil(self.NextShurikenThrow - CurTime())
            owner:ChatPrint(self.PrintName .. " disponible dans " .. remaining .. " secondes")
        end
        return
    end

    if CLIENT then return end

    self.IsAttacking = true
    timer.Simple(1.5, function()
        if IsValid(self) then self.IsAttacking = false end
    end)

    self.NextShurikenThrow = CurTime() + 5
    self:SetNextSecondaryFire(CurTime() + 1.5)

    net.Start("hiramekarei_special")
        net.WriteEntity(owner)
    net.Broadcast()

    timer.Simple(0.3, function()
        if not IsValid(owner) or not owner:Alive() then return end
        local pos = owner:GetShootPos() + owner:GetAimVector() * 80

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
        end

        local radius, damage = 150, 60
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
                local distance = ent:GetPos():Distance(pos)
                local falloff = 1 - math.Clamp(distance / radius, 0, 1)
                local finalDamage = damage * falloff

                local dmg = DamageInfo()
                dmg:SetDamage(finalDamage)
                dmg:SetAttacker(owner)
                dmg:SetInflictor(IsValid(self) and self or owner)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)

                if ent:IsPlayer() then
                    local direction = (ent:GetPos() - pos):GetNormalized()
                    ent:SetVelocity(direction * (300 * falloff) + Vector(0, 0, 200))
                end
            end
        end

        debugoverlay.Sphere(pos, radius, 1, Color(255, 0, 0, 50), true)
    end)

    timer.Simple(0.6, function()
        if not IsValid(owner) or not owner:Alive() then return end
        local pos = owner:GetShootPos() + owner:GetAimVector() * 140

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
        end

        local radius, damage = 150, 60
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
                local distance = ent:GetPos():Distance(pos)
                local falloff = 1 - math.Clamp(distance / radius, 0, 1)
                local finalDamage = damage * falloff

                local dmg = DamageInfo()
                dmg:SetDamage(finalDamage)
                dmg:SetAttacker(owner)
                dmg:SetInflictor(IsValid(self) and self or owner)
                dmg:SetDamageType(DMG_BLAST)
                dmg:SetDamagePosition(pos)
                ent:TakeDamageInfo(dmg)

                if ent:IsPlayer() then
                    local direction = (ent:GetPos() - pos):GetNormalized()
                    ent:SetVelocity(direction * (300 * falloff) + Vector(0, 0, 200))
                end
            end
        end

        debugoverlay.Sphere(pos, radius, 1, Color(255, 0, 0, 50), true)
    end)
end

-- =========================
-- TON CODE: PrimaryAttack
-- =========================
function SWEP:PrimaryAttack()
    if self.IsAttacking then return end
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self.ComboIndex = self.ComboIndex or 0
    self.LastAttackTime = self.LastAttackTime or 0
    self.FirstHitUsed = self.FirstHitUsed or false

    if CurTime() - self.LastAttackTime > self.ComboResetTime then
        self.ComboIndex = 0
        self.FirstHitUsed = false
    end

    self.ComboIndex = self.ComboIndex + 1
    if self.ComboIndex > #self.ComboAnims then
        self.ComboIndex = 1
        self.FirstHitUsed = false
    end

    self.LastAttackTime = CurTime()

    local animDuration = self.ComboAnimDurations[self.ComboIndex] or 1.0
    self:SetNextPrimaryFire(CurTime() + animDuration)

    self.IsAttacking = true
    timer.Simple(animDuration, function()
        if IsValid(self) then self.IsAttacking = false end
    end)

    local animName = self.ComboAnims[self.ComboIndex]
    if SERVER then
        net.Start("hiramekarei_PlayAttack")
            net.WriteString(animName)
            net.WriteEntity(owner)
            net.WriteFloat(animDuration)
        net.Broadcast()
    end

    if self.ComboIndex == 1 and not self.FirstHitUsed then
        self:EmitSound(self.Primary.Sound)
        timer.Simple(0.15, function() if IsValid(self) then self:EmitSound(self.Primary.Sound) end end)
        timer.Simple(0.3,  function() if IsValid(self) then self:EmitSound(self.Primary.Sound) end end)
        timer.Simple(0.45, function() if IsValid(self) then self:EmitSound(self.Primary.Sound) end end)
        self.FirstHitUsed = true
    else
        self:EmitSound(self.Primary.Sound)
    end

    if SERVER then
        local hitEntities = {}
        local startTime = CurTime()
        local hitboxDuration = 0.6

        local maxHitsPerEntity = 1
        local hitDelay = 0

        if self.ComboIndex == 1 and self.FirstHitUsed then
            maxHitsPerEntity = 4
            hitDelay = 0.15
        end

        local timerName = "ShibukiHitbox_" .. owner:EntIndex() .. "_" .. CurTime()

        timer.Create(timerName, 0, 0, function()
            if not IsValid(self) or not IsValid(owner) then timer.Remove(timerName) return end
            if CurTime() - startTime > hitboxDuration then timer.Remove(timerName) return end

            local startPos = owner:GetShootPos()
            local endPos = startPos + owner:GetAimVector() * self.Primary.Range
            local mins = Vector(-40, -35, -40)
            local maxs = Vector(40, 35, 40)

            local tr = util.TraceHull({
                start  = startPos,
                endpos = endPos,
                filter = owner,
                mins   = mins,
                maxs   = maxs
            })

            if tr.Hit and IsValid(tr.Entity) and (tr.Entity:IsPlayer() or tr.Entity:IsNPC()) then
                hitEntities[tr.Entity] = hitEntities[tr.Entity] or { count = 0, lastHitTime = 0 }
                local data = hitEntities[tr.Entity]

                if data.count < maxHitsPerEntity and (CurTime() - data.lastHitTime) >= hitDelay then
                    data.count = data.count + 1
                    data.lastHitTime = CurTime()

                    local dmg = DamageInfo()
                    dmg:SetDamage(self.Primary.Damage)
                    dmg:SetAttacker(owner)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_SLASH)
                    tr.Entity:TakeDamageInfo(dmg)
                end
            end
        end)
    end
end

-- =========================
-- CLIENT : anims + worldmodel 2 mains (UNIQUE)
-- =========================
if CLIENT then
    net.Receive("hiramekarei_PlayAttack", function()
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
            if IsValid(ply) then ply._FumaSwordAttacking = false end
        end)
    end)

    net.Receive("hiramekarei_special", function()
        local ply = net.ReadEntity()
        if not IsValid(ply) then return end

        local seq = ply:LookupSequence("nrp_sword_swordturnkickupperslash")
        ply._FumaSwordThrowing = true

        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        end

        timer.Simple(1.5, function()
            if IsValid(ply) then ply._FumaSwordThrowing = false end
        end)
    end)

    -- Animations idle/run custom
    hook.Remove("CalcMainActivity", "hiramekarei_ForceIdleRunSeq")
    hook.Add("CalcMainActivity", "hiramekarei_ForceIdleRunSeq", function(ply, vel)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "hiramekarei" then return end
        if ply:InVehicle() then return end

        local speed2d = vel:Length2D()

        if speed2d > 300 then
            local seq = ply:LookupSequence("oldjimmy_akaza_a_p1012_v00_c90_baserun01_1")
            if seq and seq >= 0 then
                ply:SetPlaybackRate(0.1)
                return ACT_MP_RUN, seq
            end
            ply:SetPlaybackRate(0.1)
            return ACT_MP_RUN
        end

        if speed2d > 120 then
           local seq = ply:LookupSequence("menu_walk")
            --local seq = ply:LookupSequence("tambour_a_p1006_v00_c00_basewalkf01_1")
            if seq and seq >= 0 then return ACT_MP_WALK, seq end
            return ACT_MP_WALK
        end

        local seq = ply:LookupSequence("idle_all_angry")
        if seq and seq >= 0 then
            return ACT_MP_STAND_IDLE, seq
        end
    end)

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

    function SWEP:RemoveClientModels()
        if IsValid(self.ClientModelR) then self.ClientModelR:Remove() self.ClientModelR = nil end
        if IsValid(self.ClientModelL) then self.ClientModelL:Remove() self.ClientModelL = nil end
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

        DrawAttached(self.ClientModelR, owner,
            "ValveBiped.Bip01_R_Hand",
            self.CustomPos or vector_origin,
            self.CustomRot or angle_zero
        )

        DrawAttached(self.ClientModelL, owner,
            "ValveBiped.Bip01_L_Hand",
            self.CustomPosLeft or vector_origin,
            self.CustomRotLeft or angle_zero
        )
    end
end
