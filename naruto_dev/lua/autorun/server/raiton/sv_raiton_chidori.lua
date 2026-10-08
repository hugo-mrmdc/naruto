--========================================================
-- Raiton : Chidori (SERVEUR)
--
-- 1. CHARGE : le lanceur charge la foudre dans sa main gauche (animation ANIM_CHARGE, particule
--    solve_raiton_aura_ruee affichée par cl_raiton_chidori.lua), immobile.
-- 2. COURSE : il fonce dans la direction où il regarde et PEUT TOURNER en courant (animation ANIM_COURSE FORCÉE en boucle
--    par le client, cl_raiton_chidori.lua) jusqu'à toucher un ennemi, un mur, ou la fin de la course.
-- 3. IMPACT : il frappe l'ennemi (animation ANIM_FIN, jouée aussi à la fin de la course si personne n'est touché) : dégâts, étourdissement STUN secondes, et au sol les mêmes
--    particules que le Poing de foudre (onde solve_raiton_chakramode_wave).
-- La course elle-même est tenue par sh_raiton_chidori.lua. Le serveur décide de tout : chakra, recharge, impact.
--
-- Réseau : "raiton_chidori_cast" (client -> serveur) ; l'onde d'impact réutilise le message "raiton_poing_impact"
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_chidori_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS         = 70
local STUN           = 2      -- secondes d'étourdissement de l'ennemi touché
local VITESSE        = 1000   -- vitesse de la course
local CHARGE         = 0.8    -- secondes de charge avant de courir
local COURSE_MAX     = 1.4    -- DURÉE de la course en secondes (portée = vitesse x durée) ; par niveau : stat "duree"
local PORTEE_CONTACT = 80     -- distance, devant le lanceur, à laquelle un ennemi est touché
local RAYON_CONTACT  = 70     -- rayon de la zone qui touche

local CHAKRA_COUT    = 55
local CHAKRA_MAX     = NA_CHAKRA_MAX or 100
local RECHARGE       = 18

-- Noms des animations : plusieurs possibles, la première qui existe sur le modèle du joueur est jouée.
-- "M_NI_SHT_Ninjutsu_Chidori_*" (packs anim_extension_bb / cancer, enregistrés dans wOS par
-- lua/wos/dynabase/registers/na_chidori_register.lua) ; "nrp_ninjutsu_trow_chidori_*" = les mêmes animations exposées
-- par anim_extension_mod6 / cyber (déjà chargées), en secours.
local ANIM_CHARGE    = { "M_NI_SHT_Ninjutsu_Chidori_Charge_Lv1", "nrp_ninjutsu_trow_chidori_charge_lv1", "m_ni_ninjutsu_chidori_charge_lv1" }
local ANIM_COURSE    = { "M_NI_SHT_Ninjutsu_Chidori_Run_Lv3_Loop", "nrp_ninjutsu_trow_chidori_run_lv3_loop", "m_ni_ninjutsu_chidori_run_lv3_loop" }     -- rejouée tant que dure la course
local ANIM_FIN       = { "M_NI_SHT_Ninjutsu_Chidori_Attack_Lv3_End", "nrp_ninjutsu_trow_chidori_attack_lv3_end", "m_ni_ninjutsu_chidori_attack_lv3_end" } -- à l'impact
--========================================================

local ID = "raiton_chidori"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_raiton.pcf")
game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_aura_ruee")

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { course, debut, vitesse, boucleFin } tant que la technique est en cours

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
    ply:SetNW2Float("NA_ChidoriFin", 0)   -- fin de la course ET de la particule de la main (client)
    ply:SetNW2Float("NA_ChidoriVit", 0)
    ply:SetNW2Bool("NA_Canalise", false)
end

-- Joue la première animation de la liste qui existe sur le modèle ; renvoie sa durée (pour la rejouer en boucle)
local function Jouer(ply, noms)
    for _, nom in ipairs(noms) do
        local seq = ply:LookupSequence(nom)
        if seq and seq >= 0 then
            NA_AnimJutsu(ply, nom)
            return math.max(ply:SequenceDuration(seq), 0.2)
        end
    end
    NA_AnimJutsu(ply, noms[1])   -- aucune trouvée : NA_AnimJutsu l'écrit dans la console (jutsu_anim_cl.lua)
    return 0.6
end

-- L'ennemi est touché
local function Toucher(ply, cible)
    local vitesse = ply:GetVelocity()
    Terminer(ply)
    if not ply:Alive() then return end

    ply:SetVelocity(Vector(-vitesse.x, -vitesse.y, 0))   -- la course s'arrête net
    Jouer(ply, ANIM_FIN)

    local dmg = DamageInfo()
    dmg:SetDamage(Niv(ply, "degats", DEGATS))
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_GENERIC)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)

    if NA_Etourdir then NA_Etourdir(cible, Niv(ply, "stun", STUN)) end   -- sv_etourdissement.lua

    -- au sol, sous l'ennemi : les mêmes particules que le Poing de foudre
    local tr = util.TraceLine({
        start = cible:GetPos() + Vector(0, 0, 20), endpos = cible:GetPos() - Vector(0, 0, 300),
        mask = MASK_SOLID_BRUSHONLY,
    })
    net.Start("raiton_poing_impact")   -- défini dans sv_raiton_poing.lua, joué par cl_raiton_poing.lua
        net.WriteVector(tr.Hit and tr.HitPos or cible:GetPos())
    net.Broadcast()
    sound.Play("naruto_sound/jutsu/raiton/raiton3.wav", cible:GetPos(), 85, 90, 1)
end

local function Courir(ply)
    local a = actifs[ply]
    if not a or not IsValid(ply) or not ply:Alive() then return end

    local vitesse = Niv(ply, "vitesse", VITESSE)
    ply:SetNW2Float("NA_ChidoriVit", vitesse)   -- direction : celle du regard, à chaque tick (sh_raiton_chidori.lua)
    ply:SetNW2Float("NA_ChidoriFin", CurTime() + a.duree)
    a.course = true
    a.debut = CurTime()
    a.vitesse = vitesse
end

net.Receive("raiton_chidori_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
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

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end   -- recharge visible dans la barre

    local charge = Niv(ply, "charge", CHARGE)
    actifs[ply] = { course = false, duree = Niv(ply, "duree", COURSE_MAX) }
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)
    ply:SetNW2Float("NA_ChidoriVit", 0)
    ply:SetNW2Float("NA_ChidoriFin", CurTime() + charge + Niv(ply, "duree", COURSE_MAX))   -- la particule de la main commence dès la charge

    Jouer(ply, ANIM_CHARGE)
    if NA_Mudra then NA_Mudra(ply, charge) end
    timer.Simple(charge, function() Courir(ply) end)
end)

-- Suivi de la course : contact avec un ennemi, mur, temps écoulé
hook.Add("Think", "RaitonChidori_Suivi", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() then
            Terminer(ply)
        elseif a.course then
            -- pas de coups pendant la course : renouvelé seulement quand il s'épuise
            if ply:GetNW2Float("NA_MudraFin", 0) - CurTime() < 0.2 then NA_Mudra(ply, 0.5) end

            -- ennemi devant le lanceur ?
            local dir = Angle(0, ply:EyeAngles().y, 0):Forward()   -- direction actuelle (il peut tourner)
            local centre = ply:GetPos() + dir * PORTEE_CONTACT + Vector(0, 0, 40)
            local cible, dMin = nil, math.huge
            for _, ent in ipairs(ents.FindInSphere(centre, RAYON_CONTACT)) do
                if EstCible(ent, ply) then
                    local d = ent:WorldSpaceCenter():DistToSqr(centre)
                    if d < dMin then cible, dMin = ent, d end
                end
            end

            local t = CurTime() - a.debut
            if cible then
                Toucher(ply, cible)
            elseif t > a.duree or (t > 0.15 and ply:GetVelocity():Length2D() < a.vitesse * 0.3) then   -- fin de course, ou mur
                local v = ply:GetVelocity()
                Terminer(ply)
                ply:SetVelocity(Vector(-v.x, -v.y, 0))
                Jouer(ply, ANIM_FIN)   -- course finie sans toucher personne (temps écoulé ou mur) : l'animation de fin se joue quand même
            end
        end
    end
end)

hook.Add("PlayerDeath", "RaitonChidori_Mort", function(ply) Terminer(ply) end)
hook.Add("PlayerSpawn", "RaitonChidori_Spawn", function(ply) Terminer(ply) end)
hook.Add("PlayerDisconnected", "RaitonChidori_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
