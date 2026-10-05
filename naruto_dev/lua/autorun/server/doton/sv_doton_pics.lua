--========================================================
-- Doton : Pics de pierre (SERVEUR)
--
-- Vise un ennemi comme le Cube de confinement Jinton : une boîte (hitbox de visée, taille par niveau) est lancée
-- depuis les yeux le long du regard ; la cible valable la plus proche est touchée après les mudras : dégâts et
-- étourdissement. La particule solve_doton_pics_floor se joue au sol SOUS elle, et le modèle lv_doton_petrif
-- apparaît sur elle jusqu'à la fin de l'étourdissement.
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("doton_pics_cast")
util.AddNetworkString("doton_pics_fx")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 20
local STUN         = 2      -- secondes d'étourdissement
local PORTEE       = 900    -- distance maximale de la cible
local TAILLE_VISEE = 20     -- demi-taille de la hitbox de visée (boîte lancée le long du regard)
                            -- plus grand = plus facile de viser. Visible avec : developer 1
local MODELE       = "models/nature/doton/lv_doton_petrif.mdl"   -- posé sur les ennemis touchés

local RECHARGE     = 14
local CHAKRA_COUT  = 35
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.5
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2
--========================================================

local ID = "doton_pics"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem("solve_doton_pics_floor")
resource.AddFile("models/nature/doton/lv_doton_petrif.mdl")
resource.AddFile("models/nature/doton/lv_doton_petrif.vvd")
resource.AddFile("models/nature/doton/lv_doton_petrif.dx90.vtx")
resource.AddFile("materials/models/loeve/lv_doton_petrif/lv_doton_petrif.vmt")
resource.AddFile("materials/models/loeve/lv_doton_petrif/lv_doton_petrif.vtf")

local pret = {}

-- pose le modèle de pierre sur la cible, jusqu'à la fin de l'étourdissement
local function Petrifier(ent, stun)
    local pic = ents.Create("prop_dynamic")
    if not IsValid(pic) then return end
    pic:SetModel(MODELE)
    pic:SetPos(ent:GetPos())
    pic:SetAngles(Angle(0, ent:GetAngles().y, 0))
    pic:SetSolid(SOLID_NONE)
    pic:Spawn()
    pic:EmitSound("naruto_sound/jutsu/doton/earth1.wav", 80, math.random(60, 80))
    timer.Simple(stun, function() if IsValid(pic) then pic:Remove() end end)
end

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- hitbox de visée au niveau du joueur (_na_niveaux_techniques.lua)
local function HitboxVisee(ply)
    local t = Niv(ply, "hitbox", TAILLE_VISEE)
    return Vector(t, t, t)
end

-- Ennemi visé : même méthode que le Cube Jinton (NA_FindAlongRay) : parmi tout ce que la boîte traverse
-- jusqu'au premier mur, la cible valable la plus proche.
local function TrouverCible(ply)
    local oeil = ply:EyePos()
    local t = HitboxVisee(ply)

    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end

    -- mode développeur : la hitbox reste affichée 2 s à chaque lancement
    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.SweptBox(oeil, mur.HitPos, -t, t, angle_zero, 2, cible and Color(0, 255, 0, 40) or Color(255, 60, 60, 40))
        if cible then debugoverlay.Box(cible:GetPos(), cible:OBBMins(), cible:OBBMaxs(), 2, Color(0, 255, 0, 60)) end
    end
    return cible
end

local function Frapper(ply, cible)
    if not IsValid(ply) or not ply:Alive() then return end
    -- la cible a pu mourir ou s'éloigner pendant l'incantation
    if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > Niv(ply, "portee", PORTEE) * 1.2 then return end

    local dmg = DamageInfo()
    dmg:SetDamage(Niv(ply, "degats", DEGATS))
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_CRUSH)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)

    local stun = Niv(ply, "stun", STUN)
    if NA_Etourdir then NA_Etourdir(cible, stun) end   -- sv_etourdissement.lua
    Petrifier(cible, stun)

    -- particule au sol, sous la cible touchée
    local pied = util.TraceLine({
        start = cible:GetPos() + Vector(0, 0, 20), endpos = cible:GetPos() - Vector(0, 0, 200),
        mask = MASK_SOLID_BRUSHONLY,
    })
    net.Start("doton_pics_fx")
        net.WriteVector(pied.Hit and pied.HitPos or cible:GetPos())
    net.Broadcast()
end

net.Receive("doton_pics_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
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

    local cible = TrouverCible(ply)   -- pas de cible : mudras + recharge quand même (comme le Cube Jinton)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Frapper(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "DotonPics_Nettoyage", function(ply) pret[ply] = nil end)
