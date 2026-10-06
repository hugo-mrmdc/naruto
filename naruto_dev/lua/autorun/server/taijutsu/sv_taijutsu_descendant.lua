--========================================================
-- Taijutsu : Coup de pied plongeant (SERVEUR)
--
-- 1. Le lanceur saute.
-- 2. Après un court instant, il fonce dans la direction où il regarde (toujours vers le bas) ;
--    l'animation (m_ni_atk_ninjutsu_d28nj2_loop) est rejouée tant que dure le plongeon.
--    Le plongeon lui-même est tenu par sh_senju_pied.lua.
-- 3. À l'atterrissage : impact, particules, dégâts autour de lui (sans projection).
-- Le serveur décide de tout : chakra, recharge, impact.
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_descendant_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.taijutsu_descendant)
--========================================================
local DEGATS         = 35
local RAYON          = 180
local ETOURDI        = 0.4    -- micro étourdissement des cibles touchées à la retombée (secondes)
local SAUT           = 450    -- force du saut
local VITESSE        = 1300   -- vitesse du plongeon
local DELAI_PLONGEE  = 0.35   -- secondes de saut avant de foncer
local PLONGEE_MAX    = 1.5    -- secondes max de plongeon (sécurité si on ne touche jamais le sol)
local PENTE_MINI     = -0.25  -- le plongeon descend au moins de cette pente, même en regardant vers le haut

local CHAKRA_COUT    = 15
local CHAKRA_MAX     = NA_CHAKRA_MAX or 100
local RECHARGE       = 10

local ANIM_PLONGEON  = "m_ni_atk_ninjutsu_d28nj2_loop"   -- rejouée tant que dure le plongeon

local PARTICULE      = "solve_doton_pics_floor"   -- particles/solve_doton.pcf
local SON_IMPACT     = "dimix/sond/taijutsu/hit6.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "taijutsu_descendant", stat, base) end

resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem(PARTICULE)

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { plonge, debutPlonge } tant que la technique est en cours

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Terminer(ply)
    actifs[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Float("NA_SenjuPiedFin", 0)
    ply:SetNW2Vector("NA_SenjuPiedDir", vector_origin)
    ply:SetNW2Bool("NA_Canalise", false)
end

local function Atterrir(ply)
    local vitesse = ply:GetVelocity()
    Terminer(ply)
    if not ply:Alive() then return end

    ply:SetVelocity(-vitesse)   -- le plongeon s'arrête net

    -- point d'impact : le sol sous le lanceur
    local tr = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 40), endpos = ply:GetPos() - Vector(0, 0, 400),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local pos = tr.Hit and tr.HitPos or ply:GetPos()

    ParticleEffect(PARTICULE, pos, angle_zero)
    sound.Play(SON_IMPACT, pos, 90, 80, 1)
    util.ScreenShake(pos, 8, 10, 0.6, 700)

    for _, ent in ipairs(ents.FindInSphere(pos, Niv(ply, "rayon", RAYON))) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        -- micro stun à la retombée (sv_etourdissement.lua)
        if NA_Etourdir then NA_Etourdir(ent, Niv(ply, "etourdi", ETOURDI)) end
    end
end

-- (re)lance l'animation de plongeon quand la précédente est finie
local function Boucler(ply, a)
    local now = CurTime()
    if now < (a.boucleFin or 0) then return end
    local seq = ply:LookupSequence(ANIM_PLONGEON)
    a.boucleFin = now + ((seq and seq >= 0) and math.max(ply:SequenceDuration(seq), 0.2) or 0.5)
    NA_AnimJutsu(ply, ANIM_PLONGEON)
end

local function Plonger(ply)
    local a = actifs[ply]
    if not a or not IsValid(ply) or not ply:Alive() then return end

    local dir = ply:EyeAngles():Forward()
    dir.z = math.min(dir.z, PENTE_MINI)
    dir:Normalize()

    local vitesse = Niv(ply, "vitesse", VITESSE)
    ply:SetNW2Vector("NA_SenjuPiedDir", dir * vitesse)
    ply:SetNW2Float("NA_SenjuPiedFin", CurTime() + PLONGEE_MAX)
    a.plonge = true
    a.debutPlonge = CurTime()
    a.vitesse = vitesse
    Boucler(ply, a)
end

net.Receive("taijutsu_descendant_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "taijutsu_descendant") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
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

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "taijutsu_descendant", recharge) end   -- recharge visible dans la barre

    actifs[ply] = { plonge = false }
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)

    NA_AnimJutsu(ply, ANIM_PLONGEON)   -- animation + pas de coups pendant (_na_mudra.lua)

    local vel = ply:GetVelocity()
    ply:SetVelocity(Vector(-vel.x, -vel.y, Niv(ply, "saut", SAUT) - vel.z))

    timer.Simple(Niv(ply, "delai_plongee", DELAI_PLONGEE), function() Plonger(ply) end)
end)

-- Suivi du plongeon : atterrissage, choc contre un mur, temps écoulé
hook.Add("Think", "TaiDescendant_Suivi", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() then
            Terminer(ply)
        elseif a.plonge then
            -- pas de coups pendant le plongeon : renouvelé seulement quand il s'épuise
            if ply:GetNW2Float("NA_MudraFin", 0) - CurTime() < 0.2 then NA_Mudra(ply, 0.5) end
            Boucler(ply, a)

            local t = CurTime() - a.debutPlonge
            local bloque = t > 0.15 and ply:GetVelocity():Length() < a.vitesse * 0.3   -- arrêté par un mur
            if (t > 0.1 and ply:IsOnGround()) or bloque or t > PLONGEE_MAX then
                Atterrir(ply)
            end
        end
    end
end)

-- pas de dégâts de chute pendant la technique
hook.Add("GetFallDamage", "TaiDescendant_SansChute", function(ply)
    if actifs[ply] then return 0 end
end)

hook.Add("PlayerDeath", "TaijutsuDescendant_Mort", function(ply) Terminer(ply) end)
hook.Add("PlayerSpawn", "TaijutsuDescendant_Spawn", function(ply) Terminer(ply) end)
hook.Add("PlayerDisconnected", "TaijutsuDescendant_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
