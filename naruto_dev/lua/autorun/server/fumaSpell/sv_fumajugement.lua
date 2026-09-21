--========================================================
-- Fuma : Jugement des Quatre Lames (SERVEUR)
--
-- Un fil d'acier part de la main vers là où on vise (entité fuma_fil).
-- S'il touche un ennemi : l'ennemi est étourdi, le fil reste tendu, et quatre
-- shurikens apparaissent au-dessus de lui, un de chaque côté, puis foncent sur
-- lui l'un après l'autre (entité fuma_quatre_lames).
-- S'il ne touche rien : le fil se rétracte.
--========================================================

if not SERVER then return end

util.AddNetworkString("fuma_jugement_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 1000   -- distance maximale du fil
local VITESSE_FIL   = 3000   -- unités / seconde
local HITBOX        = 18     -- demi-taille de la zone du fil qui accroche (developer 1 pour la voir)

local ETOURDI       = 2.5    -- secondes d'étourdissement de la cible
local DEGATS        = 20     -- dégâts de CHAQUE shuriken (x4)

local RECHARGE      = 18     -- secondes avant de pouvoir relancer (depuis le lancement)
local RECHARGE_RATE = 6      -- recharge si le fil ne touche rien
local CHAKRA_COUT   = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DELAI_LANCER  = 0.3    -- délai entre l'animation et le départ du fil
local ANIM_LANCER   = "nrp_ninjutsu_defend_d35nj2_throw"
local SON_LANCER    = "fuma/throw_1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "fuma_jugement", stat, base) end

local enCours = {}
local pret    = {}

local function Refus(ply, message)
    ply:PrintMessage(HUD_PRINTCENTER, message)
end

-- appelé par le fil (fuma_fil.lua) quand il accroche une cible
function NA_FumaJugementTouche(ply, cible)
    if not IsValid(ply) or not IsValid(cible) then return end
    if NA_Etourdir then NA_Etourdir(cible, Niv(ply, "etourdi", ETOURDI)) end

    local lames = ents.Create("fuma_quatre_lames")
    if not IsValid(lames) then return end
    lames.Degats = NA_Stat(ply, "fuma_jugement", "degats", DEGATS)
    lames:SetOwner(ply)
    lames:SetCible(cible)
    lames:SetPos(cible:GetPos())
    lames:Spawn()
end

-- appelé par le fil quand il ne touche rien
function NA_FumaJugementRate(ply)
    if not IsValid(ply) then return end
    pret[ply] = CurTime() + NA_Stat(ply, "fuma_jugement", "recharge_rate", RECHARGE_RATE)
    if NA_CD then NA_CD.Set(ply, "fuma_jugement", NA_Stat(ply, "fuma_jugement", "recharge_rate", RECHARGE_RATE)) end
end

net.Receive("fuma_jugement_cast", function(_, ply)
    if not NA_Debloquee(ply, "fuma_jugement") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "fuma_jugement", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "fuma_jugement", "chakra", CHAKRA_COUT) then return Refus(ply, "Pas assez de chakra") end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "fuma_jugement", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "fuma_jugement", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "fuma_jugement", NA_Stat(ply, "fuma_jugement", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_LANCER)   -- animation + pas de coups pendant (_na_mudra.lua)

    timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end

        ply:EmitSound(SON_LANCER, 75, 110)
        local fil = ents.Create("fuma_fil")
        if not IsValid(fil) then return end
        fil.Portee  = Niv(ply, "portee", PORTEE)
        fil.Vitesse = Niv(ply, "vitesse_fil", VITESSE_FIL)
        fil.Hitbox  = NA_Stat(ply, "fuma_jugement", "hitbox", HITBOX)
        fil.Accroche = Niv(ply, "etourdi", ETOURDI)
        fil.Direction = ply:GetAimVector()
        fil:SetOwner(ply)
        fil:SetPos(ply:GetShootPos())
        fil:Spawn()
    end)
end)

hook.Add("PlayerDisconnected", "FumaJugement_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
