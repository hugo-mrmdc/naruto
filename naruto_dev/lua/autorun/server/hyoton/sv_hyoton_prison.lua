--========================================================
-- Hyoton : Prison de glace (SERVEUR) - stun + dégâts par tick
-- Vise un ennemi (visée des singes : NA_InkutonCible). Après les mudras il est étourdi DUREE secondes (NA_Etourdir,
-- comme le cube Jinton) dans une arène de miroirs (entité hyoton_prison) qui lui inflige des dégâts à chaque tick.
--
-- Réseau : "hyoton_prison_cast" (client -> serveur)
--========================================================

util.AddNetworkString("hyoton_prison_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 2.5    -- durée du stun (secondes)
local DEGATS       = 5      -- par tick
local INTERVALLE   = 0.5
local RECHARGE     = 18
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.3
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "hyoton_prison"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

net.Receive("hyoton_prison_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cible = NA_InkutonCible and NA_InkutonCible(ply, ID)   -- nil = mudras + recharge quand même

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
        if not IsValid(ply) or not ply:Alive() or not IsValid(cible) then return end
        local duree = Niv(ply, "duree", DUREE)
        if NA_Etourdir then NA_Etourdir(cible, duree) end
        local ent = ents.Create("hyoton_prison")
        if not IsValid(ent) then return end
        ent:SetPos(cible:GetPos())
        ent:SetOwner(ply)
        ent.Cible      = cible
        ent.DureeVie   = duree
        ent.Degats     = Niv(ply, "degats", DEGATS)
        ent.Intervalle = Niv(ply, "intervalle", INTERVALLE)
        ent:Spawn()
        cible:EmitSound("physics/glass/glass_impact_bullet4.wav", 75, 90)
    end)
end)

hook.Add("PlayerDisconnected", "HyotonPrison_Nettoyage", function(ply) pret[ply] = nil end)
