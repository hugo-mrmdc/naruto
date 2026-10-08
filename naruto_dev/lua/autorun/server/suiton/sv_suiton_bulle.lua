--========================================================
-- Suiton : Bulles (SERVEUR)
--
-- Après une courte incantation, le joueur souffle une salve de bulles d'eau (entité
-- suiton_bulle, lua/entities) qui partent en éventail devant lui. Chaque bulle qui touche
-- un ennemi éclate et lui fait des dégâts : plus on en touche, plus ça fait mal.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoires.
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_bulle_cast")
util.AddNetworkString("suiton_bulle_pose")   -- serveur -> clients : animation du lanceur pendant la salve

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local NOMBRE       = 10     -- nombre de bulles de la salve
local DUREE_SALVE  = 0.7    -- secondes pendant lesquelles les bulles sont lancées (une après l'autre)
local DEGATS       = 8      -- dégâts par bulle qui touche
local VITESSE      = 550    -- unités par seconde (chaque bulle varie de ±20 %)
local DUREE_VIE    = 3      -- secondes avant qu'une bulle disparaisse
local HITBOX       = 26     -- demi-taille de la zone qui touche
local RECHARGE     = 8      -- secondes avant de pouvoir relancer (depuis la fin de la salve)
local CHAKRA_COUT  = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.6    -- incantation avant la salve
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "suiton_bulle", stat, base) end

game.AddParticles("particles/atg_particules.pcf")     -- atg_bulle_eau
game.AddParticles("particles/atg_particules2.pcf")    -- jet_eau_hit_pat (explosion, comme la boule d'eau)
PrecacheParticleSystem("atg_bulle_eau")
PrecacheParticleSystem("jet_eau_hit_pat")
resource.AddFile("particles/atg_particules.pcf")
resource.AddFile("particles/atg_particules2.pcf")

local enCours = {}   -- joueur -> true pendant l'incantation et la salve
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

-- Une bulle, TOUT DROIT dans la direction du regard du joueur AU MOMENT où elle part
local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local dir = ply:GetAimVector()
    local depart = ply:EyePos() + dir * 40

    local ent = ents.Create("suiton_bulle")
    if not IsValid(ent) then return end

    ent:SetPos(depart)
    ent:SetAngles(dir:Angle())
    ent:SetOwner(ply)
    ent.Direction = dir
    ent.Vitesse  = Niv(ply, "vitesse", VITESSE) * math.Rand(0.8, 1.2)
    ent.Degats   = Niv(ply, "degats", DEGATS)
    ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Rayon    = Niv(ply, "hitbox", HITBOX)
    ent:Spawn()
end

net.Receive("suiton_bulle_cast", function(_, ply)
    if not NA_Debloquee(ply, "suiton_bulle") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local nombre = math.floor(Niv(ply, "nombre", NOMBRE))
    local salve = Niv(ply, "duree_salve", DUREE_SALVE)
    local recharge = Niv(ply, "recharge", RECHARGE)

    -- la recharge démarre après la salve
    local total = mudra + salve + recharge
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "suiton_bulle", total) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra + salve) end   -- pas de coups pendant les mudras ni la salve

    -- même animation que le souffle katon pendant la salve (jouée par les clients : cl_suiton_bulle.lua)
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        net.Start("suiton_bulle_pose")
            net.WriteEntity(ply)
            net.WriteFloat(salve)
        net.Broadcast()
    end)

    -- les bulles partent l'une après l'autre pendant la salve
    for i = 0, nombre - 1 do
        timer.Simple(mudra + salve * (i / math.max(nombre - 1, 1)), function()
            Lancer(ply)
            if i == 0 and IsValid(ply) then ply:EmitSound("naruto_sound/jutsu/senju/senju1.wav", 75, 120) end
        end)
    end
    timer.Simple(mudra + salve, function() enCours[ply] = nil end)
end)

hook.Add("PlayerDisconnected", "SuitonBulle_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
