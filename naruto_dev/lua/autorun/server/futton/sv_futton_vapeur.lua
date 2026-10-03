--========================================================
-- Futton : Émanation de vapeur (SERVEUR)
--
-- Buff sur soi : pendant DUREE secondes, une vapeur (particule emanation_vapeur_pat, affichée par
-- cl_futton_vapeur.lua) émane du lanceur. Il court plus vite (VITESSE, lu par le hook Move de
-- futton_init.lua) et les ennemis autour de lui (RAYON) subissent des dégâts à chaque tick.
--
-- Réseau : "futton_vapeur_cast" (client -> serveur) ; NW2Bool "NA_FuttonVapeur", NW2Float "NA_FuttonVitesse"
--========================================================

util.AddNetworkString("futton_vapeur_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 8      -- secondes du buff
local VITESSE      = 1.3    -- multiplicateur de vitesse du lanceur
local DEGATS       = 6      -- dégâts par tick aux ennemis autour
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local RAYON        = 220    -- rayon de la vapeur

local RECHARGE     = 20
local CHAKRA_COUT  = 30
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "futton_vapeur"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

local enCours = {}
local pret    = {}

local function TimerNom(ply) return "futton_vapeur_" .. ply:EntIndex() end

local function Arreter(ply)
    if not IsValid(ply) then return end
    timer.Remove(TimerNom(ply))
    ply:SetNW2Bool("NA_FuttonVapeur", false)
    ply:SetNW2Float("NA_FuttonVitesse", 1)
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local rayon, degats = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS)
    ply:SetNW2Bool("NA_FuttonVapeur", true)
    ply:SetNW2Float("NA_FuttonVitesse", Niv(ply, "vitesse", VITESSE))

    local fin = CurTime() + Niv(ply, "duree", DUREE)
    timer.Create(TimerNom(ply), Niv(ply, "intervalle", INTERVALLE), 0, function()
        if not IsValid(ply) or not ply:Alive() or CurTime() >= fin then Arreter(ply) return end
        for _, ent in ipairs(ents.FindInSphere(ply:GetPos() + Vector(0, 0, 40), rayon)) do
            if EstCible(ent, ply) then
                local dmg = DamageInfo()
                dmg:SetDamage(degats)
                dmg:SetAttacker(ply)
                dmg:SetInflictor(ply)
                dmg:SetDamageType(DMG_BURN)
                dmg:SetDamagePosition(ent:WorldSpaceCenter())
                ent:TakeDamageInfo(dmg)
            end
        end
    end)
end

net.Receive("futton_vapeur_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() or ply:GetNW2Bool("NA_FuttonVapeur", false) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

hook.Add("PlayerDeath", "FuttonVapeur_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)
hook.Add("PlayerSpawn", "FuttonVapeur_Spawn", Arreter)
hook.Add("PlayerDisconnected", "FuttonVapeur_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply], pret[ply] = nil, nil
end)
