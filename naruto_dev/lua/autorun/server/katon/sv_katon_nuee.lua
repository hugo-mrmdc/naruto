--========================================================
-- Katon : Nuée ardente (SERVEUR)
--
-- Après les mudras, une nuée ardente (particule solve_katon_nuee_smoke_fire, particles/solve_new_katon.pcf) éclate au
-- sol, là où le lanceur regarde (si un ennemi est sur le chemin du regard, sur lui). Elle dure DUREE secondes : la
-- particule jaillit toutes les REPRISE secondes (elle ne dure que 0.75 s), et tout ennemi dans la zone prend des
-- dégâts à chaque tick et brûle. Le lanceur n'est pas touché.
-- OPTIMISÉ : aucune entité ; un timer, une recherche d'ennemis par tick, un message réseau par jaillissement.
-- Le serveur décide de tout : incantation, recharge, chakra.
--
-- Réseau : "katon_nuee_cast" (client -> serveur), "katon_nuee_fx" (serveur -> clients : particule), "katon_nuee_fil" (fil bouche -> nuée)
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_nuee_cast")
util.AddNetworkString("katon_nuee_fx")
util.AddNetworkString("katon_nuee_fil")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 1      -- durée de la nuée (secondes)
local REPRISE      = 1      -- secondes entre deux jaillissements de la particule (0.75 s chacun)
local RAYON        = 380    -- rayon de la zone : la particule jaillit sur une couche de 350 à 400 autour de son centre
local DEGATS       = 8      -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks
local BRULURE_DUREE = 4     -- brûlure appliquée aux cibles (0 = pas de brûlure)
local BRULURE_DPS  = 5
local PORTEE       = 700    -- distance de visée maximale
local TAILLE_VISEE = 35     -- demi-taille de la boîte de visée : un ennemi dedans est visé
local HAUTEUR_MAX  = 250    -- hauteur maximale d'un ennemi au-dessus du sol de la nuée pour être touché

local RECHARGE     = 22
local CHAKRA_COUT  = 70
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_TIR     = "nrp_ninjutsu_trow_fireball_lv3"   -- la même que la Grosse boule de feu
--========================================================

local ID = "katon_nuee"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_new_katon.pcf")
game.AddParticles("particles/solve_new_katon.pcf")
PrecacheParticleSystem("solve_katon_nuee_smoke_fire")

local pret = {}
local developer = GetConVar("developer")

local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

-- Point du sol visé : le premier décor touché par le regard ; si un ennemi est sur le chemin, le sol sous lui
local function PointVise(ply)
    local oeil = ply:GetShootPos()
    local mur = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * Niv(ply, "portee", PORTEE), filter = ply, mask = MASK_SOLID_BRUSHONLY })
    local point = mur.HitPos

    local cible, dMin = nil, math.huge
    local t = Vector(TAILLE_VISEE, TAILLE_VISEE, TAILLE_VISEE)
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do   -- _na_visee.lua
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < dMin then cible, dMin = ent, d end
        end
    end
    if cible then point = cible:GetPos() end

    local sol = util.TraceLine({
        start = point + (mur.Hit and mur.HitNormal * 5 or vector_origin) + Vector(0, 0, 10),
        endpos = point - Vector(0, 0, 4000), mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or point
end

local function Nuee(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local centre = PointVise(ply)
    local duree, reprise = Niv(ply, "duree", DUREE), Niv(ply, "reprise", REPRISE)
    local rayon, degats = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS)
    local bruleD, bruleDps = Niv(ply, "brulure_duree", BRULURE_DUREE), Niv(ply, "brulure_dps", BRULURE_DPS)
    local r2 = rayon * rayon
    local fin = CurTime() + duree

    if developer:GetInt() > 0 then debugoverlay.Sphere(centre, rayon, duree, Color(255, 120, 40, 12), true) end
    sound.Play("geams/solve_jutsu/katon/solve_katon_arena_start.wav", centre, 90, 70)

    -- fil de feu entre la bouche du lanceur et la nuée, pendant toute la nuée
    net.Start("katon_nuee_fil")
        net.WriteEntity(ply)
        net.WriteVector(centre)
        net.WriteFloat(duree)
    net.Broadcast()

    -- particule : un jaillissement tout de suite, puis toutes les `reprise` secondes tant que la nuée dure
    for t = 0, duree - 0.01, reprise do
        timer.Simple(t, function()
            net.Start("katon_nuee_fx")
                net.WriteVector(centre)
            net.Broadcast()
        end)
    end

    -- dégâts : un seul coup à l'éclatement (une seule recherche), puis uniquement la brûlure
    for _, ent in ipairs(ents.FindInSphere(centre + Vector(0, 0, 60), rayon)) do
        if EstCible(ent, ply) then
            local p = ent:GetPos()
            local dx, dy = p.x - centre.x, p.y - centre.y
            if dx * dx + dy * dy <= r2 and p.z - centre.z <= HAUTEUR_MAX and p.z - centre.z >= -100 then
                local dmg = DamageInfo()
                dmg:SetDamage(degats)
                dmg:SetAttacker(ply)
                dmg:SetInflictor(ply)
                dmg:SetDamageType(DMG_BURN)
                dmg:SetDamagePosition(ent:WorldSpaceCenter())
                ent:TakeDamageInfo(dmg)
                if bruleD > 0 and NA_Bruler then NA_Bruler(ent, ply, bruleD, bruleDps) end   -- sv_bouledefeut.lua
            end
        end
    end
end

net.Receive("katon_nuee_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin de la nuée
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, ID, total) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        NA_AnimJutsu(ply, ANIM_TIR)
        Nuee(ply)
    end)
end)

hook.Add("PlayerDisconnected", "KatonNuee_Nettoyage", function(ply)
    pret[ply] = nil
    timer.Remove("KatonNuee_" .. ply:EntIndex())
end)
