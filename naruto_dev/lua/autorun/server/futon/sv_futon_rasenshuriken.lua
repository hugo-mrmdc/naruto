--========================================================
-- Futon : Rasenshuriken (SERVEUR) - rang S
--
-- Après les mudras, le lanceur MONTE dans les airs et joue l'animation ANIM_APPEL pendant que la particule rasenshuri_pat
-- tourne dans sa main droite (NW2Float "NA_RasenFin", affichée par cl_futon_rasenshuriken.lua). Au moment du lancer, le Rasenshuriken
-- (entité futon_rasenshuriken) part droit devant lui, là où il regarde ; au premier contact il explose
-- ([1]Rasenshuriken_Explosion_event_test) : dégâts + projection autour. Puis le lanceur redescend.
--
-- Réseau : "futon_rasen_cast" (client -> serveur), "futon_rasen_fx" (serveur -> clients : explosion)
--========================================================

util.AddNetworkString("futon_rasen_cast")
util.AddNetworkString("futon_rasen_fx")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 120    -- dégâts de l'explosion (réduits avec la distance)
local RAYON        = 350    -- rayon de l'explosion
local VITESSE      = 1400   -- vitesse du Rasenshuriken
local DUREE_VIE    = 3      -- secondes avant qu'il disparaisse sans rien toucher
local POUSSEE      = 500    -- projection horizontale des ennemis touchés
local SOULEVE      = 300    -- projection verticale
local HAUTEUR      = 350    -- montée du lanceur (unités)
local VITESSE_MONTEE = 700
local DELAI_LANCER = 1.0    -- secondes entre le début de l'animation et le lancer
local FIN_ANIM     = 0.6    -- secondes en l'air après le lancer, avant de redescendre

local RECHARGE     = 40
local CHAKRA_COUT  = 80
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_MUDRA   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_APPEL   = "nrp_ninjutsu_attack_truerasenshuriken"
local ATTACHE_MAIN = "anim_attachment_RH"   -- main DROITE (la gauche est LH : voir cl_raiton_chidori.lua)
--========================================================

local ID = "futon_rasenshuriken"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("rasenshuri_pat")
PrecacheParticleSystem("[1]Rasenshuriken_Explosion_event_test")

local enCours = {}   -- joueur -> true pendant toute la technique
local pret    = {}
local function TimerNom(ply, n) return "futon_rasen_" .. n .. "_" .. ply:EntIndex() end

local function Terminer(ply)
    local etait = enCours[ply]
    enCours[ply] = nil
    if not IsValid(ply) then return end
    timer.Remove(TimerNom(ply, "montee"))
    timer.Remove(TimerNom(ply, "lancer"))
    timer.Remove(TimerNom(ply, "fin"))
    ply:SetNW2Float("NA_RasenFin", 0)
    if etait then
        ply:SetNW2Bool("NA_Canalise", false)   -- les autres jutsu sont de nouveau permis
        ply:SetNW2Bool("NA_Vol", false)
        ply:SetNW2Float("NA_MonteVit", -1)
        ply.MokutonNoFall = CurTime() + 10   -- on retombe de haut : pas de dégâts de chute
    end
end

-- position de la main droite (sinon devant la poitrine)
local function PosMain(ply)
    local att = ply:LookupAttachment(ATTACHE_MAIN)
    if att and att > 0 then
        local a = ply:GetAttachment(att)
        if a then return a.Pos end
    end
    return ply:GetShootPos() + ply:GetAimVector() * 30 + ply:GetRight() * 12 - Vector(0, 0, 8)
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then Terminer(ply) return end

    local depart = PosMain(ply)
    -- direction : vers le point visé (pas juste le regard depuis les yeux, la main est décalée)
    local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 8000, filter = ply, mask = MASK_SOLID })
    local dir = (tr.HitPos - depart):GetNormalized()
    if dir:Dot(ply:GetAimVector()) < 0.5 then dir = ply:GetAimVector() end

    local ent = ents.Create("futon_rasenshuriken")
    if IsValid(ent) then
        ent:SetPos(depart)
        ent:SetAngles(dir:Angle())
        ent:SetOwner(ply)
        ent.Dir     = dir
        ent.Vitesse = Niv(ply, "vitesse", VITESSE)
        ent.Vie     = Niv(ply, "duree_vie", DUREE_VIE)
        ent.Degats  = Niv(ply, "degats", DEGATS)
        ent.Rayon   = Niv(ply, "rayon", RAYON)
        ent.Poussee = Niv(ply, "poussee", POUSSEE)
        ent.Souleve = Niv(ply, "souleve", SOULEVE)
        ent:Spawn()
    end

    ply:SetNW2Float("NA_RasenFin", 0)   -- la particule de la main s'arrête : la boule est partie
    ply:EmitSound("naruto_sound/jutsu/futon/futon11.wav", 80, 110)
    timer.Create(TimerNom(ply, "fin"), Niv(ply, "fin_anim", FIN_ANIM), 1, function() Terminer(ply) end)
end

local function CommencerAnim(ply)
    local delai = Niv(ply, "delai_lancer", DELAI_LANCER)
    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:SetNW2Float("NA_MonteVit", 0)   -- en l'air, immobile
    ply:SetNW2Float("NA_RasenFin", CurTime() + delai)
    timer.Create(TimerNom(ply, "lancer"), delai, 1, function() Lancer(ply) end)
end

net.Receive("futon_rasen_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Dragon", false) then return end

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
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    enCours[ply] = true
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu pendant toute la technique (_na_registre.lua)

    NA_AnimJutsu(ply, ANIM_MUDRA)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then Terminer(ply) return end

        -- montée (même mécanique que la Déflagration Bakuton : NA_Vol + NA_MonteVit, lus par kami/sh_kami_wings_move.lua)
        local hauteur, vitesse = Niv(ply, "hauteur", HAUTEUR), Niv(ply, "vitesse_montee", VITESSE_MONTEE)
        local depart = ply:GetPos().z
        ply:SetNW2Bool("NA_Vol", true)
        ply:SetNW2Float("NA_MonteVit", vitesse)

        local fait = false
        local function Haut()
            if fait then return end
            fait = true
            timer.Remove(TimerNom(ply, "montee"))
            if IsValid(ply) and ply:Alive() then CommencerAnim(ply) else Terminer(ply) end
        end
        timer.Create(TimerNom(ply, "montee"), 0.05, 0, function()
            if not IsValid(ply) or not ply:Alive() then Terminer(ply) return end
            -- hauteur atteinte, ou bloqué par un plafond
            if ply:GetPos().z - depart >= hauteur or (ply:GetVelocity().z < vitesse * 0.3 and ply:GetPos().z - depart > 50) then Haut() end
        end)
        -- sécurité : coincé sous un plafond dès le départ
        timer.Simple(hauteur / vitesse + 1.5, Haut)
    end)
end)

hook.Add("PlayerDeath", "FutonRasen_Mort", Terminer)
hook.Add("PlayerSpawn", "FutonRasen_Spawn", function(ply) if enCours[ply] then Terminer(ply) end end)
hook.Add("PlayerDisconnected", "FutonRasen_Nettoyage", function(ply)
    Terminer(ply)
    pret[ply] = nil
end)
