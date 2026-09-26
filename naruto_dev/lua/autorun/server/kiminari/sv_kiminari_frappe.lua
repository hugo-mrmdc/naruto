--========================================================
-- Kiminari : Frappe noire (SERVEUR)
--
-- Mudras pendant DUREE_MUDRA secondes, puis À LA FIN des mudras la frappe se
-- pose là où le lanceur regarde à ce moment (PORTEE max ; au-delà, au sol
-- sous le point de portée max) : la particule
-- [19]_kiminari_charge (particles/atg_farisv2.pcf) y apparaît et
-- la décharge frappe : tout ennemi dans le rayon prend des dégâts et est
-- étourdi DUREE secondes (NA_Etourdir, sv_etourdissement.lua). La particule ne
-- s'affiche qu'au point visé (rien sur l'ennemi étourdi).
-- Particules affichées par cl_kiminari_frappe.lua (message "kiminari_frappe_fx").
--========================================================

if not SERVER then return end

util.AddNetworkString("kiminari_frappe_cast")
util.AddNetworkString("kiminari_frappe_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 15     -- dégâts de la décharge
local DUREE        = 2      -- secondes d'étourdissement
local RAYON        = 250    -- rayon autour du point visé (developer 1 pour le voir)
local PORTEE       = 900    -- distance max du point visé

local RECHARGE     = 18     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0      -- mudras avant la frappe (0 = la frappe part tout de suite)
local DUREE_FX     = 1      -- secondes de la particule sur le point frappé
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_COUPE   = 0.6    -- l'animation de mudras est coupée après ces secondes (0 = entière)

local SON_CHARGE   = "ambient/energy/electric_loop.wav"
local SON_DECHARGE = "ambient/energy/zap9.wav"
local SON_TOUCHE   = "ambient/energy/spark%d.wav"   -- %d = 1 à 6
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kiminari_frappe", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Point visé : ce que le regard touche dans la portée, sinon le sol sous le
-- point de portée max
local function PointVise(ply)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut,
        endpos = debut + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply,
        mask = MASK_SOLID,
    })
    if tr.Hit then return tr.HitPos end

    local sol = util.TraceLine({
        start = tr.HitPos,
        endpos = tr.HitPos - Vector(0, 0, 4000),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.HitPos
end

-- Particule de charge pendant "duree" secondes (vue par tout le monde),
-- sur une entité ou sur un point du monde
local function Fx(cible, duree)
    net.Start("kiminari_frappe_fx")
    if isvector(cible) then
        net.WriteBool(false)
        net.WriteVector(cible)
    else
        net.WriteBool(true)
        net.WriteEntity(cible)
    end
    net.WriteFloat(duree)
    net.Broadcast()
end

local function Decharge(ply, point)
    if not IsValid(ply) or not ply:Alive() then return end
    ply:StopSound(SON_CHARGE)
    sound.Play(SON_DECHARGE, point, 90, 100, 1)
    Fx(point, DUREE_FX)   -- la frappe tombe sur le point visé

    local rayon = Niv(ply, "rayon", RAYON)
    local duree = Niv(ply, "duree", DUREE)

    for _, ent in ipairs(ents.FindInSphere(point, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "kiminari_frappe", "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        if NA_Etourdir then NA_Etourdir(ent, duree) end
        -- pas de particule sur l'ennemi étourdi : la frappe ne s'affiche qu'au point visé
        ent:EmitSound(string.format(SON_TOUCHE, math.random(1, 6)), 75, math.random(95, 110), 0.8)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(point, rayon, 2, Color(120, 180, 255, 20), true)
    end
end

net.Receive("kiminari_frappe_cast", function(_, ply)
    if not NA_Debloquee(ply, "kiminari_frappe") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = NA_Stat(ply, "kiminari_frappe", "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "kiminari_frappe", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kiminari_frappe", NA_Stat(ply, "kiminari_frappe", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_APPEL, Niv(ply, "anim_coupe", ANIM_COUPE))   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    ply:EmitSound(SON_CHARGE, 70, 120, 0.6)

    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Decharge(ply, PointVise(ply))   -- point visé à la fin des mudras
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KiminariFrappe_Mort", function(ply)
    enCours[ply] = nil
    ply:StopSound(SON_CHARGE)
end)

hook.Add("PlayerDisconnected", "KiminariFrappe_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
