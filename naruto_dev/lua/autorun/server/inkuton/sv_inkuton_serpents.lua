--========================================================
-- Inkuton : Serpents d'encre (SERVEUR)
-- On vise un ennemi (visée des singes : NA_InkutonCible). Le lanceur déroule son parchemin, puis des
-- serpents partent un par un au sol et essaient de rattraper la cible (entité inkuton_serpent) : ils ne
-- s'accrochent pas, un contact = des dégâts. Un mur les arrête, une cible qui change de direction peut
-- leur échapper.
--
-- Réseau : "inkuton_serpents_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains"
--========================================================

util.AddNetworkString("inkuton_serpents_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 40     -- par serpent qui touche
local VITESSE      = 700
local ROTATION     = 220    -- degrés/s : plus c'est bas, plus la cible peut esquiver
local DUREE_VIE    = 3
local DETECTION    = 500    -- rayon de détection quand il n'y a pas de cible visée
local NOMBRE       = 3
local DECALAGE     = 0.25   -- secondes entre le départ de deux serpents
local ECART        = 40
local DEVANT       = 60
local RECHARGE     = 12
local CHAKRA_COUT  = 30
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0
local DELAI        = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local ID = "inkuton_serpents"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx", "sw.vtx" }) do
    resource.AddFile("models/inkuton/serpentsai." .. ext)
end
resource.AddFile("materials/models/razmo/saiprops/serpentsai.vmt")

local pret = {}

local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end

    local nombre = Niv(ply, "nombre", NOMBRE)
    local ecart = Niv(ply, "ecart", ECART)
    local decalage = Niv(ply, "decalage", DECALAGE)

    for i = 1, nombre do
        timer.Simple((i - 1) * decalage, function()
            if not IsValid(ply) or not ply:Alive() then return end
            -- direction prise au départ de CHAQUE serpent : ils vont là où tu regardes à ce moment-là
            local yaw = ply:EyeAngles().y
            local avant = Angle(0, yaw, 0):Forward()
            local droite = Angle(0, yaw, 0):Right()
            local base = ply:GetPos() + avant * Niv(ply, "devant", DEVANT)
            local ent = ents.Create("inkuton_serpent")
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

net.Receive("inkuton_serpents_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    -- cible visée si il y en a une ; sinon les serpents avancent tout droit et prennent le premier ennemi repéré
    local cible = NA_InkutonCible and NA_InkutonCible(ply, ID)

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
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_LANCER)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    local id = ply:LookupSequence(ANIM_LANCER)
    local duree = (id and id >= 0) and ply:SequenceDuration(id) or 1.2
    net.Start("inkuton_chiens_mains")
        net.WriteEntity(ply)
        net.WriteFloat(duree)
    net.Broadcast()

    timer.Simple(math.max(mudra, Niv(ply, "delai", DELAI)), function() Lancer(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "InkutonSerpents_Nettoyage", function(ply) pret[ply] = nil end)
