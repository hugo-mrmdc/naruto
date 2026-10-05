--========================================================
-- Doton : Boule de roche (SERVEUR)
--
-- Après une courte incantation, lance un rocher (entité doton_pierre, lua/entities) droit devant :
-- il blesse le premier ennemi touché et le projette.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("doton_pierre_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 40     -- dégâts à l'impact
local VITESSE      = 1300   -- unités par seconde
local DUREE_VIE    = 2      -- secondes avant que le rocher disparaisse
local HITBOX       = 22     -- demi-largeur de la zone qui touche
local HITBOX_HAUT  = 22     -- demi-hauteur de la zone qui touche
local ECHELLE      = 0.45   -- taille du modèle (1 = boule de ~94 unités de large)
local RECUL        = 500    -- projection de la cible touchée, dans le sens du tir (0 = aucune)
local SOULEVE      = 200    -- projection vers le haut
local RECHARGE     = 8      -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.6    -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"   -- mudras
local ANIM_LANCER  = "nrp_ninjutsu_trow_fireball_lv3"                -- geste de lancer
local DELAI_LANCER = 0.3    -- secondes entre le début du geste de lancer et le départ du rocher
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "doton_pierre", stat, base) end

resource.AddFile("particles/atg_particules3.pcf")
game.AddParticles("particles/atg_particules3.pcf")
PrecacheParticleSystem("atg_boule_roche_explo")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local aim = ply:GetAimVector()   -- direction du regard AU MOMENT du départ
    local ent = ents.Create("doton_pierre")
    if not IsValid(ent) then return end

    ent:SetPos(ply:EyePos() + aim * 50)
    ent:SetOwner(ply)
    ent.Direction = aim
    ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
    ent.Degats    = Niv(ply, "degats", DEGATS)
    ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Rayon     = Niv(ply, "hitbox", HITBOX)
    ent.RayonHaut = Niv(ply, "hitbox_haut", HITBOX_HAUT)
    ent.Echelle   = Niv(ply, "echelle", ECHELLE)
    ent.Recul     = Niv(ply, "recul", RECUL)
    ent.Souleve   = Niv(ply, "souleve", SOULEVE)
    ent:Spawn()

    ply:EmitSound("naruto_sound/jutsu/doton/earth10.wav", 75, 90)
end

net.Receive("doton_pierre_cast", function(_, ply)
    if not NA_Debloquee(ply, "doton_pierre") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "doton_pierre", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    -- mudras, puis geste de lancer, puis départ du rocher
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then enCours[ply] = nil return end
        NA_AnimJutsu(ply, ANIM_LANCER)
        timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function()
            enCours[ply] = nil
            Lancer(ply)
        end)
    end)
end)

hook.Add("PlayerDisconnected", "DotonPierre_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
