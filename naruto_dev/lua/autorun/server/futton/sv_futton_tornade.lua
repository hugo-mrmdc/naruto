--========================================================
-- Futton : Tornade de vapeur (SERVEUR)
-- Après les mudras, NOMBRE tornades de vapeur (entité futton_tornade) partent devant le lanceur, en éventail.
--
-- Réseau : "futton_tornade_cast" (client -> serveur)
--========================================================

util.AddNetworkString("futton_tornade_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local NOMBRE       = 3
local ECART        = 10     -- degrés entre deux tornades (éventail)
local DEGATS       = 8      -- par tick
local INTERVALLE   = 0.3
local RAYON        = 90
local VITESSE      = 450
local DUREE_VIE    = 3      -- secondes (portée = vitesse x durée)
local DEVANT       = 60     -- distance de départ devant le lanceur

local RECHARGE     = 14
local CHAKRA_COUT  = 35
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.3
local ANIM_APPEL   = "m_ni_atk_ninjutsu_d22nj1_start"
--========================================================

local ID = "futton_tornade"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local yaw = ply:EyeAngles().y
    local nombre, ecart = Niv(ply, "nombre", NOMBRE), Niv(ply, "ecart", ECART)
    for i = 1, nombre do
        local ang = Angle(0, yaw + (i - (nombre + 1) / 2) * ecart, 0)
        local ent = ents.Create("futton_tornade")
        if IsValid(ent) then
            ent:SetPos(ply:GetPos() + ang:Forward() * Niv(ply, "devant", DEVANT))
            ent:SetAngles(ang)
            ent:SetOwner(ply)
            ent.Degats     = Niv(ply, "degats", DEGATS)
            ent.Intervalle = Niv(ply, "intervalle", INTERVALLE)
            ent.Rayon      = Niv(ply, "rayon", RAYON)
            ent.Vitesse    = Niv(ply, "vitesse", VITESSE)
            ent.DureeVie   = Niv(ply, "duree_vie", DUREE_VIE)
            ent:Spawn()
        end
    end
    ply:EmitSound("ambient/wind/wind_snippet2.wav", 75, 110, 0.8)
end

net.Receive("futton_tornade_cast", function(_, ply)
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

hook.Add("PlayerDisconnected", "FuttonTornade_Nettoyage", function(ply) pret[ply] = nil end)
