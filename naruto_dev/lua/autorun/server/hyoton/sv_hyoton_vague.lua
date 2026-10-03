--========================================================
-- Hyoton : Vague de glace (SERVEUR)
-- Après les mudras, un bouquet de pics (entité hyoton_vague) part du lanceur et avance tout droit au ras du
-- sol. Au premier ennemi touché : dégâts + court étourdissement, puis il disparaît. Il s'arrête sur un mur.
--
-- Réseau : "hyoton_vague_cast" (client -> serveur)
--========================================================

util.AddNetworkString("hyoton_vague_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local PORTEE       = 900    -- distance parcourue (= vitesse x durée de vie)
local VITESSE      = 900
local RAYON        = 90     -- demi-largeur de la zone qui touche
local DEGATS       = 50
local STUN         = 1
local ECHELLE      = 0.8    -- le modèle fait ~280 unités de large à l'échelle 1 : ajuster si trop gros / petit

local RECHARGE     = 16
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "hyoton_vague"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

net.Receive("hyoton_vague_cast", function(_, ply)
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
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local ent = ents.Create("hyoton_vague")
        if not IsValid(ent) then return end
        local av = Angle(0, ply:EyeAngles().y, 0):Forward()
        ent:SetPos(ply:GetPos() + av * 60)
        ent:SetOwner(ply)
        ent.Direction = av
        ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
        ent.DureeVie  = Niv(ply, "portee", PORTEE) / ent.Vitesse
        ent.Rayon     = Niv(ply, "rayon", RAYON)
        ent.Degats    = Niv(ply, "degats", DEGATS)
        ent.Stun      = Niv(ply, "stun", STUN)
        ent.Echelle   = Niv(ply, "echelle", ECHELLE)
        ent:Spawn()
    end)
end)

hook.Add("PlayerDisconnected", "HyotonVague_Nettoyage", function(ply) pret[ply] = nil end)
