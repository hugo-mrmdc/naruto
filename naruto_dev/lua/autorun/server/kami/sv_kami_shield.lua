--========================================================
-- Paper Shield (SERVEUR)
-- Enveloppe le lanceur de papier : réduit les dégâts qu'il reçoit
-- pendant quelques secondes. Particules visibles par tout le monde.
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_shield_cast")
util.AddNetworkString("kami_shield_fx")
util.AddNetworkString("kami_shield_stop")

local PCF_PATH = "particles/atg_faris.pcf"
local FX_NAME  = "[2]_paper_shield"

game.AddParticles(PCF_PATH)
PrecacheParticleSystem(FX_NAME)
resource.AddFile(PCF_PATH)

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

local DUREE        = 15     -- durée du bouclier (secondes)
local REDUCTION    = 50    -- % de dégâts reçus en moins
local RECHARGE     = 15     -- secondes avant de pouvoir relancer (après la fin)
local CHAKRA_COUT  = 25     -- chakra dépensé au lancement (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.6    -- incantation avant l'apparition du bouclier
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kami_bouclier", stat, base) end

local shielded = {}  -- joueur -> heure de fin
local casting  = {}
local nextUse  = {}

local function GetChakra(ply)
    return ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
end

local function StopShield(ply)
    if not shielded[ply] then return end
    shielded[ply] = nil

    if IsValid(ply) then
        ply:SetNW2Bool("NA_PaperShield", false)
        timer.Remove("kami_shield_" .. ply:EntIndex())

        net.Start("kami_shield_stop")
            net.WriteEntity(ply)
        net.Broadcast()
    end
end

local function StartShield(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    shielded[ply] = CurTime() + Niv(ply, "duree", DUREE)
    ply:SetNW2Bool("NA_PaperShield", true)
    nextUse[ply] = CurTime() + Niv(ply, "duree", DUREE) + NA_Stat(ply, "kami_bouclier", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kami_bouclier", Niv(ply, "duree", DUREE) + NA_Stat(ply, "kami_bouclier", "recharge", RECHARGE)) end -- recharge visible dans la barre

    net.Start("kami_shield_fx")
        net.WriteEntity(ply)
        net.WriteFloat(Niv(ply, "duree", DUREE))
    net.Broadcast()

    ply:EmitSound("geams/solve_jutsu/meiton/solve_meiton_dome_start.wav", 70, 120, 0.6)

    timer.Create("kami_shield_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function()
        StopShield(ply)
    end)
end

----------------------------------------------------------
-- Lancement
----------------------------------------------------------
net.Receive("kami_shield_cast", function(_, ply)
    if not NA_Debloquee(ply, "kami_bouclier") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if shielded[ply] or casting[ply] then return end

    if (nextUse[ply] or 0) > CurTime() then
        ply:ChatPrint("Paper Shield : encore " .. math.ceil(nextUse[ply] - CurTime()) .. " secondes")
        return
    end

    if NA_Stat(ply, "kami_bouclier", "chakra", CHAKRA_COUT) > 0 then
        if GetChakra(ply) < NA_Stat(ply, "kami_bouclier", "chakra", CHAKRA_COUT) then
            ply:ChatPrint("Pas assez de chakra pour le Paper Shield.")
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, GetChakra(ply) - NA_Stat(ply, "kami_bouclier", "chakra", CHAKRA_COUT)))
    end

    casting[ply] = true

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        if IsValid(ply) then casting[ply] = nil end
        StartShield(ply)
    end)
end)

----------------------------------------------------------
-- Réduction des dégâts
----------------------------------------------------------
hook.Add("EntityTakeDamage", "KamiShield_Reduce", function(target, dmg)
    if not target:IsPlayer() then return end

    local fin = shielded[target]
    if not fin then return end

    if CurTime() > fin then
        StopShield(target)
        return
    end

    if Niv(target, "reduction", REDUCTION) <= 0 then return end
    dmg:ScaleDamage(math.Clamp(1 - Niv(target, "reduction", REDUCTION) / 100, 0, 1))
    target:EmitSound("geams/solve_jutsu/meiton/solve_meiton_boost_start.wav", 65, 110, 0.6)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KamiShield_Death", function(ply)
    casting[ply] = nil
    StopShield(ply)
end)

hook.Add("PlayerSpawn", "KamiShield_Spawn", function(ply)
    casting[ply] = nil
    StopShield(ply)
end)

hook.Add("PlayerDisconnected", "KamiShield_Cleanup", function(ply)
    StopShield(ply)
    casting[ply] = nil
    nextUse[ply] = nil
end)
