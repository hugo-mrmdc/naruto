--========================================================
-- Futon : Ouragan de vent (SERVEUR)
-- Après le mudra, une grosse tornade de vent (entité futon_ouragan) avance devant le lanceur :
-- dégâts et petit bump à chaque ennemi traversé.
--
-- Réseau : "futon_ouragan_cast" (client -> serveur)
--========================================================

util.AddNetworkString("futon_ouragan_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 60
local RAYON        = 110
local VITESSE      = 500
local DUREE_VIE    = 3      -- secondes (portée = vitesse x durée)
local POUSSE       = 450    -- bump horizontal
local SOULEVEE     = 250    -- bump vertical
local DEVANT       = 70     -- distance de départ devant le lanceur

local RECHARGE     = 12
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "m_ni_atk_ninjutsu_d22nj1_start"
--========================================================

resource.AddFile("particles/patlick_atgparticules.pcf")

local ID = "futon_ouragan"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local ang = Angle(0, ply:EyeAngles().y, 0)
    local ent = ents.Create("futon_ouragan")
    if not IsValid(ent) then return end
    ent:SetPos(ply:GetPos() + ang:Forward() * Niv(ply, "devant", DEVANT))
    ent:SetAngles(ang)
    ent:SetOwner(ply)
    ent.Degats   = Niv(ply, "degats", DEGATS)
    ent.Rayon    = Niv(ply, "rayon", RAYON)
    ent.Vitesse  = Niv(ply, "vitesse", VITESSE)
    ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
    ent.Pousse   = Niv(ply, "pousse", POUSSE)
    ent.Soulevee = Niv(ply, "souleve", SOULEVEE)
    ent:Spawn()
    ply:EmitSound("ambient/wind/wind_snippet2.wav", 75, 90, 0.8)
end

net.Receive("futon_ouragan_cast", function(_, ply)
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

hook.Add("PlayerDisconnected", "FutonOuragan_Nettoyage", function(ply) pret[ply] = nil end)
