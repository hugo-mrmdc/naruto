--========================================================
-- Futon : Wind Slash (SERVEUR)
--
-- Après une courte incantation, lance une lame de vent (entité futon_windslash,
-- lua/entities) droit devant : dégâts à l'impact.
-- Le serveur décide de tout : incantation, recharge, chakra, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("futon_windslash_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 35     -- dégâts à l'impact
local VITESSE      = 1800   -- unités par seconde
local DUREE_VIE    = 1.5    -- secondes avant que la lame disparaisse
local HITBOX       = 40     -- demi-taille de la zone qui touche (le croissant fait ~190 de large)
local HITBOX_HAUT  = 15     -- demi-hauteur de la zone qui touche (la lame est plate)
local ECHELLE      = 0.6    -- taille du modèle (1 = 187 unités de large)
local ROULIS       = 0      -- rotation de la lame autour de son axe de tir : 0 = à plat, 90 = debout
local RECHARGE     = 5      -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 20     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_attack_d55nj1"   -- animation du lancer (m_throw_d55nj1_ple_move)
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "futon_windslash", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- la direction est celle du regard AU MOMENT du départ, pas de l'appui
    local aim = ply:GetAimVector()

    local ent = ents.Create("futon_windslash")
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
    ent.Roulis   = Niv(ply, "roulis", ROULIS)
    ent:Spawn()

    ply:EmitSound("naruto_sound/jutsu/futon/futon12.wav", 75, 130)
end

net.Receive("futon_windslash_cast", function(_, ply)
    if not NA_Debloquee(ply, "futon_windslash") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "futon_windslash", recharge) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDisconnected", "FutonWindslash_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
