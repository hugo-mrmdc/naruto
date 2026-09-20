--========================================================
-- Fuma : Aura (SERVEUR)
--
-- Buff sur soi : pendant DUREE secondes, une aura entoure le lanceur
-- (particule fuma_buff de particles/fuma.pcf, affichée par cl_fumaaura.lua).
-- Il inflige plus de dégâts et en encaisse moins.
--
-- Réseau : NW2Bool "NA_AuraFuma" (aura active) et NW2Float "NA_AuraFumaFin"
--========================================================

if not SERVER then return end

util.AddNetworkString("fuma_aura_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 12     -- secondes du buff
local BONUS_DEGATS = 0.30   -- dégâts infligés en plus (0.30 = +30 %)
local REDUCTION    = 0.25   -- dégâts reçus en moins (0.25 = -25 %)

local RECHARGE     = 25     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.4    -- incantation avant l'aura
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local SON_DEBUT    = "ambient/energy/newspark04.wav"
local SON_FIN      = "ambient/energy/newspark02.wav"
--========================================================

local enCours = {}
local pret    = {}

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_AuraFuma", false)
end

local function Arreter(ply)
    if not IsValid(ply) or not Actif(ply) then return end
    timer.Remove("fuma_aura_" .. ply:EntIndex())
    ply:SetNW2Bool("NA_AuraFuma", false)
    ply:SetNW2Float("NA_AuraFumaFin", 0)
    if ply:Alive() then ply:EmitSound(SON_FIN, 70, 90, 0.6) end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    ply:SetNW2Bool("NA_AuraFuma", true)
    ply:SetNW2Float("NA_AuraFumaFin", CurTime() + DUREE)
    ply:EmitSound(SON_DEBUT, 75, 110, 0.8)

    timer.Create("fuma_aura_" .. ply:EntIndex(), DUREE, 1, function() Arreter(ply) end)
end

net.Receive("fuma_aura_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() or Actif(ply) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if CHAKRA_COUT > 0 then
        if chakra < CHAKRA_COUT then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - CHAKRA_COUT)
    end

    enCours[ply] = true
    pret[ply] = CurTime() + RECHARGE
    if NA_CD then NA_CD.Set(ply, "fuma_aura", RECHARGE) end   -- recharge visible dans la barre

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Effets du buff
----------------------------------------------------------
hook.Add("EntityTakeDamage", "FumaAura_Degats", function(cible, dmg)
    -- dégâts infligés par un porteur de l'aura
    local att = dmg:GetAttacker()
    if BONUS_DEGATS > 0 and IsValid(att) and att:IsPlayer() and att ~= cible and Actif(att) then
        dmg:ScaleDamage(1 + BONUS_DEGATS)
    end

    -- dégâts reçus par un porteur de l'aura
    if REDUCTION > 0 and cible:IsPlayer() and Actif(cible) then
        dmg:ScaleDamage(1 - REDUCTION)
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "FumaAura_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "FumaAura_Spawn", Arreter)

hook.Add("PlayerDisconnected", "FumaAura_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
