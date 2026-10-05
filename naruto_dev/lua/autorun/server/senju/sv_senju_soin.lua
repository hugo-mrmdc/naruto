--========================================================
-- Senju : Soin (SERVEUR)
--
-- Le lanceur récupère un pourcentage de sa vie MAX, étalé sur une durée définie
-- (par défaut 25 % en 5 secondes, soit 5 % de la vie max par seconde) :
--   - une aura de soin l'entoure pendant ce temps (particule aura_senju_renfo_pat,
--     particles/patlick_atgparticules.pcf, dessinée par cl_senju_soin.lua) ;
--   - il peut bouger et se battre pendant le soin ;
--   - le soin s'arrête s'il meurt ; on ne peut pas le relancer tant qu'il agit.
--
-- Réseau : NW2Bool "NA_SenjuSoin" (soin en cours)
--========================================================

if not SERVER then return end

util.AddNetworkString("senju_soin_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.senju_soin)
--========================================================
local SOIN_POURCENT = 25     -- % de la vie MAX rendus au total
local DUREE         = 5      -- secondes sur lesquelles le soin est étalé

local CHAKRA_COUT   = 30     -- chakra consommé au lancement
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 25     -- secondes avant de pouvoir le relancer
local DUREE_MUDRA   = 0.5    -- incantation avant le soin
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "naruto_sound/jutsu/senju/senju2.wav"
local SON_FIN       = "naruto_sound/jutsu/senju/senju3.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_soin", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local soins   = {}   -- joueur -> { fin, parSeconde, reste }

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_SenjuSoin", false)
end

local function Arreter(ply, finNormale)
    soins[ply] = nil
    if not IsValid(ply) then return end
    if Actif(ply) and finNormale and ply:Alive() then ply:EmitSound(SON_FIN, 70, 100, 0.6) end
    ply:SetNW2Bool("NA_SenjuSoin", false)
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    local duree = math.max(Niv(ply, "duree", DUREE), 0.5)
    soins[ply] = {
        fin = CurTime() + duree,
        -- vie rendue par seconde : le pourcentage de la vie max, réparti sur la durée
        parSeconde = ply:GetMaxHealth() * Niv(ply, "soin_pourcent", SOIN_POURCENT) / 100 / duree,
        reste = 0,   -- fractions de PV accumulées d'un tick à l'autre
    }
    ply:SetNW2Bool("NA_SenjuSoin", true)
    ply:EmitSound(SON_DEBUT, 75, 100, 0.8)
end

net.Receive("senju_soin_cast", function(_, ply)
    if not IsValid(ply) then return end
    if not NA_Debloquee(ply, "senju_soin") then return end   -- technique pas encore débloquée (F6)
    if not ply:Alive() or enCours[ply] or Actif(ply) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "senju_soin", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Le soin, 10 fois par seconde
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "SenjuSoin_Tick", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for ply, s in pairs(soins) do
        if not IsValid(ply) or not ply:Alive() then
            Arreter(ply)
        elseif now >= s.fin then
            Arreter(ply, true)
        else
            s.reste = s.reste + s.parSeconde * dt
            local entier = math.floor(s.reste)
            if entier >= 1 then
                s.reste = s.reste - entier
                ply:SetHealth(math.min(ply:Health() + entier, ply:GetMaxHealth()))
            end
        end
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "SenjuSoin_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "SenjuSoin_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "SenjuSoin_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
    soins[ply] = nil
end)
