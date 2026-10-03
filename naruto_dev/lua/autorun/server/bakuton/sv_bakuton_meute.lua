--========================================================
-- Bakuton : Meute d'araignées (SERVEUR)
-- Comme les serpents d'encre : on vise un ennemi (sinon elles avancent tout droit et prennent le premier
-- repéré). Les araignées partent une par une au sol (entité bakuton_araignee_meute) et explosent au contact.
--
-- Réseau : "bakuton_meute_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains"
--========================================================

util.AddNetworkString("bakuton_meute_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 35     -- par araignée qui explose
local RAYON        = 110
local VITESSE      = 650
local ROTATION     = 220    -- degrés/s : plus c'est bas, plus la cible peut esquiver
local DUREE_VIE    = 4
local DETECTION    = 500    -- rayon de détection quand il n'y a pas de cible visée
local NOMBRE       = 5
local DECALAGE     = 0.15   -- secondes entre le départ de deux araignées
local ECART        = 30
local DEVANT       = 60
local RECHARGE     = 12
local CHAKRA_COUT  = 30
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DELAI        = 0.6
local ANIM_LANCER  = "nrp_ninjutsu_defend_mudwall"
--========================================================

local ID = "bakuton_meute"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/atg_araignee_bakuton." .. ext)
end
for _, f in ipairs({ "atg_araignee_bakuton.vmt", "atg_araignee_bakuton.vtf", "atg_outline.vmt", "atg_outline.vtf" }) do
    resource.AddFile("materials/atg/pvp/bakuton/atg_araignee/" .. f)
end
resource.AddFile("materials/atg_props/shared/lightwarpshader_bakuton.vtf")

local pret = {}

local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end
    local nombre = Niv(ply, "nombre", NOMBRE)

    for i = 1, nombre do
        timer.Simple((i - 1) * Niv(ply, "decalage", DECALAGE), function()
            if not IsValid(ply) or not ply:Alive() then return end
            -- direction prise au départ de CHAQUE araignée : ils vont là où tu regardes à ce moment-là
            local yaw = ply:EyeAngles().y
            local ang = Angle(0, yaw, 0)
            local ent = ents.Create("bakuton_araignee_meute")
            if not IsValid(ent) then return end
            ent:SetPos(ply:GetPos() + ang:Forward() * Niv(ply, "devant", DEVANT) + ang:Right() * (i - (nombre + 1) / 2) * Niv(ply, "ecart", ECART))
            ent:SetAngles(ang)
            ent:SetOwner(ply)
            ent.Cible     = IsValid(cible) and cible or nil
            ent.Detection = Niv(ply, "detection", DETECTION)
            ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
            ent.Rotation  = Niv(ply, "rotation", ROTATION)
            ent.Degats    = Niv(ply, "degats", DEGATS)
            ent.Rayon     = Niv(ply, "rayon", RAYON)
            ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
            ent:Spawn()
        end)
    end
end

net.Receive("bakuton_meute_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cible = NA_InkutonCible and NA_InkutonCible(ply, ID)   -- visée des singes (sv_inkuton_singes.lua)

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

    NA_AnimJutsu(ply, ANIM_LANCER, 0, 3)   -- x3 plus vite
    local mudra = Niv(ply, "duree_mudra", 0)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    timer.Simple(math.max(mudra, Niv(ply, "delai", DELAI)), function() Lancer(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "BakutonMeute_Nettoyage", function(ply) pret[ply] = nil end)
