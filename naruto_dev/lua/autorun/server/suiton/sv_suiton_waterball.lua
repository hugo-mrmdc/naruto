--========================================================
-- Suiton : Boule d'eau (SERVEUR)
--
-- Après une courte incantation, lance une boule d'eau (entité suiton_waterball,
-- lua/entities) droit devant : dégâts et projection à l'impact.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_waterball_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 30     -- dégâts à l'impact
local VITESSE      = 1400   -- unités par seconde
local DUREE_VIE    = 2      -- secondes avant que la boule disparaisse
local HITBOX       = 22     -- demi-taille de la zone qui touche
local ECHELLE      = 0.5    -- taille du modèle (1 = rayon d'environ 65 unités)
local RECUL        = 350    -- projection de la cible touchée (0 = aucune)
local ANGLE_MODELE = Angle(0, 180, 0)   -- rotation du modèle par rapport à sa direction : sa "queue" est vers +X
local RECHARGE     = 6      -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.6    -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "suiton_waterball", stat, base) end

-- particule d'impact (jet_eau_hit_pat)
game.AddParticles("particles/atg_particules2.pcf")
PrecacheParticleSystem("jet_eau_hit_pat")
resource.AddFile("particles/atg_particules2.pcf")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- la direction est celle du regard AU MOMENT du départ, pas de l'appui
    local aim = ply:GetAimVector()

    local ent = ents.Create("suiton_waterball")
    if not IsValid(ent) then return end

    ent:SetPos(ply:EyePos() + aim * 40)
    ent:SetAngles(aim:Angle() + ANGLE_MODELE)
    ent:SetOwner(ply)
    ent.Direction = aim
    ent.Vitesse  = Niv(ply, "vitesse", VITESSE)
    ent.Degats   = Niv(ply, "degats", DEGATS)
    ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Rayon    = Niv(ply, "hitbox", HITBOX)
    ent.Echelle  = Niv(ply, "echelle", ECHELLE)
    ent.Recul    = Niv(ply, "recul", RECUL)
    ent:Spawn()

    ply:EmitSound("naruto_sound/jutsu/senju/senju1.wav", 75, 100)
end

net.Receive("suiton_waterball_cast", function(_, ply)
    if not NA_Debloquee(ply, "suiton_waterball") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

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
    if NA_CD then NA_CD.Set(ply, "suiton_waterball", recharge) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDisconnected", "SuitonWaterball_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
