--========================================================
-- Bakuton : Mignons d'argile (SERVEUR)
-- Comme les serpents d'encre : on vise un ennemi (sinon ils avancent tout droit et prennent le premier
-- repéré). Les mignons partent un par un au sol (entité bakuton_mignon) et explosent au contact.
--
-- Réseau : "bakuton_mignons_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains"
--========================================================

util.AddNetworkString("bakuton_mignons_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 50     -- par mignon qui explose
local RAYON        = 130
local VITESSE      = 450
local ROTATION     = 220    -- degrés/s : plus c'est bas, plus la cible peut esquiver
local DUREE_VIE    = 4
local DETECTION    = 500    -- rayon de détection quand il n'y a pas de cible visée
local NOMBRE       = 3
local DECALAGE     = 0.3    -- secondes entre le départ de deux mignons
local ECART        = 40
local DEVANT       = 60
local RECHARGE     = 12
local CHAKRA_COUT  = 30
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DELAI        = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local ID = "bakuton_mignons"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/atg_mignon_argile." .. ext)
end
for _, f in ipairs({ "atg/pvp/bakuton/atg_mignon/atg_mignon.vmt", "atg/pvp/bakuton/atg_mignon/atg_mignon.vtf",
                     "atg/pvp/bakuton/atg_mignon/atg_outline.vmt", "atg/pvp/bakuton/atg_mignon/atg_outline.vtf",
                     "atg_props/shared/normal.vtf", "atg_props/shared/lightwarpshader_bakuton.vtf" }) do
    resource.AddFile("materials/" .. f)
end

local pret = {}

local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end
    local nombre = Niv(ply, "nombre", NOMBRE)

    for i = 1, nombre do
        timer.Simple((i - 1) * Niv(ply, "decalage", DECALAGE), function()
            if not IsValid(ply) or not ply:Alive() then return end
            -- direction prise au départ de CHAQUE mignon : ils vont là où tu regardes à ce moment-là
            local yaw = ply:EyeAngles().y
            local ang = Angle(0, yaw, 0)
            local ent = ents.Create("bakuton_mignon")
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

net.Receive("bakuton_mignons_cast", function(_, ply)
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

    NA_AnimJutsu(ply, ANIM_LANCER)
    local mudra = Niv(ply, "duree_mudra", 0)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    timer.Simple(math.max(mudra, Niv(ply, "delai", DELAI)), function() Lancer(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "BakutonMignons_Nettoyage", function(ply) pret[ply] = nil end)
