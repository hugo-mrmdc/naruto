--[[
    Arme : mains ninja (taijutsu)
    Clic gauche : attaque légère (combo de 3) - Clic droit : attaque lourde (armée)
    L'arme ne gère que l'animation/prédiction ; les dégâts, cooldowns et coûts sont
    entièrement décidés par NRP.Combat côté serveur.
]]

AddCSLuaFile()

SWEP.PrintName = "Mains ninja"
SWEP.Author = "Naruto RP"
SWEP.Purpose = "Clic gauche : attaque légère. Clic droit : attaque lourde."
SWEP.Category = "Naruto RP"
SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.Spawnable = false

SWEP.ViewModel = Model("models/weapons/c_arms.mdl")
SWEP.WorldModel = ""
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

local SWING_SOUND = Sound("WeaponFrag.Throw")

function SWEP:Initialize()
    self:SetHoldType("fist")
end

function SWEP:SetupDataTables()
    self:NetworkVar("Float", 0, "NextIdle")
    self:NetworkVar("Int", 0, "Combo")
end

function SWEP:PlayViewAnim(sequence)
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local vm = owner:GetViewModel()
    if not IsValid(vm) then return end

    vm:SendViewModelMatchingSequence(vm:LookupSequence(sequence))
    vm:SetPlaybackRate(1)
    self:SetNextIdle(CurTime() + vm:SequenceDuration())
end

local function CanSwing(owner)
    if not IsValid(owner) then return false end
    if owner:GetNW2Bool("NRP_Block", false) then return false end
    if NRP.Status and not NRP.Status.CanAct(owner) then return false end
    return true
end

function SWEP:PrimaryAttack()
    local cfg = NRP.Config.Combat.Melee
    local owner = self:GetOwner()

    self:SetNextPrimaryFire(CurTime() + cfg.LightDelay)
    self:SetNextSecondaryFire(CurTime() + cfg.LightDelay)
    if not CanSwing(owner) then return end

    local combo = (self:GetCombo() % 3) + 1
    self:SetCombo(combo)

    owner:SetAnimation(PLAYER_ATTACK1)
    if combo == 3 then
        self:PlayViewAnim("fists_uppercut")
    else
        self:PlayViewAnim(combo == 1 and "fists_left" or "fists_right")
    end
    self:EmitSound(SWING_SOUND, 60, 110)

    if SERVER then
        NRP.Combat.LightAttack(owner)
    end
end

function SWEP:SecondaryAttack()
    local cfg = NRP.Config.Combat.Melee
    local owner = self:GetOwner()

    self:SetNextSecondaryFire(CurTime() + cfg.HeavyDelay)
    self:SetNextPrimaryFire(CurTime() + cfg.HeavyWindup + 0.25)
    if not CanSwing(owner) then return end

    self:SetCombo(0)
    owner:SetAnimation(PLAYER_ATTACK1)
    self:PlayViewAnim("fists_uppercut")

    if SERVER then
        NRP.Combat.HeavyAttack(owner)
    end
end

function SWEP:Reload()
end

function SWEP:Think()
    local idle = self:GetNextIdle()
    if idle > 0 and CurTime() > idle then
        self:PlayViewAnim("fists_idle_0" .. math.random(1, 2))
    end
end

function SWEP:Deploy()
    self:PlayViewAnim("fists_draw")
    self:SetCombo(0)
    return true
end

function SWEP:Holster()
    self:SetNextIdle(0)
    return true
end

function SWEP:OnDrop()
    self:Remove()
end
