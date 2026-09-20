AddCSLuaFile()

SWEP.PrintName = "Hands (No Idle)"
SWEP.Author    = "You"
SWEP.Category  = "Custom"
SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Base = "weapon_base"

-- Rien n’est affiché
SWEP.ViewModel = ""
SWEP.WorldModel = ""
SWEP.UseHands = false
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = false

SWEP.HoldType = "normal"

-- Désactivation totale des tirs
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
end

-- Empêche toute action
function SWEP:PrimaryAttack()
    return
end

function SWEP:SecondaryAttack()
    return
end

-- Empêche l’animation idle
function SWEP:Think()
    return
end

-- Rien ne se dessine dans le monde
function SWEP:DrawWorldModel()
    return
end

-- Arme neutre, ne drop pas
function SWEP:ShouldDropOnDie()
    return false
end
