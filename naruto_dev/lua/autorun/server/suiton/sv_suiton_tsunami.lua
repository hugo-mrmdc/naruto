--========================================================
-- Suiton : Tsunami (SERVEUR)
--
-- Après les mudras, le lanceur monte sur une vague (modèle tsunami_solve_custom, affiché par cl_suiton_tsunami.lua
-- d'après NW2Float "NA_TsunamiFin") qui AVANCE EN CONTINU dans la direction où il regarde (sh_suiton_tsunami.lua).
-- Tout ennemi touché par le front de la vague subit des dégâts. Elle dure DUREE secondes ; E permet d'en descendre avant.
-- Le serveur décide de tout : chakra, recharge, dégâts.
--
-- Réseau : "suiton_tsunami_cast" (client -> serveur)
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_tsunami_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 6      -- secondes sur la vague
local VITESSE      = 650    -- vitesse de la vague (unités/s ; un joueur marche à ~200)
local DEGATS       = 12     -- dégâts à chaque touche
local INTERVALLE   = 0.4    -- secondes avant qu'un même ennemi puisse être touché de nouveau
local RAYON        = 250    -- rayon de la zone qui touche : la vague mesure ~600 de long, centrée sous le lanceur
local DEVANT       = 40     -- décalage vers l'avant du centre de cette zone
local HAUTEUR_MAX  = 220    -- hauteur maximale d'un ennemi AU-DESSUS DU SOL (le lanceur, lui, est tenu en l'air sur la crête)

local RECHARGE     = 20     -- secondes après la FIN de la vague avant de pouvoir relancer
local CHAKRA_COUT  = 60
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.8
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local TOUCHE_DESCENDRE = IN_USE   -- E
--========================================================

local ID = "suiton_tsunami"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("models/nature/suiton/tsunami_solve_custom.mdl")
resource.AddFile("models/nature/suiton/tsunami_solve_custom.vvd")
resource.AddFile("models/nature/suiton/tsunami_solve_custom.dx90.vtx")
resource.AddFile("models/nature/suiton/tsunami_solve_custom.phy")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local vagues  = {}   -- joueur -> { degats, intervalle, rayon, touches = { ent -> prochain coup } }
local developer = GetConVar("developer")

local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

local function Descendre(ply)
    vagues[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Float("NA_TsunamiFin", 0)
    ply:SetNW2Float("NA_TsunamiVit", 0)
    ply.MokutonNoFall = CurTime() + 3   -- pas de dégâts de chute en descendant d'un coup de haut (même drapeau que le Bakuton)
end

local function Monter(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local duree = Niv(ply, "duree", DUREE)
    ply:SetNW2Float("NA_TsunamiVit", Niv(ply, "vitesse", VITESSE))
    ply:SetNW2Float("NA_TsunamiFin", CurTime() + duree)
    vagues[ply] = {
        degats = Niv(ply, "degats", DEGATS), intervalle = Niv(ply, "intervalle", INTERVALLE),
        rayon = Niv(ply, "rayon", RAYON), touches = {}, prochain = 0,
    }
    ply:EmitSound("ambient/water/water_splash2.wav", 80, 90)
end

net.Receive("suiton_tsunami_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if ply:GetNW2Float("NA_TsunamiFin", 0) > CurTime() then Descendre(ply) return end   -- relancer = descendre
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin de la vague
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, ID, total) end

    enCours[ply] = true
    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        enCours[ply] = nil
        Monter(ply)
    end)
end)

-- Dégâts : le front de la vague touche les ennemis devant le lanceur (un seul passage pour toutes les vagues)
hook.Add("Think", "SuitonTsunami_Degats", function()
    local now = CurTime()
    for ply, v in pairs(vagues) do
        if not IsValid(ply) or not ply:Alive() or ply:GetNW2Float("NA_TsunamiFin", 0) <= now then
            Descendre(ply)
        elseif now >= v.prochain then
            v.prochain = now + 0.1
            local dir = Angle(0, ply:EyeAngles().y, 0):Forward()
            -- le joueur est tenu à hauteur de la crête (sh_suiton_tsunami.lua) : la zone est centrée au niveau du sol, devant la vague
            -- niveau du sol sous la vague (mesuré : le lanceur monte progressivement à sa hauteur au départ)
            local tr = util.TraceLine({ start = ply:GetPos(), endpos = ply:GetPos() - Vector(0, 0, 800), filter = ply, mask = MASK_SOLID_BRUSHONLY })
            local sol = tr.Hit and tr.HitPos.z or (ply:GetPos().z - (NA_Tsunami and NA_Tsunami.Haut or 0))
            local centre = Vector(ply:GetPos().x, ply:GetPos().y, sol) + dir * DEVANT + Vector(0, 0, 40)
            local r2 = v.rayon * v.rayon

            if developer:GetInt() > 0 then debugoverlay.Sphere(centre, v.rayon, 0.15, Color(60, 140, 255, 20), true) end

            for _, ent in ipairs(ents.FindInSphere(centre, v.rayon)) do
                if EstCible(ent, ply) and (v.touches[ent] or 0) <= now
                    and ent:GetPos().z - sol <= HAUTEUR_MAX and ent:GetPos().z - sol >= -80 then
                    v.touches[ent] = now + v.intervalle
                    local dmg = DamageInfo()
                    dmg:SetDamage(v.degats)
                    dmg:SetAttacker(ply)
                    dmg:SetInflictor(ply)
                    dmg:SetDamageType(DMG_DROWN)
                    dmg:SetDamagePosition(ent:WorldSpaceCenter())
                    ent:TakeDamageInfo(dmg)
                end
            end
        end
    end
end)

-- E : on descend de la vague
hook.Add("KeyPress", "SuitonTsunami_Descendre", function(ply, key)
    if key == TOUCHE_DESCENDRE and ply:GetNW2Float("NA_TsunamiFin", 0) > CurTime() then Descendre(ply) end
end)

hook.Add("PlayerDeath", "SuitonTsunami_Mort", function(ply)
    enCours[ply] = nil
    Descendre(ply)
end)
hook.Add("PlayerSpawn", "SuitonTsunami_Spawn", Descendre)
hook.Add("PlayerDisconnected", "SuitonTsunami_Nettoyage", function(ply)
    enCours[ply], pret[ply], vagues[ply] = nil, nil, nil
end)
