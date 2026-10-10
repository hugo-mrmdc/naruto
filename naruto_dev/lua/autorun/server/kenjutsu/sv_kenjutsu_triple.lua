--========================================================
-- Kenjutsu : Triple lame (SERVEUR) - rang B
--
-- Une arme blanche en main : le lanceur enchaîne trois coups de sabre
-- (animation nrp_sword_triplespinslashing). Chaque coup part à son propre
-- moment (DELAIS), blesse tous les ennemis autour du lanceur (360°) et joue
-- sa particule de slash (triple_estoc_slash_pat, _2, _3).
--========================================================

if not SERVER then return end

util.AddNetworkString("kenjutsu_triple_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.kenjutsu_triple)
--========================================================
local DEGATS       = 28     -- par coup
local RAYON        = 180    -- portée de chaque coup autour du lanceur
local VITESSE_ANIM = 3     -- vitesse de lecture de l'animation (3 = trois fois plus vite)
local DELAIS       = { 0.3, 0.7, 1.1 }   -- secondes (à vitesse normale de l'animation) avant chacun des 3 coups ; divisées par VITESSE_ANIM

local CHAKRA_COUT  = 25
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local RECHARGE     = 16

local ANIM         = "nrp_sword_triplespinslashing"
local FX_SLASH     = { "triple_estoc_slash_pat", "triple_estoc_slash_pat_2", "triple_estoc_slash_pat_3" }   -- particles/patlick_atgparticules.pcf
local FX_HIT       = "solve_ken_nrm_hit_03"   -- sur chaque cible touchée (particles/solve_kenjutsu_expert.pcf)
local SON_IMPACT   = "dimix/sond/taijutsu/hit6.wav"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "kenjutsu_triple", stat, base) end

game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
for _, n in ipairs(FX_SLASH) do PrecacheParticleSystem(n) end
PrecacheParticleSystem(FX_HIT)

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> lancement en cours

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- arme blanche = toute arme Naruto sauf les poings
local function ArmeBlanche(ply)
    local arme = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(arme) or arme:GetClass() == "naruto_poings" then return false end
    return weapons.IsBasedOn(arme:GetClass(), "naruto_arme_base")
end

local function Frapper(ply, i)
    if not IsValid(ply) or not ply:Alive() or not actifs[ply] then actifs[ply] = nil return end
    if i == #DELAIS then actifs[ply] = nil end

    ParticleEffectAttach(FX_SLASH[i], PATTACH_ABSORIGIN_FOLLOW, ply, 0)

    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), Niv(ply, "rayon", RAYON))) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110))
        ParticleEffect(FX_HIT, ent:WorldSpaceCenter(), angle_zero)
    end
end

net.Receive("kenjutsu_triple_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "kenjutsu_triple") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if not ArmeBlanche(ply) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "kenjutsu_triple", recharge) end   -- recharge visible dans la barre

    actifs[ply] = true
    NA_AnimJutsu(ply, ANIM, nil, VITESSE_ANIM)   -- animation x3 + pas de coups pendant (_na_mudra.lua)

    for i, d in ipairs(DELAIS) do
        timer.Simple(Niv(ply, "delai_coup" .. i, d) / VITESSE_ANIM, function() Frapper(ply, i) end)
    end
end)

hook.Add("PlayerDeath", "Kenjutsu_Triple_Mort", function(ply) actifs[ply] = nil end)
hook.Add("PlayerDisconnected", "Kenjutsu_Triple_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
