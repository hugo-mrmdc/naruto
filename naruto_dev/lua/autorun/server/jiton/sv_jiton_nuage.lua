--========================================================
-- Jiton : Nuage de sable (SERVEUR)
--
-- Après les mudras, un nuage de sable (particule [1]_sand_cloud,
-- particles/atg_faris.pcf, affichée par cl_jiton_nuage.lua d'après
-- NW2Bool "NA_Nuage") porte le lanceur : il VOLE, avec le même pilotage que les
-- ailes de papier (NW2Bool "NA_Vol", lua/kami/sh_kami_wings_move.lua :
-- ZQSD, Espace monte, Ctrl descend).
-- Il dure DUREE secondes ; E permet d'en descendre avant.
--========================================================

if not SERVER then return end

util.AddNetworkString("jiton_nuage_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
-- (valeurs du niveau 1, remplacées par celles de _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 20     -- secondes sur le nuage
local RECHARGE     = 45     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant le nuage
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local TOUCHE_DESCENDRE = IN_USE   -- E
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jiton_nuage", stat, base) end

local enCours = {}
local pret    = {}

local function TimerNom(ply) return "jiton_nuage_" .. ply:EntIndex() end

local function Descendre(ply)
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Nuage", false) then return end
    timer.Remove(TimerNom(ply))

    ply:SetNW2Bool("NA_Nuage", false)
    ply:SetNW2Bool("NA_Vol", false)
    ply.MokutonNoFall = CurTime() + 5   -- on peut retomber de haut : pas de dégâts de chute
    ply:EmitSound("naruto_sound/jutsu/jishaku/jishaku6.wav", 70, 90, 0.8)
end

local function Monter(ply)
    if not IsValid(ply) then return end

    ply:SetNW2Bool("NA_Nuage", true)
    ply:SetNW2Bool("NA_Vol", true)
    ply:SetVelocity(Vector(0, 0, 200))   -- petit décollage
    ply:EmitSound("naruto_sound/jutsu/jishaku/jishaku7.wav", 70, 90, 0.6)

    timer.Create(TimerNom(ply), Niv(ply, "duree", DUREE), 1, function() Descendre(ply) end)
end

net.Receive("jiton_nuage_cast", function(_, ply)
    if not NA_Debloquee(ply, "jiton_nuage") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return end   -- déjà en vol

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "jiton_nuage", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Monter(ply)
    end)
end)

-- E : on descend du nuage
hook.Add("KeyPress", "JitonNuage_Descendre", function(ply, key)
    if key == TOUCHE_DESCENDRE then Descendre(ply) end
end)

hook.Add("PlayerDeath", "JitonNuage_Mort", function(ply)
    enCours[ply] = nil
    Descendre(ply)
end)

hook.Add("PlayerSpawn", "JitonNuage_Spawn", Descendre)

hook.Add("PlayerDisconnected", "JitonNuage_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
    timer.Remove(TimerNom(ply))
end)
