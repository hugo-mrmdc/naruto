if SERVER then
    AddCSLuaFile()

    -- ✅ Setup networking
    util.AddNetworkString("FumaSword_PlayAttack")
    util.AddNetworkString("FumaSword_PlayThrow")
end

SWEP.PrintName = "Fuma Sword"
SWEP.Author = "fuma"
SWEP.Category = "Naruto"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "melee"

SWEP.UseHands = true
SWEP.ViewModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"
SWEP.WorldModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"

SWEP.CustomHandModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"
SWEP.CustomScale = 0.6
SWEP.CustomRot = Angle(45, 0, 80)
SWEP.CustomPos = Vector(5, 2, -3)

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
    "ryoku_r_right_t1",
    "ryoku_r_left_t2",
    "ryoku_r_right_t2",
}

SWEP.ComboResetTime = 2.0 -- Temps avant reset du combo

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self.ComboIndex = 0
    self.LastAttackTime = 0
end

-- ✅ Clic droit: Lance le shuriken (cooldown 10 sec)
function SWEP:SecondaryAttack()
    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    -- ✅ Vérifie le cooldown de 10 secondes
    self.NextShurikenThrow = self.NextShurikenThrow or 0
    if CurTime() < self.NextShurikenThrow then
        if SERVER then
            -- Affiche le temps restant
            local remaining = math.ceil(self.NextShurikenThrow - CurTime())
            owner:ChatPrint("Shuriken disponible dans " .. remaining .. " secondes")
        end
        return
    end

    if CLIENT then return end

    -- ✅ Active le cooldown de 10 secondes
    self.NextShurikenThrow = CurTime() + 1
    self:SetNextSecondaryFire(CurTime() + 1)

    -- ✅ Joue l'animation de lancer
    net.Start("FumaSword_PlayThrow")
    net.WriteEntity(owner)
    net.Broadcast()

    print("[SERVER] Animation throw envoyée pour", owner:Nick())

    print("[SERVER] Animation de lancer envoyée pour", owner:Nick())

    -- Spawn le shuriken


    -- Son de lancer
    --self:EmitSound("weapons/knife/knife_slash1.wav")
    timer.Simple(0.4, function()
        if IsValid(self) then self:EmitSound("fuma/throw_1.wav") end
    end)
    timer.Simple(0.6, function()
        if not IsValid(owner) or not owner:Alive() then return end
        local proj = ents.Create("prop_dynamic")
        if not IsValid(proj) then return end
       
        proj:SetModel("models/fumaSpell/orga_props_shuriken.mdl")
        proj:SetPos(owner:GetShootPos() + owner:GetAimVector() * 30)
        proj:SetAngles(owner:EyeAngles())
        proj:Spawn()
        proj:SetOwner(owner)
        proj:SetModelScale(1, 0)

        local dir = owner:GetAimVector():GetNormalized()
        local speed = 40
        local tname = "fumaThrow_" .. proj:EntIndex()
        timer.Create(tname, 0, 0, function()
            if not IsValid(proj) then
                timer.Remove(tname)
                return
            end

            local HIT_SIZE = Vector(50, 12, 6)
            local startPos = proj:GetPos()
            local nextPos  = startPos + dir * speed
            local ang      = dir:Angle()

            proj:SetAngles(ang)
            proj:SetSolid(SOLID_BBOX)
            proj:SetMoveType(MOVETYPE_NONE)
            proj:SetCollisionBounds(-HIT_SIZE, HIT_SIZE)

            local tr = util.TraceEntity({
                start  = startPos,
                endpos = nextPos,
                mask   = MASK_SHOT_HULL,
                filter = function(ent)
                    if ent == owner then return false end
                    if ent == proj then return false end
                    return true
                end
            }, proj)

            if tr.Hit then
                local hitEnt = tr.Entity

                if tr.StartSolid or tr.AllSolid then
                    proj:SetPos(nextPos)
                    return
                end

                local wep = IsValid(owner) and owner:GetActiveWeapon() or NULL
                if hitEnt == owner or (IsValid(wep) and hitEnt == wep) then
                    proj:SetPos(nextPos)
                    return
                end

                -- Dégâts sur joueur/NPC
                if IsValid(hitEnt) and hitEnt ~= owner and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
                    local pos = proj:GetPos()
                    local radius = 200
                    local dmgAmt = 60

                    for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
                        if IsValid(ent) and ent ~= owner and (ent:IsPlayer() or ent:IsNPC()) then
                            local d = ent:GetPos():Distance(pos)
                            local scale = 1 - math.Clamp(d / radius, 0, 1)

                            local dmg = DamageInfo()
                            dmg:SetDamage(dmgAmt * scale)
                            dmg:SetAttacker(owner)
                            dmg:SetInflictor(proj)
                            dmg:SetDamageType(DMG_BLAST)
                            dmg:SetDamagePosition(pos)

                            ent:TakeDamageInfo(dmg)
                        end
                    end

                    SafeRemoveEntity(proj)
                    timer.Remove(tname)
                    return
                end

                -- Collision avec le monde
                SafeRemoveEntity(proj)
                timer.Remove(tname)
                return
            end

            proj:SetPos(nextPos)
        end)

        -- Auto-destruction après 10 secondes
        timer.Simple(10, function()
            if IsValid(proj) then
                SafeRemoveEntity(proj)
                if timer.Exists(tname) then
                    timer.Remove(tname)
                end
            end
        end)
    end)
end

if SERVER then
    AddCSLuaFile()

    -- ✅ Setup networking
    util.AddNetworkString("FumaSword_PlayAttack")
    util.AddNetworkString("FumaSword_PlayThrow")
end

SWEP.PrintName = "Fuma Sword"
SWEP.Author = "fuma"
SWEP.Category = "Naruto"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.HoldType = "melee"

SWEP.UseHands = true
SWEP.ViewModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"
SWEP.WorldModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"

SWEP.CustomHandModel = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"
SWEP.CustomScale = 0.6
SWEP.CustomRot = Angle(45, 0, 80)
SWEP.CustomPos = Vector(5, 2, -3)

SWEP.Primary.Automatic = true
SWEP.Primary.Delay = 0.8
SWEP.Primary.Damage = 40
SWEP.Primary.Range = 80
SWEP.Primary.Sound = Sound("fuma/swing1.wav")

SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.ComboAnimDurations = {
    1,   -- nrp_sword_slashhorizon
    1.1, -- nrp_sword_turnslashingshoulder
    1.3, -- nrp_sword_slashing
}
SWEP.DrawAmmo = false

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
        net.Start("FumaSword_PlayAttack")
        net.WriteString(animName)
        net.WriteEntity(owner)
        net.WriteFloat(animDuration)
        net.Broadcast()
    end

    self:EmitSound(self.Primary.Sound)

    -- ✅ Hitbox continue qui se met à jour pendant toute l'attaque
    if SERVER then
        local hitEntities = {} -- Table pour éviter de frapper plusieurs fois la même entité
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
-- CLIENT - Modèle custom
-- ========================
-- ========================
-- CLIENT - Modèle custom
-- ========================
if CLIENT then
    -- ✅ Networking pour les animations d'attaque
    net.Receive("FumaSword_PlayAttack", function()
        local animName = net.ReadString()
        local ply = net.ReadEntity()

        if not IsValid(ply) then return end

        local seq = ply:LookupSequence(animName)
        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        end

        -- Marque qu'une attaque est en cours
        ply._FumaSwordAttacking = true
        timer.Simple(0.8, function()
            if IsValid(ply) then
                ply._FumaSwordAttacking = false
            end
        end)
    end)

    -- ✅ Networking pour l'animation de lancer
    net.Receive("FumaSword_PlayThrow", function()
        local ply = net.ReadEntity()

        if not IsValid(ply) then return end

        -- ✅ Debug: vérifie si l'anim existe
        local seq = ply:LookupSequence("nrp_ninjutsu_defend_d35nj2_throw")
        print("[CLIENT] Animation throw seq:", seq)

        -- ✅ Bloque l'idle pendant le lancer
        --ply._FumaSwordThrowing = true

        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_ATTACK_AND_RELOAD, seq, 0, true)
        else
            print("[CLIENT] ERREUR: Animation introuvable!")
        end

        -- Débloque après 1.5 secondes
        timer.Simple(5, function()
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
    hook.Add("CalcMainActivity", "FumaSword_ForceIdleRunSeq", function(ply, vel)
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) or wep:GetClass() ~= "shuriken_fuma" then return end
        if ply:InVehicle() then return end

        -- ✅ Bloque l'animation de base pendant l'attaque OU le lancer
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

        local seq = ply:LookupSequence("ryoku_r_idle")
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
    local WEAPON_CLASS = "shuriken_fuma"
    local MODEL = "models/fumaSpell/acc/foc_arme_shuriken_fuma.mdl"

    local offsetPos = Vector(-6, 2, 0)
    local offsetAng = Angle(45, 30, 90)

    local function RemoveBack(ply)
        if IsValid(ply._ShurikenCS) then
            ply._ShurikenCS:Remove()
            ply._ShurikenCS = nil
        end
    end

    hook.Add("PostPlayerDraw", "ShurikenBack_Draw_FixedToBone", function(ply)
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

        if not IsValid(ply._ShurikenCS) then
            ply._ShurikenCS = ClientsideModel(MODEL, RENDERGROUP_TRANSLUCENT)
            if not IsValid(ply._ShurikenCS) then return end
            ply._ShurikenCS:SetNoDraw(true)
            ply._ShurikenCS:SetModelScale(0.5, 0)
        end

        local mdl = ply._ShurikenCS
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

    hook.Add("EntityRemoved", "ShurikenBack_Cleanup", function(ent)
        if ent:IsPlayer() then
            RemoveBack(ent)
        end
    end)
end
