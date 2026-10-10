--========================================================
-- Kenjutsu : Tornade de lame (SERVEUR) - rang A
--
-- Une arme blanche en main : le lanceur fait un grand coup de sabre montant
-- (animation M_SD_Attack_Sword_06_RightUpSlashing) qui libère, DELAI_LANCER
-- secondes plus tard, une tornade (entité kenjutsu_tornade) droit devant lui.
-- Le serveur décide de tout : chakra, recharge, trajectoire.
--========================================================

if not SERVER then return end

util.AddNetworkString("kenjutsu_tornade_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.kenjutsu_tornade)
--========================================================
local DEGATS       = 60     -- par ennemi traversé
local VITESSE      = 1400   -- vitesse de la tornade (unités par seconde)
local DUREE_VIE    = 1.0    -- secondes avant qu'elle disparaisse (distance = vitesse x durée)
local SOULEVE      = 350    -- hauteur dont elle projette en l'air chaque ennemi touché
local ETOURDI      = 0.4    -- secondes d'étourdissement de l'ennemi touché
local HITBOX       = 120    -- demi-largeur de la zone qui touche
local HITBOX_HAUT  = 130    -- demi-hauteur de la zone qui touche
local DELAI_LANCER = 0.35   -- secondes d'animation avant que la tornade parte
local DEPART       = 60     -- distance devant le lanceur où elle apparaît
local NOMBRE       = 3      -- nombre de tornades lancées d'un coup (en éventail)
local ECART        = 18     -- angle entre deux tornades voisines (degrés)

local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local RECHARGE     = 25

local ANIM         = "M_SD_Attack_Sword_06_RightUpSlashing"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "kenjutsu_tornade", stat, base) end

game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
PrecacheParticleSystem("kenjutsu_tornade_pat")
PrecacheParticleSystem("solve_ken_nrm_hit_03")

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> true pendant le lancement

-- arme blanche = toute arme Naruto sauf les poings
local function ArmeBlanche(ply)
    local arme = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(arme) or arme:GetClass() == "naruto_poings" then return false end
    return weapons.IsBasedOn(arme:GetClass(), "naruto_arme_base")
end

local function Lancer(ply)
    actifs[ply] = nil
    if not IsValid(ply) or not ply:Alive() then return end

    -- direction du regard AU MOMENT du départ, à l'horizontale (les tornades restent au sol)
    local base = ply:EyeAngles()
    base.p, base.r = 0, 0

    local nb = math.max(math.floor(Niv(ply, "nombre", NOMBRE)), 1)
    local ecart = Niv(ply, "ecart", ECART)
    local touches = {}   -- partagée : un ennemi n'est touché qu'une fois, même par plusieurs tornades

    for i = 1, nb do
        -- éventail centré sur le regard : 1 = droit devant, 3 = gauche / centre / droite
        local ang = Angle(0, base.y + (i - (nb + 1) / 2) * ecart, 0)
        local dir = ang:Forward()

        local ent = ents.Create("kenjutsu_tornade")
        if not IsValid(ent) then continue end

        ent:SetPos(ply:GetPos() + dir * DEPART)
        ent:SetOwner(ply)
        ent.Direction = dir
        ent.Touches   = touches
        ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
        ent.Degats    = Niv(ply, "degats", DEGATS)
        ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
        ent.Rayon     = Niv(ply, "hitbox", HITBOX)
        ent.RayonHaut = Niv(ply, "hitbox_haut", HITBOX_HAUT)
        ent.Souleve   = Niv(ply, "souleve", SOULEVE)
        ent.Etourdi   = Niv(ply, "etourdi", ETOURDI)
        ent:Spawn()
    end
end

net.Receive("kenjutsu_tornade_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "kenjutsu_tornade") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if not ArmeBlanche(ply) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "kenjutsu_tornade", recharge) end   -- recharge visible dans la barre

    actifs[ply] = true
    NA_AnimJutsu(ply, ANIM)   -- animation + pas de coups pendant (_na_mudra.lua)

    timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function() Lancer(ply) end)
end)

hook.Add("PlayerDeath", "Kenjutsu_Tornade_Mort", function(ply) actifs[ply] = nil end)
hook.Add("PlayerDisconnected", "Kenjutsu_Tornade_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
