--========================================================
-- Kenjutsu : Tourbillon de lame (SERVEUR) - rang C
--
-- Une arme blanche en main : le lanceur fait un tour sur lui-même (animation
-- nrp_sword_ae__spinslash). Le coup part DELAI_IMPACT secondes après le
-- lancement et blesse tous les ennemis autour de lui (360°).
--========================================================

if not SERVER then return end

util.AddNetworkString("kenjutsu_tourbillon_cast")
util.AddNetworkString("kenjutsu_tourbillon_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.kenjutsu_tourbillon)
--========================================================
local DEGATS       = 38
local RAYON        = 170    -- portée du coup autour du lanceur
local DELAI_IMPACT = 0.35   -- secondes d'animation avant que le coup touche
local DELAI_FX     = 0.2    -- secondes avant que la particule de slash apparaisse
local DUREE_FX     = 0.5    -- secondes pendant lesquelles elle reste

local CHAKRA_COUT  = 15
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local RECHARGE     = 10

local ANIM         = "nrp_sword_ae__spinslash"
-- particule : posée côté client (cl_kenjutsu_tourbillon.lua), qui suit le lanceur jusqu'à la fin de l'animation
local SON_IMPACT   = "dimix/sond/taijutsu/hit6.wav"
local FX_HIT       = "solve_ken_nrm_hit_03"   -- sur chaque cible touchée (comme l'estoc, particles/solve_kenjutsu_expert.pcf)
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "kenjutsu_tourbillon", stat, base) end


local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> true pendant le lancement

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

local function Frapper(ply)
    actifs[ply] = nil
    if not IsValid(ply) or not ply:Alive() then return end

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

net.Receive("kenjutsu_tourbillon_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "kenjutsu_tourbillon") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if not ArmeBlanche(ply) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "kenjutsu_tourbillon", recharge) end   -- recharge visible dans la barre

    actifs[ply] = true
    NA_AnimJutsu(ply, ANIM)   -- animation + pas de coups pendant (_na_mudra.lua)

    net.Start("kenjutsu_tourbillon_fx")
        net.WriteEntity(ply)
        net.WriteFloat(DELAI_FX)
        net.WriteFloat(DUREE_FX)
    net.Broadcast()

    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function() Frapper(ply) end)
end)

hook.Add("PlayerDeath", "Kenjutsu_Tourbillon_Mort", function(ply) actifs[ply] = nil end)
hook.Add("PlayerDisconnected", "Kenjutsu_Tourbillon_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
