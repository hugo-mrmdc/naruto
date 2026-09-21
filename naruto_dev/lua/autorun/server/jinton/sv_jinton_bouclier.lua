--========================================================
-- Jinton : Bouclier (SERVEUR)
--
-- Une sphère (models/justu/jinton/sphereonoki.mdl) entoure le lanceur, avec la
-- particule jinton_shield (particles/solve_jinton_02.pcf). Pendant DUREE secondes,
-- il a un bouclier égal à POURCENT_VIE de sa vie max : les dégâts le vident avant
-- de toucher la vie. Le bouclier casse quand il est vide.
-- La sphère est l'entité jinton_bouclier (lua/entities/jinton_bouclier.lua).
--
-- Réseau (lu par le HUD, cl_hud_vie.lua) :
--   NW2Float "NA_Bouclier"    -> points de bouclier restants
--   NW2Float "NA_BouclierMax" -> points de bouclier au lancement
--========================================================

if not SERVER then return end

util.AddNetworkString("jinton_bouclier_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local POURCENT_VIE  = 20    -- % de la vie max en bouclier
local DUREE         = 10     -- secondes
local ECHELLE       = 1.35   -- taille de la sphère (1 = 68 unités de diamètre)

local RECHARGE      = 20     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.5    -- incantation avant l'apparition du bouclier
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT     = "ambient/energy/whiteflash.wav"
local SON_IMPACT    = "physics/glass/glass_impact_bullet%d.wav"   -- %d = 1 à 4
local SON_CASSE     = "physics/glass/glass_largesheet_break1.wav"

-- Explosion à la fin du bouclier (son du tick du cube, particule du vortex Jinton)
-- Zone : un cylindre autour du lanceur (le lanceur n'est pas touché).
local EXPLOSION        = true
local EXPLOSION_SI_CASSE = true   -- true = explose aussi quand le bouclier est brisé
local EXPLO_DEGATS     = 30
local EXPLO_RAYON      = 200      -- rayon du cylindre
local EXPLO_HAUTEUR    = 140      -- hauteur du cylindre, depuis les pieds du lanceur
local EXPLO_FX         = "[7]_jinton_vortex_expl_add2"            -- particles/atg_farisv2.pcf
local EXPLO_SON        = "jutsu/jinton/damage_cube_explosion.wav" -- son du tick du cube
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jinton_bouclier", stat, base) end

local enCours = {}
local pret    = {}

local function Bouclier(ply)
    return ply:GetNW2Float("NA_Bouclier", 0)
end

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Cylindre de debug (developer 1) : cercles du bas et du haut + montants
local function DessinerCylindre(base, rayon, hauteur, duree, couleur)
    local haut = Vector(0, 0, hauteur)
    local precedent
    for i = 0, 24 do
        local a = math.rad(i / 24 * 360)
        local p = base + Vector(math.cos(a) * rayon, math.sin(a) * rayon, 0)
        if precedent then
            debugoverlay.Line(precedent, p, duree, couleur, true)
            debugoverlay.Line(precedent + haut, p + haut, duree, couleur, true)
        end
        if i % 6 == 0 then debugoverlay.Line(p, p + haut, duree, couleur, true) end
        precedent = p
    end
end

-- Explosion de fin : particule, son du tick du cube, dégâts dans un cylindre
local function Exploser(ply)
    local base = ply:GetPos()
    local centre = base + Vector(0, 0, Niv(ply, "explo_hauteur", EXPLO_HAUTEUR) / 2)

    ParticleEffect(EXPLO_FX, ply:WorldSpaceCenter(), Angle(0, 0, 0))
    ply:EmitSound(EXPLO_SON, 85, 100)

    local portee = math.sqrt(Niv(ply, "explo_rayon", EXPLO_RAYON) ^ 2 + (Niv(ply, "explo_hauteur", EXPLO_HAUTEUR) / 2) ^ 2) + 40
    for _, ent in ipairs(ents.FindInSphere(centre, portee)) do
        if not EstCible(ent, ply) then continue end

        -- dans le cylindre : assez près à l'horizontale, et hauteurs qui se chevauchent
        local pos = ent:GetPos()
        local ecart = Vector(pos.x - base.x, pos.y - base.y, 0):Length()
        local bas, hautEnt = pos.z + ent:OBBMins().z, pos.z + ent:OBBMaxs().z
        if ecart <= Niv(ply, "explo_rayon", EXPLO_RAYON) and hautEnt >= base.z and bas <= base.z + Niv(ply, "explo_hauteur", EXPLO_HAUTEUR) then
            local dmg = DamageInfo()
            dmg:SetDamage(NA_Stat(ply, "jinton_bouclier", "degats", EXPLO_DEGATS))
            dmg:SetAttacker(ply)
            dmg:SetInflictor(ply)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)
            ParticleEffect(EXPLO_FX, ent:WorldSpaceCenter(), Angle(0, 0, 0))
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        DessinerCylindre(base, Niv(ply, "explo_rayon", EXPLO_RAYON), Niv(ply, "explo_hauteur", EXPLO_HAUTEUR), 3, Color(255, 120, 60))
    end
end

-- Retire le bouclier (fin du temps, bouclier vide, mort...)
--   casse   = le bouclier a été brisé (son de verre)
--   exploser = fin normale ou bris : l'explosion de fin se déclenche
function NA_JintonBouclierFin(ply, casse, exploser)
    if not IsValid(ply) then return end
    local actif = ply:GetNW2Float("NA_BouclierMax", 0) > 0
    if IsValid(ply.NA_SphereJinton) then ply.NA_SphereJinton:Remove() end
    ply.NA_SphereJinton = nil
    timer.Remove("jinton_bouclier_" .. ply:EntIndex())

    if Bouclier(ply) > 0 or casse then
        ply:EmitSound(casse and SON_CASSE or "ambient/energy/whiteflash.wav", 70, casse and 110 or 140, 0.6)
    end
    ply:SetNW2Float("NA_Bouclier", 0)
    ply:SetNW2Float("NA_BouclierMax", 0)

    if exploser and actif and EXPLOSION and ply:Alive() and (not casse or EXPLOSION_SI_CASSE) then
        -- juste après : le bris arrive pendant le calcul d'un dégât, on n'en inflige pas d'autres dedans
        timer.Simple(0, function()
            if IsValid(ply) and ply:Alive() then Exploser(ply) end
        end)
    end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    NA_JintonBouclierFin(ply)

    local points = math.max(1, math.floor(ply:GetMaxHealth() * Niv(ply, "pourcent_vie", POURCENT_VIE) / 100))
    ply:SetNW2Float("NA_Bouclier", points)
    ply:SetNW2Float("NA_BouclierMax", points)

    local sphere = ents.Create("jinton_bouclier")
    if IsValid(sphere) then
        sphere.Echelle = Niv(ply, "echelle", ECHELLE)
        sphere:SetOwner(ply)
        sphere:Spawn()
        ply.NA_SphereJinton = sphere
    end

    ply:EmitSound(SON_DEBUT, 75, 120, 0.7)
    timer.Create("jinton_bouclier_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function()
        NA_JintonBouclierFin(ply, false, true)   -- fin du temps : explosion
    end)
end

local function Refus(ply, message)
    ply:PrintMessage(HUD_PRINTCENTER, message)
end

net.Receive("jinton_bouclier_cast", function(_, ply)
    if not NA_Debloquee(ply, "jinton_bouclier") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "jinton_bouclier", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "jinton_bouclier", "chakra", CHAKRA_COUT) then return Refus(ply, "Pas assez de chakra") end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "jinton_bouclier", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "jinton_bouclier", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "jinton_bouclier", NA_Stat(ply, "jinton_bouclier", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Absorption des dégâts
----------------------------------------------------------
hook.Add("EntityTakeDamage", "JintonBouclier_Absorbe", function(cible, dmg)
    if not cible:IsPlayer() then return end
    local reste = Bouclier(cible)
    if reste <= 0 then return end

    local degats = dmg:GetDamage()
    if degats <= 0 then return end

    local absorbe = math.min(degats, reste)
    dmg:SetDamage(degats - absorbe)
    reste = reste - absorbe
    cible:SetNW2Float("NA_Bouclier", reste)

    if reste <= 0 then
        NA_JintonBouclierFin(cible, true, true)   -- bouclier cassé : explosion
    else
        cible:EmitSound(string.format(SON_IMPACT, math.random(1, 4)), 65, 120, 0.5)
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "JintonBouclier_Mort", function(ply)
    enCours[ply] = nil
    NA_JintonBouclierFin(ply)
end)

hook.Add("PlayerSpawn", "JintonBouclier_Spawn", function(ply)
    NA_JintonBouclierFin(ply)
end)

hook.Add("PlayerDisconnected", "JintonBouclier_Nettoyage", function(ply)
    NA_JintonBouclierFin(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
