--========================================================
-- Bakuton : Mines explosives (SERVEUR) - stun
-- Vise un ennemi (visée des singes : NA_InkutonCible). Des mines (atg_mine_bakuton) apparaissent une à une en
-- cercle au sol autour de lui : la première l'étourdit (NA_Etourdir, comme le cube Jinton), puis elles
-- explosent quand le stun se termine (entité bakuton_araignee).
--
-- Réseau : "bakuton_araignees_cast" (client -> serveur)
--========================================================

util.AddNetworkString("bakuton_araignees_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 15     -- par araignée, à l'explosion
local DUREE        = 2      -- durée du stun (secondes)
local VITESSE      = 600
local NOMBRE       = 6
local DECALAGE     = 0.08   -- secondes entre le départ de deux araignées
local RECHARGE     = 14
local CHAKRA_COUT  = 35
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DELAI        = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local ID = "bakuton_araignees"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/atg_mine_bakuton." .. ext)
end
for _, f in ipairs({ "atg_mine.vmt", "atg_mine.vtf", "atg_outline.vmt", "atg_outline.vtf" }) do
    resource.AddFile("materials/atg/pvp/bakuton/atg_mine/" .. f)
end
resource.AddFile("materials/atg/pvp/bakuton/atg_mignon/atg_outline.vtf")
resource.AddFile("materials/atg_props/shared/lightwarpshader_bakuton.vtf")

local pret = {}

local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end
    local nombre = Niv(ply, "nombre", NOMBRE)
    for i = 1, nombre do
        timer.Simple((i - 1) * Niv(ply, "decalage", DECALAGE), function()
            if not IsValid(ply) or not ply:Alive() or not IsValid(cible) then return end
            local ent = ents.Create("bakuton_araignee")
            if not IsValid(ent) then return end
            ent:SetOwner(ply)
            ent.Cible   = cible
            ent.Index, ent.Total = i, nombre
            ent.Degats  = Niv(ply, "degats", DEGATS)
            ent.Duree   = Niv(ply, "duree", DUREE)
            ent:Spawn()
        end)
    end
end

net.Receive("bakuton_araignees_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cible = NA_InkutonCible and NA_InkutonCible(ply, ID)
    if not cible then
        ply:PrintMessage(HUD_PRINTCENTER, "Aucune cible")
        return
    end

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

hook.Add("PlayerDisconnected", "BakutonAraignees_Nettoyage", function(ply) pret[ply] = nil end)
