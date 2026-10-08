--========================================================
-- Shoton : Chute de cristal (SERVEUR)
-- Après le mudra, un gros cristal (entité shoton_chute) tombe du ciel sur le point visé (portée limitée) et explose à
-- l'impact : dégâts de zone, mêmes particules que les roquettes Shoton.
--
-- Réseau : "shoton_chute_cast" (client -> serveur)
--========================================================

util.AddNetworkString("shoton_chute_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local PORTEE      = 800    -- distance de visée maximale
local HAUTEUR     = 700    -- hauteur de départ au-dessus du point visé (réduite sous un plafond)
local DEGATS      = 120
local EXPLOSION   = 150
local STUN        = 0.8    -- léger étourdissement (secondes)
local TAILLE_VISEE = 35    -- demi-taille de la boîte de visée : un ennemi dedans est visé (comme le Cube Jinton)
local RECHARGE    = 25
local CHAKRA_COUT = 70
local CHAKRA_MAX  = NA_CHAKRA_MAX or 100
local DUREE_MUDRA = 0.4
local ANIM_APPEL  = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "shoton_chute"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = Niv(ply, "portee", PORTEE)
    local oeil = ply:GetShootPos()
    local vise = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * portee, filter = ply, mask = MASK_SOLID_BRUSHONLY })
    local cible = vise.HitPos
    if vise.Hit and vise.HitNormal.z < 0.5 then cible = cible + vise.HitNormal * 40 end   -- mur : on tombe devant lui

    -- Ennemi visé : la visée ci-dessus ne voit que le décor, donc quand on visait un ennemi le cristal tombait sur le sol ou
    -- le mur DERRIÈRE lui et passait à côté. On cherche d'abord un ennemi sur le chemin du regard (boîte lancée jusqu'au
    -- décor, comme le Cube Jinton) : s'il y en a un, le cristal tombe sur LUI, et le suit pendant la chute s'il bouge.
    local suivi, dMin = nil, math.huge
    local t = Vector(TAILLE_VISEE, TAILLE_VISEE, TAILLE_VISEE)
    for _, ent in ipairs(NA_FindAlongRay(oeil, vise.HitPos, t)) do   -- _na_visee.lua
        if NA_InkutonEstCible and NA_InkutonEstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < dMin then suivi, dMin = ent, d end
        end
    end
    if suivi then cible = suivi:GetPos() end

    -- départ en hauteur, sans traverser un plafond
    local haut = Niv(ply, "hauteur", HAUTEUR)
    local plafond = util.TraceLine({ start = cible + Vector(0, 0, 10), endpos = cible + Vector(0, 0, haut), mask = MASK_SOLID_BRUSHONLY })
    local depart = plafond.Hit and (plafond.HitPos - Vector(0, 0, 80)) or (cible + Vector(0, 0, haut))

    local ent = ents.Create("shoton_chute")
    if not IsValid(ent) then return end
    ent:SetPos(depart)
    ent:SetOwner(ply)
    ent.Degats    = Niv(ply, "degats", DEGATS)
    ent.Explosion = Niv(ply, "explosion", EXPLOSION)
    ent.Stun      = Niv(ply, "stun", STUN)
    ent.Echelle   = Niv(ply, "echelle", ent.Echelle)
    ent.Suivi     = suivi
    ent:Spawn()
    ply:EmitSound("geams/solve_jutsu/shoton/solve_shoton_stun_hit.wav", 75, 110, 0.8)
end

net.Receive("shoton_chute_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then
        -- (pas de message)
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "ShotonChute_Nettoyage", function(ply) pret[ply] = nil end)
