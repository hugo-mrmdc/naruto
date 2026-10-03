--========================================================
-- Hyoton : Dôme de glace (SERVEUR)
-- Après les mudras, un dôme de glace (entité hyoton_dome) se déploie autour du lanceur : les ennemis
-- dedans sont ralentis et subissent des dégâts à chaque tick. Elle disparaît au bout de DUREE s ou si le lanceur meurt.
--
-- Réseau : "hyoton_dome_cast" (client -> serveur)
--========================================================

util.AddNetworkString("hyoton_dome_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local RAYON        = 400
local HAUTEUR      = 300
local DUREE        = 8
local DEGATS       = 6      -- par tick
local INTERVALLE   = 0.5
local RALENTI      = 0.7    -- multiplicateur de vitesse des ennemis dedans

local RECHARGE     = 30
local CHAKRA_COUT  = 50
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.6
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "hyoton_dome"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

net.Receive("hyoton_dome_cast", function(_, ply)
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
        local ent = ents.Create("hyoton_dome")
        if not IsValid(ent) then return end
        -- toujours posé au sol, même si le lanceur est en l'air
        local pos = ply:GetPos()
        local tr = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 10000), mask = MASK_SOLID_BRUSHONLY })
        ent:SetPos(tr.Hit and tr.HitPos or pos)
        ent:SetOwner(ply)
        ent.Rayon      = Niv(ply, "rayon", RAYON)
        ent.Hauteur    = Niv(ply, "hauteur", HAUTEUR)
        ent.DureeVie   = Niv(ply, "duree", DUREE)
        ent.Degats     = Niv(ply, "degats", DEGATS)
        ent.Intervalle = Niv(ply, "intervalle", INTERVALLE)
        ent.Ralenti    = Niv(ply, "ralenti", RALENTI)
        ent:Spawn()
    end)
end)

hook.Add("PlayerDisconnected", "HyotonDome_Nettoyage", function(ply) pret[ply] = nil end)
