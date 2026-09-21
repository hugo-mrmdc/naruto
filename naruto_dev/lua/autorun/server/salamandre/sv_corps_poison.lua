--========================================================
-- Corps de poison de la salamandre (SERVEUR)
--
-- Pendant quelques secondes, le corps du lanceur suinte le poison :
--   - contact : tout ce qui est collé à lui prend de l'acide et est empoisonné ;
--   - riposte : quiconque le frappe de près est empoisonné ;
--   - immunité : le lanceur ne peut plus être empoisonné (et son poison est purgé).
-- Aura godio_aura_sala (particles/godio_salamandre.pcf), visible par tous.
--========================================================

if not SERVER then return end

util.AddNetworkString("salamandre_corps_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE            = 10     -- durée du corps de poison (secondes)
local RAYON_CONTACT    = 90     -- distance de "contact" autour du corps
local DEGATS_CONTACT   = 4      -- dégâts d'acide par tick au contact (0 = poison seul)
local INTERVALLE       = 0.5    -- secondes entre deux ticks de contact
local POISON_DUREE     = 4      -- poison infligé (contact et riposte)
local RIPOSTE_DISTANCE = 150    -- qui te frappe de plus près que ça est empoisonné (0 = pas de riposte)
local IMMUNISE         = true   -- le lanceur ne peut pas être empoisonné pendant la technique
local RECHARGE         = 15     -- secondes après la FIN avant de pouvoir relancer
local CHAKRA_COUT      = 20     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX       = 100    -- doit correspondre à sv_sprint_chakra.lua
local DUREE_MUDRA      = 0.8    -- incantation avant l'aura
local ANIM_APPEL       = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

resource.AddFile("particles/godio_salamandre.pcf")

local actifs  = {}   -- joueur -> { fin, minuteur }
local casting = {}
local nextUse = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Empoisonner(cible, lanceur, avecDegats)
    if avecDegats and DEGATS_CONTACT > 0 then
        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(lanceur, "salamandre_corps", "degats", DEGATS_CONTACT))
        dmg:SetAttacker(lanceur)
        dmg:SetInflictor(lanceur)
        dmg:SetDamageType(DMG_ACID)
        dmg:SetDamagePosition(cible:WorldSpaceCenter())
        cible:TakeDamageInfo(dmg)
    end

    if POISON_DUREE > 0 and SalamandrePoison and SalamandrePoison.Apply then
        SalamandrePoison.Apply(cible, lanceur, POISON_DUREE)
    end
end

local function Arreter(ply)
    local data = actifs[ply]
    if not data then return end
    actifs[ply] = nil

    timer.Remove(data.minuteur)

    if IsValid(ply) then
        ply:SetNW2Bool("NA_CorpsPoison", false)
        ply.NA_ImmunitePoison = nil
    end
end

local function Demarrer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local fin = CurTime() + DUREE
    local minuteur = "SalamandreCorps_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    actifs[ply] = { fin = fin, minuteur = minuteur }

    ply:SetNW2Bool("NA_CorpsPoison", true)

    if IMMUNISE then
        -- lue par SalamandrePoison.Apply (sv_poison_projectile.lua)
        ply.NA_ImmunitePoison = fin
        if SalamandrePoison and SalamandrePoison.Stop then SalamandrePoison.Stop(ply) end
    end

    ply:EmitSound("npc/headcrab_poison/ph_hiss1.wav", 75, 90)

    local prochainTick = CurTime()
    timer.Create(minuteur, 0.1, 0, function()
        if not IsValid(ply) or not ply:Alive() or CurTime() >= fin then
            Arreter(ply)
            return
        end

        if CurTime() < prochainTick then return end
        prochainTick = CurTime() + INTERVALLE

        for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), RAYON_CONTACT)) do
            if EstCible(ent, ply) then Empoisonner(ent, ply, true) end
        end
    end)
end

----------------------------------------------------------
-- Riposte : frapper un corps de poison de près empoisonne l'attaquant
----------------------------------------------------------
hook.Add("EntityTakeDamage", "SalamandreCorps_Riposte", function(cible, dmg)
    if RIPOSTE_DISTANCE <= 0 then return end
    if not actifs[cible] then return end

    local attaquant = dmg:GetAttacker()
    if not EstCible(attaquant, cible) then return end
    if attaquant:GetPos():DistToSqr(cible:GetPos()) > RIPOSTE_DISTANCE * RIPOSTE_DISTANCE then return end

    -- poison seul (pas de dégâts directs : pas de réaction en chaîne)
    Empoisonner(attaquant, cible, false)
end)

----------------------------------------------------------
-- Lancement
----------------------------------------------------------
net.Receive("salamandre_corps_cast", function(_, ply)
    if not NA_Debloquee(ply, "salamandre_corps") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or actifs[ply] then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "salamandre_corps", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "salamandre_corps", "chakra", CHAKRA_COUT) then
            return
        end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - NA_Stat(ply, "salamandre_corps", "chakra", CHAKRA_COUT)))
    end

    -- la recharge démarre après la fin de l'aura
    local total = DUREE_MUDRA + DUREE + NA_Stat(ply, "salamandre_corps", "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "salamandre_corps", total) end -- recharge visible dans la barre

    casting[ply] = true

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        if IsValid(ply) then casting[ply] = nil end
        Demarrer(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "SalamandreCorps_Death", function(ply)
    casting[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "SalamandreCorps_Spawn", function(ply)
    casting[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerDisconnected", "SalamandreCorps_Cleanup", function(ply)
    Arreter(ply)
    casting[ply] = nil
    nextUse[ply] = nil
end)
