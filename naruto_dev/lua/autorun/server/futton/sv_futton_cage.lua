--========================================================
-- Futton : Cage de vapeur (SERVEUR)
-- Une zone (entité futton_cage) apparaît là où le lanceur regarde : ceux qui sont dedans ne peuvent plus
-- en sortir, personne d'autre ne peut y entrer (le lanceur passe librement).
--
-- Réseau : "futton_cage_cast" (client -> serveur)
--========================================================

util.AddNetworkString("futton_cage_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local PORTEE       = 1500   -- distance maximale de visée
local RAYON        = 300    -- rayon de la cage
local HAUTEUR      = 400    -- hauteur de la cage
local DUREE        = 8      -- secondes
local DEGATS       = 5      -- dégâts par tick à ceux qui sont dans la cage
local INTERVALLE   = 0.5

local RECHARGE     = 30
local CHAKRA_COUT  = 50
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "futton_cage"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function PointVise(ply)
    local oeil = ply:EyePos()
    local tr = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * Niv(ply, "portee", PORTEE), filter = ply, mask = MASK_SOLID })
    -- le ciel est visé : on prend le sol sous le bout du rayon
    local bas = util.TraceLine({ start = tr.HitPos + Vector(0, 0, 20), endpos = tr.HitPos - Vector(0, 0, 3000), filter = ply, mask = MASK_SOLID_BRUSHONLY })
    return bas.Hit and bas.HitPos or tr.HitPos
end

net.Receive("futton_cage_cast", function(_, ply)
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
    local pos = PointVise(ply)   -- visée prise au lancement
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local ent = ents.Create("futton_cage")
        if not IsValid(ent) then return end
        ent:SetPos(pos)
        ent:SetOwner(ply)
        ent.Rayon    = Niv(ply, "rayon", RAYON)
        ent.Hauteur  = Niv(ply, "hauteur", HAUTEUR)
        ent.DureeVie = Niv(ply, "duree", DUREE)
        ent.Degats     = Niv(ply, "degats", DEGATS)
        ent.Intervalle = Niv(ply, "intervalle", INTERVALLE)
        ent:Spawn()
    end)
end)

hook.Add("PlayerDisconnected", "FuttonCage_Nettoyage", function(ply) pret[ply] = nil end)
