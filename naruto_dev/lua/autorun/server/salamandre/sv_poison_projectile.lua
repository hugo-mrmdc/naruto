--========================================================
-- Crachat de poison de la salamandre (SERVEUR)
--
-- Le serveur décide de tout : incantation, animations, départ du crachat,
-- recharge et chakra. Le client ne fait qu'appuyer sur la touche.
-- Le projectile lui-même est l'entité salamandre_poison_spit (lua/entities).
--========================================================

if not SERVER then return end

util.AddNetworkString("PoisonProjectile_Fire")

-- Particules (déclarées aussi côté client dans salamandre_init.lua)
game.AddParticles("particles/godio_salamandre.pcf")
PrecacheParticleSystem("godio_crachat_sala")
PrecacheParticleSystem("godio_impact_sala")
resource.AddFile("particles/godio_salamandre.pcf")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

-- Projectile
local DEGATS_IMPACT  = 50     -- dégâts du crachat à l'impact
local VITESSE        = 1500   -- vitesse du crachat
local DUREE_VIE      = 3      -- secondes avant qu'il disparaisse s'il ne touche rien
local GRAVITE        = 0      -- retombée en cloche (0 = ligne droite, 400 = arc net)
local RAYON          = 6      -- demi-largeur de la zone de touche

-- Poison
local POISON_DEGATS  = 10     -- dégâts par tick de poison
local POISON_TICK    = 1      -- secondes entre deux ticks
local POISON_DUREE   = 5      -- durée du poison (un nouveau crachat la relance)

-- Lancer
local DUREE_MUDRA    = 1.0    -- mudras avant l'animation de crachat
local DELAI_LANCER   = 0.5    -- entre le début du crachat et le départ du projectile
local RECHARGE       = 1.0    -- après le départ, avant de pouvoir relancer
local CHAKRA_COUT    = 10     -- chakra par crachat (0 = gratuit)
local CHAKRA_MAX     = 100    -- doit correspondre à sv_sprint_chakra.lua

local ANIM_MUDRA     = "nrp_ninjutsu_defend_dragonflamebombs_start"   -- anim_extension_mod6.mdl
local ANIM_CRACHAT   = "nrp_ninjutsu_trow_fireball_lv3"               -- anim_extension_mod6.mdl

--========================================================

local function PlayAnim(ply, seq)
    if not IsValid(ply) or not seq or seq == "" then return end
    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(seq)
    net.Broadcast()
end

----------------------------------------------------------
-- Système de poison (réutilisable par les autres techniques de la salamandre)
----------------------------------------------------------
SalamandrePoison = SalamandrePoison or {}

local empoisonnes = {}   -- entité -> { attaquant, fin, prochain }

-- Empoisonne une cible (ou relance la durée si elle l'est déjà)
function SalamandrePoison.Apply(cible, attaquant, duree)
    if not IsValid(cible) then return end
    -- immunité temporaire (Corps de poison, sv_corps_poison.lua)
    if (cible.NA_ImmunitePoison or 0) > CurTime() then return end

    local fin = CurTime() + (duree or POISON_DUREE)
    local data = empoisonnes[cible]

    if data then
        data.fin = fin
        data.attaquant = attaquant
        return
    end

    empoisonnes[cible] = {
        attaquant = attaquant,
        fin = fin,
        prochain = CurTime() + POISON_TICK,
    }

    if cible:IsPlayer() then
        cible:SetNW2Bool("NA_Empoisonne", true)
        cible:ScreenFade(SCREENFADE.IN, Color(0, 255, 0, 50), 0.5, 0)
        cible:PrintMessage(HUD_PRINTCENTER, "Vous êtes empoisonné !")
    end
end

function SalamandrePoison.Stop(cible, message)
    if not empoisonnes[cible] then return end
    empoisonnes[cible] = nil

    if IsValid(cible) and cible:IsPlayer() then
        cible:SetNW2Bool("NA_Empoisonne", false)
        if message then cible:PrintMessage(HUD_PRINTCENTER, "Le poison s'est dissipé") end
    end
end

function SalamandrePoison.IsPoisoned(cible)
    return empoisonnes[cible] ~= nil
end

timer.Create("SalamandrePoison_Tick", 0.1, 0, function()
    local now = CurTime()

    for cible, data in pairs(empoisonnes) do
        if not IsValid(cible) or cible:Health() <= 0 or (cible:IsPlayer() and not cible:Alive()) then
            SalamandrePoison.Stop(cible)
            continue
        end

        if now >= data.fin then
            SalamandrePoison.Stop(cible, true)
            continue
        end

        if now >= data.prochain then
            data.prochain = now + POISON_TICK

            -- DMG_ACID et pas DMG_POISON : le code joueur de Half-Life 2 rend
            -- progressivement la vie perdue par DMG_POISON, le poison se soignait seul.
            local dmg = DamageInfo()
            dmg:SetDamage(NA_Stat(data.attaquant, "salamandre_poison", "degats", POISON_DEGATS))
            dmg:SetAttacker(IsValid(data.attaquant) and data.attaquant or cible)
            dmg:SetInflictor(IsValid(data.attaquant) and data.attaquant or cible)
            dmg:SetDamageType(DMG_ACID)
            cible:TakeDamageInfo(dmg)

            if cible:IsPlayer() then
                cible:ScreenFade(SCREENFADE.IN, Color(0, 255, 0, 30), 0.3, 0)
            end
        end
    end
end)

----------------------------------------------------------
-- Lancer
----------------------------------------------------------
local casting = {}
local nextUse = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- la direction est celle du regard AU MOMENT du départ, pas de l'appui
    local aim = ply:GetAimVector()

    local ent = ents.Create("salamandre_poison_spit")
    if not IsValid(ent) then return end

    ent:SetPos(ply:EyePos() + aim * 30)
    ent:SetAngles(aim:Angle())
    ent:SetOwner(ply)
    ent.Direction = aim
    ent.Vitesse = VITESSE
    ent.Degats = NA_Stat(ply, "salamandre_poison", "degats", DEGATS_IMPACT)
    ent.DureeVie = DUREE_VIE
    ent.Gravite = GRAVITE
    ent.Rayon = NA_Stat(ply, "salamandre_poison", "hitbox", RAYON)
    ent:Spawn()

    ply:EmitSound("npc/headcrab_poison/ph_poisonbite" .. math.random(1, 3) .. ".wav", 75, 110)
end

net.Receive("PoisonProjectile_Fire", function(_, ply)
    if not NA_Debloquee(ply, "salamandre_poison") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "salamandre_poison", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "salamandre_poison", "chakra", CHAKRA_COUT) then
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - NA_Stat(ply, "salamandre_poison", "chakra", CHAKRA_COUT)))
    end

    casting[ply] = true
    if NA_CD then NA_CD.Set(ply, "salamandre_poison", DUREE_MUDRA + DELAI_LANCER + NA_Stat(ply, "salamandre_poison", "recharge", RECHARGE)) end -- recharge visible dans la barre

    -- 1) mudras
    PlayAnim(ply, ANIM_MUDRA)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    -- 2) animation de crachat
    timer.Simple(DUREE_MUDRA, function()
        if not IsValid(ply) or not ply:Alive() then
            if IsValid(ply) then casting[ply] = nil end
            return
        end
        PlayAnim(ply, ANIM_CRACHAT)
    end)

    -- 3) départ du crachat
    timer.Simple(DUREE_MUDRA + DELAI_LANCER, function()
        if not IsValid(ply) then return end
        casting[ply] = nil
        nextUse[ply] = CurTime() + NA_Stat(ply, "salamandre_poison", "recharge", RECHARGE)
        Lancer(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "SalamandrePoison_Death", function(ply)
    casting[ply] = nil
    SalamandrePoison.Stop(ply)
end)

hook.Add("PlayerSpawn", "SalamandrePoison_Spawn", function(ply)
    SalamandrePoison.Stop(ply)
end)

hook.Add("PlayerDisconnected", "SalamandrePoison_Cleanup", function(ply)
    casting[ply] = nil
    nextUse[ply] = nil
    empoisonnes[ply] = nil
end)
