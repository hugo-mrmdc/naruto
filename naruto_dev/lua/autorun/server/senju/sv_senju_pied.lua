--========================================================
-- Senju : Coup de pied céleste (SERVEUR)
--
-- 1. Le lanceur saute (animation ANIM_DEBUT).
-- 2. Après un court instant, il fonce dans la direction où il regarde (toujours vers le bas).
--    Le plongeon lui-même est tenu par sh_senju_pied.lua.
-- 3. À l'atterrissage (animation ANIM_FIN) : gros impact, particules, énorme roche qui sort du sol,
--    dégâts et projection autour de lui.
-- Le serveur décide de tout : chakra, recharge, impact.
--========================================================

if not SERVER then return end

util.AddNetworkString("senju_pied_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.senju_pied)
--========================================================
local DEGATS         = 60
local RAYON          = 320
local PROJECTION     = 500
local PROJ_HAUT      = 300
local SAUT           = 550    -- force du saut
local VITESSE        = 1500   -- vitesse du plongeon
local DELAI_PLONGEE  = 0.45   -- secondes de saut avant de foncer
local PLONGEE_MAX    = 2      -- secondes max de plongeon (sécurité si on ne touche jamais le sol)
local PENTE_MINI     = -0.25  -- le plongeon descend au moins de cette pente, même en regardant vers le haut

local CHAKRA_COUT    = 45
local CHAKRA_MAX     = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE       = 20

local ANIM_DEBUT     = "nrp_ninjutsu_heal_heavenkickpain_attack_start"
local ANIM_BOUCLE    = "nrp_ninjutsu_heal_heavenkickpain_attack_loop"   -- rejouée tant que dure le plongeon
-- Animations des joueurs touchés : plusieurs noms possibles, le premier qui existe sur leur modèle est joué
local VICTIME_TOUCHE = { "m_beaten_aerial_universalpull_start", "nrp_beaten_aerial_universalpull_start" }   -- à l'impact
local VICTIME_CHUTE  = { "m_beaten_fall_chaseattack_behind_loop", "nrp_beaten_aerial_blowoff_tofall" }      -- en l'air (en boucle)
local VICTIME_SOL    = { "m_beaten_downtofloor", "nrp_beaten_aerial_downtofloor_conect_tostand" }          -- au sol
local ANIM_FIN       = "nrp_ninjutsu_heal_heavenkickpain_attack_end"

local PARTICULE      = "solve_doton_pics_floor"   -- particles/solve_doton.pcf
local NB_PARTICULES  = 3      -- une au centre + le reste en cercle (chaque système de particules coûte cher au client)
local ROCHER_ECHELLE = 5.5    -- la roche de la Frappe terrestre est à 2.2
local ROCHER_DUREE   = 3
local SON            = "physics/concrete/concrete_break3.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_pied", stat, base) end

resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem(PARTICULE)

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { plonge, debutPlonge } tant que la technique est en cours

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Terminer(ply)
    actifs[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Float("NA_SenjuPiedFin", 0)
    ply:SetNW2Vector("NA_SenjuPiedDir", vector_origin)
    ply:SetNW2Bool("NA_Canalise", false)
end

-- premier nom de la liste qui existe sur le modèle de "ent" (sinon le premier : le client peut le connaître)
local function Choisir(ent, noms)
    for _, nom in ipairs(noms) do
        local seq = ent:LookupSequence(nom)
        if seq and seq >= 0 then return nom, seq end
    end
    return noms[1]
end

-- Joueurs et faux joueurs (nextbot na_faux_joueur) subissent les animations de victime
local function Victime(ent)
    return ent:IsPlayer() or ent:GetClass() == "na_faux_joueur"
end

local function Vivant(ent)
    if ent:IsPlayer() then return ent:Alive() end
    return ent:Health() > 0
end

-- Joue une animation ; renvoie sa durée pour la relancer quand elle est finie (les gestes ne bouclent pas seuls)
local function Jouer(ent, noms)
    local nom, seq = Choisir(ent, noms)
    if ent:IsPlayer() then
        NA_AnimJutsu(ent, nom)   -- diffusée à tous les clients (jutsu_anim_cl.lua)
    elseif seq and seq >= 0 then
        ent:AddGestureSequence(seq, true)   -- nextbot : le geste est synchronisé par le moteur
    end
    return seq and seq >= 0 and math.max(ent:SequenceDuration(seq), 0.2) or 0.5
end

local victimes = {}   -- joueur touché -> { debut, enLair, boucleFin }

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

    NA_AnimJutsu(ply, ANIM_FIN)

    ParticleEffect(PARTICULE, pos, angle_zero)
    for i = 1, NB_PARTICULES - 1 do
        local a = i / (NB_PARTICULES - 1) * math.pi * 2
        ParticleEffect(PARTICULE, pos + Vector(math.cos(a), math.sin(a), 0) * 150, angle_zero)
    end
    if NA_SenjuRocher then NA_SenjuRocher(pos, ply:EyeAngles().y, ROCHER_ECHELLE, ROCHER_DUREE) end
    sound.Play(SON, pos, 100, 60, 1)
    util.ScreenShake(pos, 16, 12, 1, 1200)

    for _, ent in ipairs(ents.FindInSphere(pos, Niv(ply, "rayon", RAYON))) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CRUSH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        if Victime(ent) then   -- les autres PNJ n'ont pas d'animation de geste
            Jouer(ent, VICTIME_TOUCHE)
            victimes[ent] = { debut = CurTime(), enLair = false }
        end

        -- projeté en s'éloignant du point d'impact
        local dir = ent:WorldSpaceCenter() - pos
        dir.z = 0
        local v = dir:GetNormalized() * Niv(ply, "projection", PROJECTION) + Vector(0, 0, Niv(ply, "proj_haut", PROJ_HAUT))
        NA_Propulser(ent, v)
    end
end

-- (re)lance l'animation de plongeon quand la précédente est finie : le geste ne boucle pas tout seul
local function Boucler(ply, a)
    local now = CurTime()
    if now < (a.boucleFin or 0) then return end
    a.boucleFin = now + Jouer(ply, { ANIM_BOUCLE })
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

net.Receive("senju_pied_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "senju_pied") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "senju_pied", recharge) end   -- recharge visible dans la barre

    actifs[ply] = { plonge = false }
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)

    NA_AnimJutsu(ply, ANIM_DEBUT)   -- animation + pas de coups pendant (_na_mudra.lua)

    local vel = ply:GetVelocity()
    ply:SetVelocity(Vector(-vel.x, -vel.y, Niv(ply, "saut", SAUT) - vel.z))

    timer.Simple(Niv(ply, "delai_plongee", DELAI_PLONGEE), function() Plonger(ply) end)
end)

-- Suivi du plongeon : atterrissage, choc contre un mur, temps écoulé
hook.Add("Think", "SenjuPied_Suivi", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() then
            Terminer(ply)
        elseif a.plonge then
            -- pas de coups pendant le plongeon : renouvelé seulement quand il s'épuise (évite un envoi réseau à chaque tick)
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

-- Joueurs touchés : animation de chute tant qu'ils sont en l'air, puis animation au sol
hook.Add("Think", "SenjuPied_Victimes", function()
    for ent, v in pairs(victimes) do
        local t = CurTime() - v.debut
        if not IsValid(ent) or not Vivant(ent) or t > 6 then
            victimes[ent] = nil
        elseif t > 0.3 then
            if not ent:IsOnGround() then
                v.enLair = true
                if CurTime() >= (v.boucleFin or 0) then v.boucleFin = CurTime() + Jouer(ent, VICTIME_CHUTE) end
            elseif v.enLair or t > 1 then
                if v.enLair then Jouer(ent, VICTIME_SOL) end   -- retombé après avoir décollé
                victimes[ent] = nil
            end
        end
    end
end)

-- pas de dégâts de chute pendant la technique
hook.Add("GetFallDamage", "SenjuPied_SansChute", function(ply)
    if actifs[ply] then return 0 end
end)

hook.Add("PlayerDeath", "SenjuPied_Mort", function(ply) Terminer(ply) end)
hook.Add("PlayerSpawn", "SenjuPied_Spawn", function(ply) Terminer(ply) end)
hook.Add("PlayerDisconnected", "SenjuPied_Nettoyage", function(ply)
    actifs[ply] = nil
    victimes[ply] = nil
    pret[ply] = nil
end)
