--[[
    Naruto RP - point d'entrée serveur
    Les fonctions GM:* ci-dessous sont volontairement minces : la logique vit dans les modules,
    qui s'abonnent aux hooks "NRP.*" émis ici.
]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local function GeneralConfig()
    return NRP.Config.General or {}
end

-- Contenu à télécharger par les clients (workshop / fichiers)
for _, id in ipairs(GeneralConfig().Workshop or {}) do
    resource.AddWorkshop(id)
end

-- Donne les armes du gamemode (appelé aussi après l'apparition, car un addon peut
-- renvoyer une valeur dans le hook PlayerLoadout et empêcher GM:PlayerLoadout).
function NRP.GiveDefaultWeapons(ply)
    local cfg = GeneralConfig()
    local weapons = cfg.DefaultWeapons or { "nrp_hands" }
    for _, class in ipairs(weapons) do
        if not ply:HasWeapon(class) then
            ply:Give(class)
        end
    end
    if cfg.AdminTools and ply:IsAdmin() then
        if not ply:HasWeapon("weapon_physgun") then ply:Give("weapon_physgun") end
        if not ply:HasWeapon("gmod_tool") then ply:Give("gmod_tool") end
    end
    if weapons[1] and not IsValid(ply:GetActiveWeapon()) then
        ply:SelectWeapon(weapons[1])
    end
end

function GM:PlayerSpawn(ply, transition)
    self.BaseClass.PlayerSpawn(self, ply, transition)
    if not transition then
        NRP.GiveDefaultWeapons(ply)
    end

    -- Les modules appliquent ici statistiques, ressources, apparence...
    -- (après la classe joueur de sandbox, qui écrase vitesses et vie).
    hook.Run("NRP.PlayerSpawned", ply, transition)
end

function GM:PlayerLoadout(ply)
    ply:StripWeapons()
    ply:StripAmmo()
    NRP.GiveDefaultWeapons(ply)
    hook.Run("NRP.PlayerLoadout", ply)

    return true
end

function GM:PlayerSetModel(ply)
    if NRP.Char and NRP.Char.ApplyAppearance and NRP.Char.ApplyAppearance(ply) then
        return
    end

    ply:SetModel(GeneralConfig().DefaultModel or "models/player/group01/male_07.mdl")
end

function GM:PlayerDeathThink(ply)
    local delay = GeneralConfig().RespawnDelay or 5
    if (ply.NRPDeathTime or 0) + delay > CurTime() then
        return false
    end

    if ply:KeyPressed(IN_ATTACK) or ply:KeyPressed(IN_ATTACK2) or ply:KeyPressed(IN_JUMP) then
        ply:Spawn()
    end
end

function GM:PlayerDeath(ply, inflictor, attacker)
    ply.NRPDeathTime = CurTime()
    self.BaseClass.PlayerDeath(self, ply, inflictor, attacker)
end

-- La touche F sert au blocage : pas de lampe torche.
function GM:PlayerSwitchFlashlight(ply, enabled)
    return not enabled
end

function GM:PlayerNoClip(ply, desired)
    if not desired then return true end
    return NRP.Perm.Has(ply, "admin.noclip")
end

-- Chat vocal de proximité (désactivable)
function GM:PlayerCanHearPlayersVoice(listener, talker)
    local range = GeneralConfig().VoiceRange
    if not range or range <= 0 then
        return true, false
    end
    return listener:GetPos():DistToSqr(talker:GetPos()) <= range * range, true
end

-- Restrictions sandbox : seuls les joueurs autorisés peuvent faire apparaître des objets.
local function CanSandbox(ply)
    return NRP.Perm.Has(ply, "admin.sandbox")
end

function GM:PlayerSpawnProp(ply) return CanSandbox(ply) end
function GM:PlayerSpawnSENT(ply) return CanSandbox(ply) end
-- Les armes de l'addon naruto_dev listées dans config/compat.lua restent accessibles à tous
function GM:PlayerSpawnSWEP(ply, class)
    return CanSandbox(ply) or NRP.Compat.CanTakeWeapon(ply, class)
end

function GM:PlayerGiveSWEP(ply, class)
    return CanSandbox(ply) or NRP.Compat.CanTakeWeapon(ply, class)
end
function GM:PlayerSpawnNPC(ply) return CanSandbox(ply) end
function GM:PlayerSpawnVehicle(ply) return CanSandbox(ply) end
function GM:PlayerSpawnRagdoll(ply) return CanSandbox(ply) end
function GM:PlayerSpawnEffect(ply) return CanSandbox(ply) end
function GM:PlayerSpawnObject(ply) return CanSandbox(ply) end

function GM:CanTool(ply, ...)
    return CanSandbox(ply) and self.BaseClass.CanTool(self, ply, ...)
end

function GM:PhysgunPickup(ply, ent)
    if ent:IsPlayer() then
        return NRP.Perm.Has(ply, "admin.physgunplayers")
    end
    return CanSandbox(ply) and self.BaseClass.PhysgunPickup(self, ply, ent)
end

function GM:CanProperty(ply, property, ent)
    return CanSandbox(ply) and self.BaseClass.CanProperty(self, ply, property, ent)
end

function GM:CanDrive()
    return false
end

function GM:GetFallDamage(ply, speed)
    local mult = GeneralConfig().FallDamageMultiplier or 1
    return math.max(0, (speed - 526.5) * (100 / 396)) * mult
end

function GM:ShutDown()
    hook.Run("NRP.ShutDown")
end
