--========================================================
-- Katon : Météore (SERVEUR) - rang S
--
-- Après les mudras, un météore (entité katon_meteore, modèle atg_katon_meteor) tombe du ciel sur le point visé : à l'impact
-- au sol, particule solve_katon_chute_celeste_explo, dégâts de zone (les mêmes partout dans le rayon) et brûlure.
-- Le serveur décide de tout : incantation, recharge, chakra, dégâts.
--
-- Réseau : "katon_meteore_cast" (client -> serveur), "katon_meteore_fx" (serveur -> clients : explosion)
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_meteore_cast")
util.AddNetworkString("katon_meteore_fx")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 400    -- dégâts de l'explosion (les mêmes partout dans le rayon)
local RAYON        = 600    -- rayon de l'explosion
local ECHELLE      = 1      -- taille du météore (1 = ~418 de large)
local HAUTEUR      = 2500   -- hauteur de départ au-dessus du point visé
local GRAVITE      = 2400   -- accélération de chute
local PORTEE       = 1500   -- distance max du point visé
local BRULURE_DUREE = 4
local BRULURE_DPS  = 6

local RECHARGE     = 45
local CHAKRA_COUT  = 90
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 1.0
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "katon_meteore"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/nature/katon/atg_katon_meteor." .. ext)
end
-- textures du météore (le modèle les cherche dans materials/atg/pvp/katon/atg_meteore/)
for _, n in ipairs({ "atg_fire1", "atg_fire2", "atg_fire3", "atg_katon_meteor", "atg_wind1", "atg_wind2", "atg_wind3" }) do
    resource.AddFile("materials/atg/pvp/katon/atg_meteore/" .. n .. ".vmt")
    resource.AddFile("materials/atg/pvp/katon/atg_meteore/" .. n .. ".vtf")
end
resource.AddFile("materials/atg/pvp/katon/atg_meteore/lightwarpshader.vtf")
resource.AddFile("materials/atg/pvp/katon/atg_meteore/lightwarpshader2.vtf")
resource.AddFile("particles/solve_new_katon.pcf")
game.AddParticles("particles/solve_new_katon.pcf")
PrecacheParticleSystem("solve_katon_chute_celeste_explo")
util.PrecacheModel("models/nature/katon/atg_katon_meteor.mdl")

local enCours = {}
local pret    = {}

-- point visé, ramené au sol ; si le regard ne touche rien (ciel), on vise le sol DEVANT le lanceur à la portée max
local function PointVise(ply)
    local debut = ply:EyePos()
    local portee = Niv(ply, "portee", PORTEE)
    local tr = util.TraceLine({ start = debut, endpos = debut + ply:GetAimVector() * portee, filter = ply, mask = MASK_SOLID })
    local depart = tr.Hit and (tr.HitPos + tr.HitNormal * 5) or (debut + Angle(0, ply:EyeAngles().y, 0):Forward() * portee)
    local sol = util.TraceLine({ start = depart, endpos = depart - Vector(0, 0, 4000), filter = ply, mask = MASK_SOLID_BRUSHONLY })
    return sol.Hit and sol.HitPos or depart
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local cible = PointVise(ply)
    -- sous le plafond s'il y en a un
    local haut = util.TraceLine({
        start = cible + Vector(0, 0, 10), endpos = cible + Vector(0, 0, Niv(ply, "hauteur", HAUTEUR)),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local depart = haut.HitPos - Vector(0, 0, haut.Hit and 360 or 0)   -- le modèle fait ~355 de haut : on le met sous le plafond

    local m = ents.Create("katon_meteore")
    if not IsValid(m) then return end
    m:SetPos(depart)
    m:SetOwner(ply)
    m.Degats       = Niv(ply, "degats", DEGATS)
    m.Rayon        = Niv(ply, "rayon", RAYON)
    m.Echelle      = Niv(ply, "echelle", ECHELLE)
    m.Gravite      = Niv(ply, "gravite", GRAVITE)
    m.BrulureDuree = Niv(ply, "brulure_duree", BRULURE_DUREE)
    m.BrulureDps   = Niv(ply, "brulure_dps", BRULURE_DPS)
    m:Spawn()
end

net.Receive("katon_meteore_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

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

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    enCours[ply] = true
    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Lancer(ply)
    end)
end)

hook.Add("PlayerDeath", "KatonMeteore_Mort", function(ply) enCours[ply] = nil end)
hook.Add("PlayerDisconnected", "KatonMeteore_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
