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
local BONUS_DEGATS = 30     -- % de dégâts infligés en plus
local REDUCTION    = 25     -- % de dégâts reçus en moins

local RECHARGE     = 25     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.4    -- incantation avant l'aura
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local SON_DEBUT    = "naruto_sound/jutsu/uchiha/uchiha1.wav"
local SON_FIN      = "naruto_sound/jutsu/uchiha/uchiha2.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "fuma_aura", stat, base) end

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
    ply:SetNW2Float("NA_AuraFumaFin", CurTime() + Niv(ply, "duree", DUREE))
    ply:EmitSound(SON_DEBUT, 75, 110, 0.8)

    timer.Create("fuma_aura_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function() Arreter(ply) end)
end

net.Receive("fuma_aura_cast", function(_, ply)
    if not NA_Debloquee(ply, "fuma_aura") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() or Actif(ply) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "fuma_aura", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "fuma_aura", "chakra", CHAKRA_COUT) then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "fuma_aura", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "fuma_aura", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "fuma_aura", NA_Stat(ply, "fuma_aura", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
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
    if Niv(att, "bonus_degats", BONUS_DEGATS) > 0 and IsValid(att) and att:IsPlayer() and att ~= cible and Actif(att) then
        dmg:ScaleDamage(1 + Niv(att, "bonus_degats", BONUS_DEGATS) / 100)
    end

    -- dégâts reçus par un porteur de l'aura
    if Niv(cible, "reduction", REDUCTION) > 0 and cible:IsPlayer() and Actif(cible) then
        dmg:ScaleDamage(1 - Niv(cible, "reduction", REDUCTION) / 100)
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
