--========================================================
-- Taijutsu : Coup de pied tournoyant (SERVEUR)
--
-- Coup de pied circulaire au corps à corps : blesse, repousse et étourdit
-- les ennemis dans le cône devant le lanceur. Pas de mudras : l'animation
-- (m_ni_atk_ninjutsu_d54nj3_spinkickend) EST la frappe ; elle part
-- DELAI_IMPACT secondes après le lancement.
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_pied_cast")
util.AddNetworkString("taijutsu_pied_fx")   -- particule sur la cible touchée
resource.AddFile("particles/patlick_atgparticules.pcf")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 28
local PORTEE       = 130    -- distance max de la frappe
local ANGLE        = 70     -- demi-angle du cône devant le lanceur (degrés)
local RECUL        = 350
local SOULEVE      = 60
local ETOURDI      = 1.5    -- secondes d'étourdissement de la cible

local RECHARGE     = 8
local CHAKRA_COUT  = 10
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DELAI_IMPACT = 0.4
local ANIM_APPEL   = "m_ni_atk_ninjutsu_d54nj3_spinkickend"

local SON_IMPACT   = "dimix/sond/taijutsu/hit3.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "taijutsu_pied", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Frapper(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = Niv(ply, "portee", PORTEE)

    local origine = ply:GetPos()
    local avant = ply:GetForward()
    avant.z = 0
    avant:Normalize()
    local seuil = math.cos(math.rad(ANGLE))

    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), portee)) do
        if not EstCible(ent, ply) then continue end

        local dir = ent:GetPos() - origine
        dir.z = 0
        if dir:LengthSqr() > 1 and dir:GetNormalized():Dot(avant) < seuil then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        if dir:LengthSqr() < 1 then dir = avant end
        local vel = dir:GetNormalized() * Niv(ply, "recul", RECUL) + Vector(0, 0, Niv(ply, "souleve", SOULEVE))
        if ent.loco then
            ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
        else
            ent:SetVelocity(vel)
        end

        if NA_Etourdir then NA_Etourdir(ent, Niv(ply, "etourdi", ETOURDI)) end   -- sv_etourdissement.lua
        net.Start("taijutsu_pied_fx")
            net.WriteVector(ent:WorldSpaceCenter() + Vector(0, 0, 20))   -- un peu plus haut que le torse
        net.Broadcast()
        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110))
    end
end

net.Receive("taijutsu_pied_cast", function(_, ply)
    if not NA_Debloquee(ply, "taijutsu_pied") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    if chakra < cout then
        ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "taijutsu_pied", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant sa durée (_na_mudra.lua)

    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function()
        enCours[ply] = nil
        Frapper(ply)
    end)
end)

hook.Add("PlayerDeath", "TaijutsuPied_Mort", function(ply) enCours[ply] = nil end)
hook.Add("PlayerDisconnected", "TaijutsuPied_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
