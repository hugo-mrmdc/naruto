--========================================================
-- Jiton : Tornade de sable (SERVEUR)
--
-- Après les mudras, une tornade de sable (entité jiton_tornade, particule
-- [1]_sand_tornado, particles/atg_faris.pcf) part TOUT DROIT devant le lanceur,
-- collée au sol. Elle blesse une fois chaque ennemi qu'elle traverse et le
-- projette en l'air, jusqu'à un mur ou la fin de sa durée de vie.
--
-- Tout le comportement de la tornade est dans lua/entities/jiton_tornade.lua.
--========================================================

if not SERVER then return end

util.AddNetworkString("jiton_tornade_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
-- (valeurs du niveau 1, remplacées par celles de _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 25     -- dégâts, une seule fois par ennemi
local VITESSE      = 600    -- vitesse de la tornade (unités / seconde)
local DUREE        = 2.5    -- durée de vie : distance parcourue = VITESSE x DUREE
local RAYON        = 110    -- zone qui blesse (developer 1 pour la voir)
local HAUTEUR      = 220
local PROJECTION   = 350    -- vitesse vers le haut donnée à l'ennemi touché

local RECHARGE     = 24     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 40     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la tornade
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jiton_tornade", stat, base) end

local enCours = {}
local pret    = {}

local function Lancer(ply)
    if not IsValid(ply) then return end

    local dir = Angle(0, ply:EyeAngles().y, 0):Forward()   -- tout droit, à plat
    local ent = ents.Create("jiton_tornade")
    if not IsValid(ent) then return end

    ent:SetPos(ply:GetPos() + dir * 60)
    ent:SetOwner(ply)
    ent.Direction  = dir
    ent.Vitesse    = Niv(ply, "vitesse", VITESSE)
    ent.DureeVie   = Niv(ply, "duree", DUREE)
    ent.Rayon      = Niv(ply, "rayon", RAYON)
    ent.Hauteur    = Niv(ply, "hauteur", HAUTEUR)
    ent.Degats     = Niv(ply, "degats", DEGATS)
    ent.Projection = Niv(ply, "projection", PROJECTION)
    ent:Spawn()
end

net.Receive("jiton_tornade_cast", function(_, ply)
    if not NA_Debloquee(ply, "jiton_tornade") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "jiton_tornade", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Lancer(ply)
    end)
end)

hook.Add("PlayerDeath", "JitonTornade_Mort", function(ply)
    enCours[ply] = nil
end)

hook.Add("PlayerDisconnected", "JitonTornade_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
