--========================================================
-- Kenjutsu : Estoc perforant (SERVEUR) - rang C
--
-- Une arme blanche en main : le lanceur joue l'animation d'estoc puis se
-- propulse vers l'avant (dash tenu par sh_dash.lua : NA_DashVel / NA_DashFin).
-- Tous les ennemis traversés sont blessés une fois ; la particule de slash
-- suit le lanceur, celle d'impact éclate au sol à l'arrivée.
--========================================================

if not SERVER then return end

util.AddNetworkString("kenjutsu_perforant_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.kenjutsu_perforant)
--========================================================
local DEGATS       = 45
local RAYON        = 90     -- distance autour du lanceur qui blesse pendant le dash
local ETOURDI      = 0.6
local VITESSE      = 1400   -- vitesse du dash
local DUREE_DASH   = 0.25   -- secondes de dash (distance = vitesse x durée)
local ANGLE_MAX_HAUT = 20  -- degrés max vers le haut
local DELAI_ELAN   = 0.2   -- secondes d'animation avant de partir

local CHAKRA_COUT  = 12
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local RECHARGE     = 9

local ANIM         = "m_sd_attack_2edgesword_cmb_05"
local FX_SLASH     = "dash_perforant_slash_pat"
local FX_SOL       = "dash_perforant_hitground_pat"
local FX_HIT       = "solve_ken_nrm_hit_03"   -- sur la cible touchée (particles/solve_kenjutsu_expert.pcf)
local SON_IMPACT   = "dimix/sond/taijutsu/hit6.wav"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "kenjutsu_perforant", stat, base) end

game.AddParticles("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/solve_kenjutsu_expert.pcf")
PrecacheParticleSystem(FX_HIT)
PrecacheParticleSystem(FX_SLASH)
PrecacheParticleSystem(FX_SOL)

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { fin, touches } pendant le dash

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

local function Terminer(ply)
    actifs[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Bool("NA_Canalise", false)
    ply:SetNW2Float("NA_DashFin", 0)
    ply:SetFriction(1)
    ply:SetVelocity(-ply:GetVelocity())   -- stop net : sinon l'élan l'emporte bien plus loin
end

-- impact au sol sous la cible touchée
local function ImpactSol(ply, cible)
    local pos = cible:GetPos()
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 40), endpos = pos - Vector(0, 0, 3000),
        filter = { ply, cible }, mask = MASK_SOLID_BRUSHONLY,
    })
    local ang = ply:EyeAngles()
    ang.p, ang.r = 0, 0
    ParticleEffect(FX_SOL, tr.Hit and tr.HitPos or pos, ang)
end

local function Blesser(ply, a)
    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), Niv(ply, "rayon", RAYON))) do
        if a.touche or not EstCible(ent, ply) then continue end
        a.touche = true   -- un seul ennemi par estoc

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        if NA_Etourdir then NA_Etourdir(ent, Niv(ply, "etourdi", ETOURDI), nil, nil, true) end   -- sv_etourdissement.lua
        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110))
        ImpactSol(ply, ent)
        ParticleEffect(FX_HIT, ent:WorldSpaceCenter(), angle_zero)
    end
end

local function Demarrer(ply)
    if not IsValid(ply) or not ply:Alive() or not actifs[ply] then actifs[ply] = nil return end

    local ang = ply:EyeAngles()
    ang.p = math.max(ang.p, -ANGLE_MAX_HAUT)   -- regard vers le haut limité (p négatif = haut) : pas de montée excessive
    local dir = ang:Forward()                  -- là où il regarde, bas compris

    local vitesse, duree = Niv(ply, "vitesse", VITESSE), Niv(ply, "duree_dash", DUREE_DASH)
    -- on remplace la vitesse horizontale (le maintien est fait par sh_dash.lua)
    local vel = ply:GetVelocity()
    ply:SetVelocity(-vel + dir * vitesse)
    ply:SetNW2Vector("NA_DashVel", dir * vitesse)
    ply:SetNW2Float("NA_DashFin", CurTime() + duree)
    ply:SetFriction(0)

    ParticleEffectAttach(FX_SLASH, PATTACH_ABSORIGIN_FOLLOW, ply, 0)
    actifs[ply].fin = CurTime() + duree
end

hook.Add("Think", "Kenjutsu_Perforant", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() then
            actifs[ply] = nil
        elseif a.fin then
            Blesser(ply, a)
            if a.touche or CurTime() >= a.fin then Terminer(ply) end   -- s'arrête net sur l'ennemi touché
        end
    end
end)

net.Receive("kenjutsu_perforant_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "kenjutsu_perforant") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if not ArmeBlanche(ply) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "kenjutsu_perforant", recharge) end   -- recharge visible dans la barre

    actifs[ply] = {}
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)
    NA_AnimJutsu(ply, ANIM)               -- animation + pas de coups pendant (_na_mudra.lua)

    timer.Simple(Niv(ply, "delai_elan", DELAI_ELAN), function() Demarrer(ply) end)
end)

hook.Add("PlayerDeath", "Kenjutsu_Perforant_Mort", function(ply) if actifs[ply] then Terminer(ply) end end)
hook.Add("PlayerDisconnected", "Kenjutsu_Perforant_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
