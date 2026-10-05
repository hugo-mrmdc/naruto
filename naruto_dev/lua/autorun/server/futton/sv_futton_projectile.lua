--========================================================
-- Futton : Projectile de vapeur (SERVEUR)
-- Après le mudra, un projectile (entité futton_projectile) part là où le lanceur regarde et fait des dégâts au premier
-- ennemi touché.
--
-- Réseau : "futton_projectile_cast" (client -> serveur)
--========================================================

util.AddNetworkString("futton_projectile_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 80
local RAYON        = 30
local VITESSE      = 1800
local DUREE_VIE    = 2      -- secondes (portée = vitesse x durée)
local DEVANT       = 50     -- distance de départ devant le lanceur

local RECHARGE     = 10
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.3
local ANIM_APPEL   = "m_ni_atk_ninjutsu_d22nj1_start"
--========================================================

local ID = "futton_projectile"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local dir = ply:GetAimVector()
    local ent = ents.Create("futton_projectile")
    if not IsValid(ent) then return end
    ent:SetPos(ply:GetShootPos() + dir * Niv(ply, "devant", DEVANT) - Vector(0, 0, 10))
    ent:SetAngles(dir:Angle())
    ent:SetOwner(ply)
    ent.Direction = dir
    ent.Degats    = Niv(ply, "degats", DEGATS)
    ent.Rayon     = Niv(ply, "rayon", RAYON)
    ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
    ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
    ent:Spawn()
    ply:EmitSound("naruto_sound/jutsu/futon/futon10.wav", 75, 130, 0.8)
end

net.Receive("futton_projectile_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

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

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "FuttonProjectile_Nettoyage", function(ply) pret[ply] = nil end)
