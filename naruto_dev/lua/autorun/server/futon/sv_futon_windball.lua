--========================================================
-- Futon : Wind Ball (SERVEUR)
--
-- Après une courte incantation, lance une boule de vent (entité futon_windball,
-- lua/entities) droit devant : à l'impact, dégâts, particule solve_futon_bump_01 et
-- projection de la cible touchée.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("futon_windball_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 25     -- dégâts à l'impact
local VITESSE      = 1500   -- unités par seconde
local DUREE_VIE    = 2      -- secondes avant que la boule disparaisse
local HITBOX       = 30     -- demi-largeur de la zone qui touche (à l'horizontale)
local HITBOX_HAUT  = 30     -- demi-hauteur de la zone qui touche : baisse-la pour une hitbox plus basse
local ECHELLE      = 0.5    -- taille du modèle (1 = boule de 116 unités de large)
local RECUL        = 600    -- projection de la cible touchée, dans le sens du tir (0 = aucune)
local SOULEVE      = 250    -- projection vers le haut
local RECHARGE     = 6      -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"   -- mudras
local ANIM_LANCER  = "nrp_ninjutsu_trow_fireball_lv3"                -- geste de lancer : celui de la boule de feu
local DELAI_LANCER = 0.3    -- secondes entre le début du geste de lancer et le départ de la boule
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "futon_windball", stat, base) end

-- particule d'impact (solve_futon_bump_01)
resource.AddFile("particles/solve_futon.pcf")
game.AddParticles("particles/solve_futon.pcf")
PrecacheParticleSystem("solve_futon_bump_01")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- la direction est celle du regard AU MOMENT du départ, pas de l'appui
    local aim = ply:GetAimVector()

    local ent = ents.Create("futon_windball")
    if not IsValid(ent) then return end

    ent:SetPos(ply:EyePos() + aim * 40)
    ent:SetOwner(ply)
    ent.Direction = aim
    ent.Vitesse  = Niv(ply, "vitesse", VITESSE)
    ent.Degats   = Niv(ply, "degats", DEGATS)
    ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Rayon    = Niv(ply, "hitbox", HITBOX)
    ent.RayonHaut = Niv(ply, "hitbox_haut", HITBOX_HAUT)
    ent.Echelle  = Niv(ply, "echelle", ECHELLE)
    ent.Recul    = Niv(ply, "recul", RECUL)
    ent.Souleve  = Niv(ply, "souleve", SOULEVE)
    ent:Spawn()

    ply:EmitSound("naruto_sound/jutsu/futon/futon12.wav", 75, 100)
end

net.Receive("futon_windball_cast", function(_, ply)
    if not NA_Debloquee(ply, "futon_windball") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "futon_windball", recharge) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    -- comme la boule de feu : mudras, puis geste de lancer, puis départ de la boule
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then enCours[ply] = nil return end
        NA_AnimJutsu(ply, ANIM_LANCER)   -- animation + pas de coups pendant (_na_mudra.lua)
        timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function()
            enCours[ply] = nil
            Lancer(ply)
        end)
    end)
end)

hook.Add("PlayerDisconnected", "FutonWindball_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
