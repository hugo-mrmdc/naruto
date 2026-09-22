--========================================================
-- Kiminari : Prison noire (SERVEUR)
--
-- Une zone électrique apparaît AUTOUR DU LANCEUR pendant DUREE secondes, avec
-- la particule [3]_electric_tornado (particles/atg_faris.pcf) sur lui.
-- SUIT = true : la zone le suit ; false : elle reste où il l'a lancée.
-- Tout ennemi qui FRANCHIT le bord de la zone (il entre OU il sort) prend des
-- dégâts et est étourdi DUREE_STUN secondes (NA_Etourdir, sv_etourdissement.lua).
-- Ceux qui restent dedans ou dehors sans franchir le bord ne prennent rien.
--
-- Réseau : "kiminari_prison_zone" (lanceur + position + suit + durée)
--          "kiminari_prison_fx"   (entité étourdie + durée)
--          -> cl_kiminari_prison.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("kiminari_prison_cast")
util.AddNetworkString("kiminari_prison_zone")
util.AddNetworkString("kiminari_prison_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 8      -- secondes de présence de la zone
local INTERVALLE   = 0.1    -- secondes entre deux vérifications du bord

local SUIT         = false  -- true = la zone suit le lanceur, false = elle reste sur place
local RAYON        = 250    -- rayon de la zone (developer 1 pour la voir)
local HAUTEUR      = 250    -- hauteur de la zone au-dessus du sol

local DEGATS       = 12     -- dégâts à chaque franchissement du bord
local DUREE_STUN   = 1.5    -- secondes d'étourdissement
local IMMUNITE     = 1      -- secondes sans nouvel étourdissement APRÈS la fin du précédent

local RECHARGE     = 24     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la zone
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "ambient/energy/zap9.wav"
local SON_BOUCLE   = "ambient/energy/electric_loop.wav"
local SON_TOUCHE   = "ambient/energy/spark%d.wav"   -- %d = 1 à 6
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kiminari_prison", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Cylindre : assez près à l'horizontale, et entre le sol et le haut de la zone
local function Dedans(ent, centre, rayon, hauteur)
    local pos = ent:GetPos()
    local ecart = Vector(pos.x - centre.x, pos.y - centre.y, 0):Length()
    return ecart <= rayon and pos.z + ent:OBBMaxs().z >= centre.z - 20 and pos.z <= centre.z + hauteur
end

local function Frapper(ply, ent, zone)
    local now = CurTime()
    if (zone.immunite[ent] or 0) > now then return end
    zone.immunite[ent] = now + zone.stun + zone.imm

    local dmg = DamageInfo()
    dmg:SetDamage(NA_Stat(ply, "kiminari_prison", "degats", DEGATS))
    dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
    dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
    dmg:SetDamageType(DMG_SHOCK)
    dmg:SetDamagePosition(ent:WorldSpaceCenter())
    ent:TakeDamageInfo(dmg)

    if NA_Etourdir then NA_Etourdir(ent, zone.stun) end
    ent:EmitSound(string.format(SON_TOUCHE, math.random(1, 6)), 75, math.random(95, 110), 0.8)

    net.Start("kiminari_prison_fx")
        net.WriteEntity(ent)
        net.WriteFloat(zone.stun)
    net.Broadcast()
end

local function Tick(ply, zone)
    if zone.suit then zone.centre = ply:GetPos() end
    local vus = {}
    local centreSphere = zone.centre + Vector(0, 0, zone.hauteur / 2)
    for _, ent in ipairs(ents.FindInSphere(centreSphere, zone.rayon + zone.hauteur + 100)) do
        if not EstCible(ent, ply) then continue end
        vus[ent] = true

        local dedans = Dedans(ent, zone.centre, zone.rayon, zone.hauteur)
        local avant = zone.etat[ent]
        zone.etat[ent] = dedans
        -- avant == nil : première fois qu'on le voit, on note juste où il est
        if avant ~= nil and avant ~= dedans then Frapper(ply, ent, zone) end
    end

    -- sorti de la sphère de recherche : forcément dehors
    for ent, dedans in pairs(zone.etat) do
        if vus[ent] then continue end
        zone.etat[ent] = nil
        if dedans and EstCible(ent, ply) then Frapper(ply, ent, zone) end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(zone.centre, zone.rayon, INTERVALLE, Color(120, 180, 255, 15), true)
    end
end

local function Lancer(ply)
    if not IsValid(ply) then return end
    local centre = ply:GetPos()

    local duree = Niv(ply, "duree", DUREE)
    local zone = {
        centre   = centre,
        rayon    = Niv(ply, "rayon", RAYON),
        hauteur  = Niv(ply, "hauteur", HAUTEUR),
        suit     = SUIT,
        stun     = Niv(ply, "duree_stun", DUREE_STUN),
        imm      = Niv(ply, "immunite", IMMUNITE),
        etat     = {},   -- ent -> true (dedans) / false (dehors)
        immunite = {},   -- ent -> CurTime avant lequel il ne peut plus être étourdi
    }

    net.Start("kiminari_prison_zone")
        net.WriteEntity(ply)
        net.WriteVector(centre)
        net.WriteBool(SUIT)
        net.WriteFloat(duree)
    net.Broadcast()

    sound.Play(SON_DEBUT, centre + Vector(0, 0, 40), 90, 100, 1)

    -- son de la zone : porté par une entité invisible pour pouvoir le couper
    local haut = ents.Create("info_target")
    if IsValid(haut) then
        haut:SetPos(centre + Vector(0, 0, 40))
        haut:Spawn()
        if SUIT then haut:SetParent(ply) end
        haut:EmitSound(SON_BOUCLE, 75, 110, 0.6)
    end

    Tick(ply, zone)   -- état de départ : qui est dedans, qui est dehors

    local fin = CurTime() + duree
    local nom = "kiminari_prison_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(nom, Niv(ply, "intervalle", INTERVALLE), 0, function()
        if CurTime() >= fin or not IsValid(ply) or (SUIT and not ply:Alive()) then
            timer.Remove(nom)
            if IsValid(haut) then
                haut:StopSound(SON_BOUCLE)
                haut:Remove()
            end
            return
        end
        Tick(ply, zone)
    end)
end

net.Receive("kiminari_prison_cast", function(_, ply)
    if not NA_Debloquee(ply, "kiminari_prison") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = NA_Stat(ply, "kiminari_prison", "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "kiminari_prison", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kiminari_prison", NA_Stat(ply, "kiminari_prison", "recharge", RECHARGE)) end   -- recharge visible dans la barre

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

hook.Add("PlayerDisconnected", "KiminariPrison_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
