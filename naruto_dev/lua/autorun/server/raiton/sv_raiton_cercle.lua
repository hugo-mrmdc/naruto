--========================================================
-- Raiton : Cercle de foudre (SERVEUR)
--
-- Après une courte incantation, un cercle de foudre se déploie autour du lanceur, là où il se
-- tient : la particule izox_raiton_circle_deux (particles/1izoxsolvenr.pcf) est jouée à chaque
-- impulsion, et à chaque impulsion tout ennemi dans le rayon prend des dégâts et est REPOUSSÉ
-- vers l'extérieur du cercle (et un peu vers le haut). Le cercle COLLE au lanceur : il le suit
-- (particule et zone de dégâts) s'il se déplace pendant les impulsions.
-- Particule affichée par cl_raiton_cercle.lua (message "raiton_cercle_fx").
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_cercle_cast")
util.AddNetworkString("raiton_cercle_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local RAYON        = 320    -- rayon du cercle (developer 1 pour le voir ; la particule fait ~300 en fin d'expansion)
local IMPULSIONS   = 3      -- nombre d'impulsions (chacune joue la particule, blesse et repousse)
local INTERVALLE   = 0.8    -- secondes entre deux impulsions
local DEGATS       = 12     -- dégâts par impulsion
local RECUL        = 700    -- projection vers l'extérieur du cercle, à chaque impulsion (0 = aucune)
local SOULEVE      = 250    -- projection vers le haut
local RECHARGE     = 15     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la première impulsion
local DUREE_FX     = 1.5    -- secondes de la particule après chaque impulsion
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_COUPE   = 0.6    -- l'animation de mudras est coupée après ces secondes (0 = entière)
local SON_IMPULSION = "naruto_sound/jutsu/raiton/raiton1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "raiton_cercle", stat, base) end

resource.AddFile("particles/1izoxsolvenr.pcf")
game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem("izox_raiton_circle_deux")

local enCours = {}   -- joueur -> true tant que le cercle est actif
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Une impulsion : particule chez tout le monde, dégâts et projection vers l'extérieur.
-- Le cercle est centré sur le lanceur AU MOMENT de l'impulsion (il le suit).
local function Impulsion(ply, rayon, degats, recul, souleve)
    if not IsValid(ply) or not ply:Alive() then return end
    local centre = ply:GetPos() + Vector(0, 0, 10)
    sound.Play(SON_IMPULSION, centre, 95, math.random(90, 110), 1)

    net.Start("raiton_cercle_fx")
        net.WriteEntity(ply)   -- la particule est accrochée au lanceur
        net.WriteFloat(DUREE_FX)
    net.Broadcast()

    for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
        dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        -- expulsé vers l'extérieur du cercle, et un peu vers le haut
        local sortie = ent:GetPos() - centre
        sortie.z = 0
        if sortie:LengthSqr() < 1 then sortie = VectorRand() sortie.z = 0 end
        local vel = sortie:GetNormalized() * recul + Vector(0, 0, souleve)
        if ent.loco then
            ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
        else
            ent:SetVelocity(vel)
        end

        ent:EmitSound("naruto_sound/jutsu/raiton/raiton2.wav", 75, math.random(95, 110), 0.8)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(centre, rayon, 1, Color(120, 180, 255, 15), true)
    end
end

net.Receive("raiton_cercle_cast", function(_, ply)
    if not NA_Debloquee(ply, "raiton_cercle") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
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
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local nombre = math.floor(Niv(ply, "impulsions", IMPULSIONS))
    local pause = Niv(ply, "intervalle", INTERVALLE)
    local recharge = Niv(ply, "recharge", RECHARGE)

    -- la recharge démarre après la dernière impulsion
    local total = mudra + pause * math.max(nombre - 1, 0) + recharge
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "raiton_cercle", total) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL, ANIM_COUPE)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    local rayon   = Niv(ply, "rayon", RAYON)
    local degats  = Niv(ply, "degats", DEGATS)
    local recul   = Niv(ply, "recul", RECUL)
    local souleve = Niv(ply, "souleve", SOULEVE)

    for i = 0, nombre - 1 do
        timer.Simple(mudra + pause * i, function()
            Impulsion(ply, rayon, degats, recul, souleve)
        end)
    end
    timer.Simple(mudra + pause * math.max(nombre - 1, 0), function() enCours[ply] = nil end)
end)

hook.Add("PlayerDisconnected", "RaitonCercle_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
