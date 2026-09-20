--[[
    Module : combat (partagé) - touches, états visibles, verrouillage des mouvements

    États réseau (NW2, visibles de tous car nécessaires aux animations/prédictions) :
        NRP_Block          bool   garde levée
        NRP_CastEnd        float  fin d'incantation (module jutsu)
        NRP_CastRoot       bool   immobilisé pendant l'incantation
        NRP_St_<status>    float  fin d'un statut (voir sh_status.lua)
        NRP_SpawnProtect   float  fin de la protection d'apparition
]]

NRP.Combat = NRP.Combat or {}
local Combat = NRP.Combat

NRP.Keys.Register("block", { name = "Bloquer (maintenir)", default = KEY_C, order = 10 })
NRP.Keys.Register("dodge", { name = "Esquive", default = KEY_Z, order = 11 })
NRP.Keys.Register("dash", { name = "Dash", default = KEY_LALT, order = 12 })
NRP.Keys.Register("substitution", { name = "Substitution (Kawarimi)", default = KEY_X, order = 13 })

function Combat.Cfg()
    return NRP.Config.Combat
end

function Combat.IsBlocking(ply)
    return ply:GetNW2Bool("NRP_Block", false)
end

function Combat.HasSpawnProtection(ply)
    return ply:GetNW2Float("NRP_SpawnProtect", 0) > CurTime()
end

-- La position pos est-elle dans le cône de vision (horizontal) du joueur ?
function Combat.IsFacing(ply, pos, halfAngle)
    local fwd = ply:GetAimVector()
    fwd.z = 0
    fwd:Normalize()

    local to = pos - ply:GetPos()
    to.z = 0
    if to:IsZero() then return true end
    to:Normalize()

    return fwd:Dot(to) >= math.cos(math.rad(halfAngle or 60))
end

function Combat.IsDamageable(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() then return ent:Alive() end
    return ent:IsNPC() or ent:IsNextBot() or ent.NRPDamageable == true
end

-- Mouvement : statuts bloquants, incantation, garde (prédit côté client)
hook.Add("SetupMove", "NRP.Combat.Movement", function(ply, mv)
    local now = CurTime()
    local locked = ply:GetNW2Float("NRP_St_stun", 0) > now
        or ply:GetNW2Float("NRP_St_root", 0) > now
        or (ply:GetNW2Bool("NRP_CastRoot", false) and ply:GetNW2Float("NRP_CastEnd", 0) > now)

    if locked then
        mv:SetForwardSpeed(0)
        mv:SetSideSpeed(0)
        mv:SetUpSpeed(0)
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_JUMP, IN_SPEED))))
        return
    end

    if ply:GetNW2Bool("NRP_Block", false) then
        local mult = Combat.Cfg().Block.MoveSpeedMultiplier
        mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * mult)
        mv:SetMaxSpeed(mv:GetMaxSpeed() * mult)
        mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(IN_SPEED)))
    end
end)
