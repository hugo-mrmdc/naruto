--========================================================
-- Hyoton : Loups de glace (SERVEUR)
-- On vise un ennemi (visée des singes : NA_InkutonCible). Après les mudras, des
-- loups partent un par un au sol et essaient de rattraper la cible (entité hyoton_loup) : ils ne
-- s'accrochent pas, un contact = des dégâts. Un mur les arrête, une cible qui change de direction peut
-- leur échapper.
--
-- Réseau : "hyoton_loup_cast" (client -> serveur) 
--========================================================

util.AddNetworkString("hyoton_loup_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 45     -- par loup qui touche
local VITESSE      = 700
local ROTATION     = 220    -- degrés/s : plus c'est bas, plus la cible peut esquiver
local DUREE_VIE    = 3
local DETECTION    = 500    -- rayon de détection quand il n'y a pas de cible visée
local NOMBRE       = 2
local DECALAGE     = 0.25   -- secondes entre le départ de deux loups
local ECART        = 40
local DEVANT       = 60
local RECHARGE     = 14
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_LANCER  = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "hyoton_loup"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end

    local nombre = Niv(ply, "nombre", NOMBRE)
    local ecart = Niv(ply, "ecart", ECART)
    local decalage = Niv(ply, "decalage", DECALAGE)

    for i = 1, nombre do
        timer.Simple((i - 1) * decalage, function()
            if not IsValid(ply) or not ply:Alive() then return end
            -- direction prise au départ de CHAQUE loup : ils vont là où tu regardes à ce moment-là
            local yaw = ply:EyeAngles().y
            local avant = Angle(0, yaw, 0):Forward()
            local droite = Angle(0, yaw, 0):Right()
            local base = ply:GetPos() + avant * Niv(ply, "devant", DEVANT)
            local ent = ents.Create("hyoton_loup")
            if not IsValid(ent) then return end
            ent:SetPos(base + droite * (i - (nombre + 1) / 2) * ecart)
            ent:SetAngles(Angle(0, yaw, 0))
            ent:SetOwner(ply)
            ent.Cible    = IsValid(cible) and cible or nil   -- nil : il avance tout droit et cherche
            ent.Detection = Niv(ply, "detection", DETECTION)
            ent.Vitesse  = Niv(ply, "vitesse", VITESSE)
            ent.Rotation = Niv(ply, "rotation", ROTATION)
            ent.Degats   = Niv(ply, "degats", DEGATS)
            ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
            ent:Spawn()
        end)
    end
end

net.Receive("hyoton_loup_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    -- cible visée si il y en a une ; sinon les loups avancent tout droit et prennent le premier ennemi repéré
    local cible = NA_InkutonCible and NA_InkutonCible(ply, ID)

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_LANCER)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Lancer(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "HyotonLoup_Nettoyage", function(ply) pret[ply] = nil end)
