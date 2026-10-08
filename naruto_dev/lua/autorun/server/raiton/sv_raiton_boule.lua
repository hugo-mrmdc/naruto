--========================================================
-- Raiton : Boule de foudre (SERVEUR)
--
-- Après une courte incantation, lance une boule de foudre (entité raiton_ball, lua/entities)
-- droit devant : elle blesse et étourdit le premier ennemi touché (NA_Etourdir, sv_etourdissement.lua).
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_boule_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 30     -- dégâts à l'impact
local DUREE        = 1.5    -- secondes d'étourdissement
local VITESSE      = 1300   -- unités par seconde
local DUREE_VIE    = 2      -- secondes avant que la boule disparaisse
local HITBOX       = 30     -- demi-largeur de la zone qui touche
local HITBOX_HAUT  = 30     -- demi-hauteur de la zone qui touche
local RECHARGE     = 10     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.3  -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"   -- mudras
local ANIM_LANCER  = "nrp_ninjutsu_attack_d63nj3_cmb00_f"            -- geste de lancer
local DELAI_LANCER = 0.3    -- secondes entre le début du geste de lancer et le départ de la boule
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "raiton_boule", stat, base) end

resource.AddFile("particles/solve_raiton.pcf")
game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_ball_small")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local aim = ply:GetAimVector()   -- direction du regard AU MOMENT du départ
    local ent = ents.Create("raiton_ball")
    if not IsValid(ent) then return end

    ent:SetPos(ply:EyePos() + aim * 40)
    ent:SetOwner(ply)
    ent.Direction = aim
    ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
    ent.Degats    = Niv(ply, "degats", DEGATS)
    ent.Duree     = Niv(ply, "duree", DUREE)
    ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Rayon     = Niv(ply, "hitbox", HITBOX)
    ent.RayonHaut = Niv(ply, "hitbox_haut", HITBOX_HAUT)
    ent:Spawn()

    ply:EmitSound("naruto_sound/jutsu/raiton/raiton1.wav", 75, 110)
end

net.Receive("raiton_boule_cast", function(_, ply)
    if not NA_Debloquee(ply, "raiton_boule") then return end   -- technique pas encore débloquée (F6)
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
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "raiton_boule", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    -- mudras, puis geste de lancer, puis départ de la boule
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then enCours[ply] = nil return end
        NA_AnimJutsu(ply, ANIM_LANCER)
        timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function()
            enCours[ply] = nil
            Lancer(ply)
        end)
    end)
end)

hook.Add("PlayerDisconnected", "RaitonBoule_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
