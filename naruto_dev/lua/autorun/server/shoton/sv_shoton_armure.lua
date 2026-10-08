--========================================================
-- Shoton : Armure de cristal (SERVEUR)
-- Après les mudras, une armure rose recouvre le lanceur pendant "duree" secondes : moins de dégâts subis.
-- Le visuel (silhouette + particules par os) est posé par les clients (cl_shoton_armure.lua) d'après le
-- NW2Bool "NA_ShotonArmure". Barre de durée : cl_duration_bars.lua.
--========================================================

util.AddNetworkString("shoton_armure_cast")

local DUREE       = 15
local REDUCTION   = 35    -- % de dégâts reçus en moins
local CHAKRA_COUT = 40
local RECHARGE    = 30
local CHAKRA_MAX  = NA_CHAKRA_MAX or 100
local DUREE_MUDRA = 0.4
local ANIM_APPEL  = "nrp_ninjutsu_defend_dragonflamebombs_start"

local ID = "shoton_armure"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Actif(ply) return IsValid(ply) and ply:GetNW2Bool("NA_ShotonArmure", false) end

local function Arreter(ply)
    if not IsValid(ply) then return end
    timer.Remove("ShotonArmure_" .. ply:EntIndex())
    if Actif(ply) and ply:Alive() then ply:EmitSound("geams/solve_jutsu/shoton/solve_shoton_dragon_start.wav", 75, 100, 0.7) end
    ply:SetNW2Bool("NA_ShotonArmure", false)
end

net.Receive("shoton_armure_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end
    if not NA_Debloquee(ply, ID) or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then
        -- (pas de message)
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        ply:SetNW2Bool("NA_ShotonArmure", true)
        ply:EmitSound("geams/solve_jutsu/shoton/solve_shoton_shuriken_start.wav", 80, 90, 0.9)
        timer.Create("ShotonArmure_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function() Arreter(ply) end)
    end)
end)

hook.Add("EntityTakeDamage", "ShotonArmure_Reduction", function(cible, dmg)
    if not cible:IsPlayer() or not Actif(cible) then return end
    dmg:ScaleDamage(1 - Niv(cible, "reduction", REDUCTION) / 100)
end)

hook.Add("PlayerDeath", "ShotonArmure_Mort", Arreter)
hook.Add("PlayerSpawn", "ShotonArmure_Spawn", Arreter)
hook.Add("PlayerDisconnected", "ShotonArmure_Nettoyage", function(ply)
    Arreter(ply)
    pret[ply] = nil
end)
