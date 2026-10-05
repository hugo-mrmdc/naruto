--========================================================
-- Chinoike : Vortex de sang (SERVEUR)
--
-- On vise un endroit : un vortex de sang s'ouvre au sol pendant DUREE
-- secondes (particule vortex_sang_pat, particles/atg_particules2.pcf).
-- Il ATTIRE vers son centre tous les ennemis autour, en tourbillonnant,
-- et le CŒUR blesse ceux qui y sont pris à chaque tick.
--
-- Réseau : "chinoike_vortex_zone" (position + durée) -> cl_chinoike_vortex.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("chinoike_vortex_cast")
util.AddNetworkString("chinoike_vortex_zone")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
-- (dégâts, chakra, recharge, durée, rayon du cœur et force : valeurs du niveau 1,
--  remplacées par celles de _na_niveaux_techniques.lua si elles y sont réglées)
--========================================================
local DUREE        = 3.5    -- secondes de vortex (= durée de la particule)
local INTERVALLE   = 0.5    -- secondes entre deux ticks de dégâts
local PAS          = 0.05   -- secondes entre deux poussées vers le centre

local PORTEE       = 900    -- distance max où on peut poser le vortex
local RAYON_ATTIRE = 450    -- distance à partir de laquelle on est aspiré
local RAYON_COEUR  = 200    -- zone qui blesse (~ taille de la particule, developer 1 pour la voir)

local FORCE        = 3000   -- aspiration des joueurs (plus fort que la course : on ne s'enfuit pas en courant)
local TOURBILLON   = 900    -- rotation autour du centre
local VITESSE_PNJ  = 350    -- vitesse à laquelle les PNJ / nextbots glissent vers le centre

local DEGATS       = 10     -- dégâts par tick et par ennemi dans le cœur

local RECHARGE     = 20     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant le vortex
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "naruto_sound/jutsu/mugen/1-01.wav"
local SON_TICK     = "naruto_sound/jutsu/mugen/1-02.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "chinoike_vortex", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- on n'aspire pas à travers les murs
local function Visible(depuis, ent)
    local tr = util.TraceLine({
        start = depuis,
        endpos = ent:WorldSpaceCenter(),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return not tr.Hit
end

-- Endroit visé, ramené au sol
local function Viser(ply)
    local oeil = ply:EyePos()
    local tr = util.TraceLine({
        start = oeil,
        endpos = oeil + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply,
    })

    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 40),
        endpos = tr.HitPos - Vector(0, 0, 400),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })

    return sol.Hit and sol.HitPos or tr.HitPos
end

local function Attirer(ply, centre)
    local milieu = centre + Vector(0, 0, 40)
    local rayonCoeur = NA_Stat(ply, "chinoike_vortex", "rayon", RAYON_COEUR)

    for _, ent in ipairs(ents.FindInSphere(milieu, Niv(ply, "rayon_attire", RAYON_ATTIRE))) do
        -- joueurs : aspirés dans SetupMove (sh_chinoike_vortex.lua), prédit par leur client
        if ent:IsPlayer() then continue end
        if not EstCible(ent, ply) or not Visible(milieu, ent) then continue end

        local vers = centre - ent:GetPos()
        vers.z = 0
        local dist = vers:Length()
        if dist < 30 then continue end   -- déjà au centre : pas de tremblement

        local dir = vers / dist
        local tangente = Vector(-dir.y, dir.x, 0)

        -- l'aspiration faiblit près du centre, sinon on le dépasse et on fait des allers-retours
        local attenuation = math.Clamp(dist / rayonCoeur, 0.25, 1)

        -- PNJ / nextbots : on les fait glisser à vitesse fixe, sans traverser les murs
        local vitesse = Niv(ply, "vitesse_pnj", VITESSE_PNJ) * attenuation
        local depart = ent:GetPos()
        local tr = util.TraceHull({
            start = depart, endpos = depart + (dir * vitesse + tangente * vitesse * 0.3) * Niv(ply, "pas", PAS),
            mins = ent:OBBMins(), maxs = ent:OBBMaxs(),
            filter = ent, mask = MASK_NPCSOLID,
        })
        if not tr.StartSolid then ent:SetPos(tr.HitPos) end
    end
end

local function Blesser(ply, centre)
    local milieu = centre + Vector(0, 0, 40)
    local rayonCoeur = NA_Stat(ply, "chinoike_vortex", "rayon", RAYON_COEUR)

    for _, ent in ipairs(ents.FindInSphere(milieu, rayonCoeur)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "chinoike_vortex", "degats", DEGATS))
        dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
        dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(SON_TICK, 70, math.random(90, 110), 0.6)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(milieu, rayonCoeur, Niv(ply, "intervalle", INTERVALLE), Color(255, 60, 60, 20), true)
        debugoverlay.Sphere(milieu, Niv(ply, "rayon_attire", RAYON_ATTIRE), Niv(ply, "intervalle", INTERVALLE), Color(255, 160, 160, 8), true)
    end
end

local function Lancer(ply, centre)
    if not IsValid(ply) then return end
    local duree = NA_Stat(ply, "chinoike_vortex", "duree", DUREE)

    -- aspiration des joueurs (sh_chinoike_vortex.lua) : mêmes valeurs sur le serveur et chez les clients
    local v = {
        centre       = centre,
        fin          = CurTime() + duree,
        lanceur      = ply,
        rayon_attire = Niv(ply, "rayon_attire", RAYON_ATTIRE),
        rayon_coeur  = NA_Stat(ply, "chinoike_vortex", "rayon", RAYON_COEUR),
        force        = NA_Stat(ply, "chinoike_vortex", "force", FORCE),
        tourbillon   = Niv(ply, "tourbillon", TOURBILLON),
    }
    NA_VortexSang.Ajouter(v)

    net.Start("chinoike_vortex_zone")
        net.WriteVector(centre)
        net.WriteFloat(duree)
        net.WriteEntity(ply)
        net.WriteFloat(v.rayon_attire)
        net.WriteFloat(v.rayon_coeur)
        net.WriteFloat(v.force)
        net.WriteFloat(v.tourbillon)
    net.Broadcast()

    sound.Play(SON_DEBUT, centre + Vector(0, 0, 60), 85, 70, 1)

    local fin = CurTime() + duree
    local prochainDegat = CurTime()
    local nom = "chinoike_vortex_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(nom, Niv(ply, "pas", PAS), 0, function()
        local now = CurTime()
        if now >= fin then
            timer.Remove(nom)
            return
        end

        Attirer(ply, centre)

        if now >= prochainDegat then
            prochainDegat = now + Niv(ply, "intervalle", INTERVALLE)
            Blesser(ply, centre)
        end
    end)
end

net.Receive("chinoike_vortex_cast", function(_, ply)
    if not NA_Debloquee(ply, "chinoike_vortex") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = NA_Stat(ply, "chinoike_vortex", "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = NA_Stat(ply, "chinoike_vortex", "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "chinoike_vortex", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Lancer(ply, Viser(ply))
    end)
end)

hook.Add("PlayerDisconnected", "ChinoikeVortex_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
