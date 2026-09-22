--========================================================
-- Kiminari : Laser Circus (SERVEUR)
--
-- Après les mudras, le lanceur tire VAGUES salves de lasers : à chaque salve,
-- un laser part de sa main vers chaque ennemi visible devant lui (cône ANGLE,
-- PORTEE max, CIBLES max), qui prend des dégâts. Sans ennemi, un laser part
-- quand même vers le point visé.
-- Particule : laser_circus_kiminari_pat (particles/patlick_atgparticules.pcf),
-- un rayon du point de contrôle 0 (départ) au point de contrôle 1 (arrivée).
--
-- Réseau : "kiminari_laser_fx" (départ + liste des arrivées) -> cl_kiminari_laser.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("kiminari_laser_cast")
util.AddNetworkString("kiminari_laser_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 14     -- dégâts par laser
local VAGUES       = 3      -- nombre de salves
local INTERVALLE   = 0.35   -- secondes entre deux salves
local CIBLES       = 5      -- ennemis touchés au maximum par salve

local PORTEE       = 1200   -- distance max des lasers
local ANGLE        = 45     -- demi-angle du cône devant le lanceur (degrés)

local RECHARGE     = 26     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 40     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la première salve
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_CHARGE   = "ambient/energy/electric_loop.wav"
local SON_TIR      = "ambient/energy/zap%d.wav"     -- %d = 1 à 3
local SON_TOUCHE   = "ambient/energy/spark%d.wav"   -- %d = 1 à 6
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kiminari_laser", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Départ des lasers : la main droite si le modèle en a une, sinon devant les yeux
local function Depart(ply)
    local os = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    if os then
        local pos = ply:GetBonePosition(os)
        if pos then return pos end
    end
    return ply:EyePos() + ply:GetAimVector() * 20
end

-- Ennemis visibles dans le cône devant le lanceur, les plus proches d'abord
local function Cibles(ply, depart)
    local portee = Niv(ply, "portee", PORTEE)
    local cosMin = math.cos(math.rad(Niv(ply, "angle", ANGLE)))
    local regard = ply:GetAimVector()
    local liste = {}

    for _, ent in ipairs(ents.FindInSphere(depart, portee)) do
        if not EstCible(ent, ply) then continue end
        local centre = ent:WorldSpaceCenter()
        local dir = centre - depart
        local dist = dir:Length()
        if dist > portee or dist < 1 then continue end
        if regard:Dot(dir / dist) < cosMin then continue end

        local tr = util.TraceLine({ start = depart, endpos = centre, filter = { ply, ent }, mask = MASK_SHOT })
        if tr.Hit then continue end   -- un mur entre les deux

        liste[#liste + 1] = { ent = ent, dist = dist }
    end

    table.sort(liste, function(a, b) return a.dist < b.dist end)
    local max = Niv(ply, "cibles", CIBLES)
    local res = {}
    for i = 1, math.min(#liste, max) do res[i] = liste[i].ent end
    return res
end

local function Salve(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local depart = Depart(ply)
    local cibles = Cibles(ply, depart)
    local arrivees = {}

    for _, ent in ipairs(cibles) do
        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "kiminari_laser", "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(string.format(SON_TOUCHE, math.random(1, 6)), 75, math.random(95, 110), 0.8)
        arrivees[#arrivees + 1] = ent:WorldSpaceCenter()
    end

    -- personne : un laser part quand même vers le point visé
    if #arrivees == 0 then
        local tr = util.TraceLine({
            start = ply:EyePos(),
            endpos = ply:EyePos() + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
            filter = ply,
            mask = MASK_SHOT,
        })
        arrivees[1] = tr.HitPos
    end

    ply:EmitSound(string.format(SON_TIR, math.random(1, 3)), 80, math.random(100, 115), 0.9)

    net.Start("kiminari_laser_fx")
        net.WriteVector(depart)
        net.WriteUInt(#arrivees, 6)
        for _, pos in ipairs(arrivees) do net.WriteVector(pos) end
    net.Broadcast()
end

net.Receive("kiminari_laser_cast", function(_, ply)
    if not NA_Debloquee(ply, "kiminari_laser") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = NA_Stat(ply, "kiminari_laser", "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "kiminari_laser", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kiminari_laser", NA_Stat(ply, "kiminari_laser", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    ply:EmitSound(SON_CHARGE, 70, 130, 0.6)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local vagues = Niv(ply, "vagues", VAGUES)
    local intervalle = Niv(ply, "intervalle", INTERVALLE)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    for i = 0, vagues - 1 do
        timer.Simple(mudra + i * intervalle, function()
            if i == vagues - 1 then enCours[ply] = nil end
            if not IsValid(ply) then return end
            if i == 0 then ply:StopSound(SON_CHARGE) end
            Salve(ply)
        end)
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KiminariLaser_Mort", function(ply)
    enCours[ply] = nil
    ply:StopSound(SON_CHARGE)
end)

hook.Add("PlayerDisconnected", "KiminariLaser_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
