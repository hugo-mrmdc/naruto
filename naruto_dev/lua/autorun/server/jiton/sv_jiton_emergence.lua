--========================================================
-- Jiton : Émergence de sable (SERVEUR)
--
-- Après les mudras, le sable jaillit du sol AUTOUR DU LANCEUR
-- (particule [1]_sand_emergence, particles/atg_faris.pcf) et la zone reste
-- DUREE secondes. SUIT = true : la zone le suit ; false : elle reste où il
-- l'a lancée. Tout ennemi qui se tient dedans, à chaque tick :
--   - prend des dégâts ;
--   - est ralenti (hook "Move" dans jiton_init.lua, il dure un peu plus qu'un
--     tick : le ralenti reste tant qu'il est dans la zone, et s'arrête juste
--     après qu'il en soit sorti).
-- Le ralenti ne touche que les joueurs (comme la Pluie de sang Chinoike).
--
-- Réseau : "jiton_emergence_zone" (lanceur + position + suit + durée) -> cl_jiton_emergence.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("jiton_emergence_cast")
util.AddNetworkString("jiton_emergence_zone")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 6      -- secondes de présence de la zone
local INTERVALLE   = 0.5    -- secondes entre deux ticks

local SUIT         = false  -- true = la zone suit le lanceur, false = elle reste sur place
local RAYON        = 200    -- rayon de la zone qui touche (developer 1 pour la voir)
local HAUTEUR      = 150    -- hauteur de la zone au-dessus du sol

local DEGATS       = 8      -- dégâts par tick et par ennemi
local RALENTI      = 0.6    -- vitesse des ennemis dans la zone (1 = pas de ralenti)

local RECHARGE     = 18     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la zone
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "naruto_sound/jutsu/jishaku/jishaku4.wav"
local SON_TICK     = "naruto_sound/jutsu/jishaku/jishaku5.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jiton_emergence", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Tick(ply, zone)
    if zone.suit then zone.centre = ply:GetPos() end
    for _, ent in ipairs(ents.FindInSphere(zone.centre + Vector(0, 0, zone.hauteur / 2), zone.rayon + zone.hauteur)) do
        if not EstCible(ent, ply) then continue end

        -- cylindre : assez près à l'horizontale, et entre le sol et le haut de la zone
        local pos = ent:GetPos()
        local ecart = Vector(pos.x - zone.centre.x, pos.y - zone.centre.y, 0):Length()
        local haut = pos.z + ent:OBBMaxs().z
        if ecart > zone.rayon or haut < zone.centre.z - 20 or pos.z > zone.centre.z + zone.hauteur then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(zone.degats)
        dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
        dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
        dmg:SetDamageType(DMG_CRUSH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(SON_TICK, 70, math.random(90, 110), 0.6)

        -- ralenti tant qu'il reste dans la zone
        if zone.ralenti < 1 and ent:IsPlayer() then
            ent:SetNW2Float("NA_JitonEmergenceFin", CurTime() + zone.intervalle + 0.1)
            ent:SetNW2Float("NA_JitonEmergenceRalenti", zone.ralenti)   -- ralenti au niveau du LANCEUR
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(zone.centre + Vector(0, 0, zone.hauteur / 2), zone.rayon, zone.intervalle, Color(220, 180, 90, 20), true)
    end
end

local function Lancer(ply)
    if not IsValid(ply) then return end

    local centre = ply:GetPos()
    local duree = Niv(ply, "duree", DUREE)
    local zone = {
        centre     = centre,
        suit       = SUIT,
        rayon      = Niv(ply, "rayon", RAYON),
        hauteur    = Niv(ply, "hauteur", HAUTEUR),
        degats     = Niv(ply, "degats", DEGATS),
        ralenti    = Niv(ply, "ralenti", RALENTI),
        intervalle = Niv(ply, "intervalle", INTERVALLE),
    }

    net.Start("jiton_emergence_zone")
        net.WriteEntity(ply)
        net.WriteVector(centre)
        net.WriteBool(SUIT)
        net.WriteFloat(duree)
    net.Broadcast()

    sound.Play(SON_DEBUT, centre + Vector(0, 0, 20), 85, 90, 1)

    local fin = CurTime() + duree
    local nom = "jiton_emergence_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(nom, zone.intervalle, 0, function()
        if CurTime() >= fin or not IsValid(ply) or (SUIT and not ply:Alive()) then
            timer.Remove(nom)
            return
        end
        Tick(ply, zone)
    end)
end

net.Receive("jiton_emergence_cast", function(_, ply)
    if not NA_Debloquee(ply, "jiton_emergence") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "jiton_emergence", recharge) end   -- recharge visible dans la barre

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

hook.Add("PlayerDeath", "JitonEmergence_Mort", function(ply)
    enCours[ply] = nil
end)

hook.Add("PlayerDisconnected", "JitonEmergence_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
