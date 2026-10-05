--========================================================
-- Taijutsu : Enchaînement aérien (SERVEUR)
--
--   1. Coup de pied relevé (m_attack_hand_lowkicktokickup) : la cible touchée
--      devant le lanceur est envoyée en l'air.
--   2. Au sommet, la cible reste suspendue (étourdie, animation
--      m_ni_def_ninjutsu_aerial_palmrotation_loop) et le lanceur la rejoint.
--   3. Coup de talon plongeant (m_attack_aerial_hand_turnheeldropkick) : dégâts
--      et la cible est écrasée au sol.
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_combo_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS         = 15     -- dégâts du premier coup
local DEGATS_FINAL   = 40     -- dégâts du coup de talon
local PORTEE         = 150    -- distance max du premier coup
local ANGLE          = 60     -- demi-angle du cône devant le lanceur (degrés)
local LANCER         = 450    -- vitesse verticale donnée à la cible
local ECRASER        = 1400   -- vitesse vers le bas du coup final

local RECHARGE       = 18
local CHAKRA_COUT    = 30
local CHAKRA_MAX     = NA_CHAKRA_MAX or 100
local DELAI_IMPACT   = 0.35   -- lancer de l'anim 1 -> la cible décolle
local DELAI_SOMMET   = 0.45   -- décollage -> le lanceur rejoint la cible
local DELAI_FINAL    = 0.5    -- rejoint la cible -> coup de talon

local ANIM_LANCER    = "m_attack_hand_lowkicktokickup"
local ANIM_FINAL     = "m_attack_aerial_hand_turnheeldropkick"
local ANIM_CIBLE     = "m_ni_def_ninjutsu_aerial_palmrotation_loop"
local DISTANCE_COTE  = 70     -- à quelle distance de la cible le lanceur se place
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "taijutsu_combo", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Cible la plus proche dans le cône devant le lanceur
local function TrouverCible(ply)
    local origine = ply:GetPos()
    local avant = ply:GetForward()
    avant.z = 0
    avant:Normalize()
    local seuil = math.cos(math.rad(ANGLE))
    local portee = Niv(ply, "portee", PORTEE)
    local meilleure, dist = nil, math.huge

    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), portee)) do
        if not EstCible(ent, ply) then continue end
        local dir = ent:GetPos() - origine
        dir.z = 0
        local d = dir:LengthSqr()
        if d > 1 and dir:GetNormalized():Dot(avant) < seuil then continue end
        if d < dist then meilleure, dist = ent, d end
    end
    return meilleure
end

local function Degats(ply, cible, montant)
    local dmg = DamageInfo()
    dmg:SetDamage(montant)
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)
end

local function Liberer(ply, cible)
    enCours[ply] = nil
    if IsValid(cible) then
        if cible:IsPlayer() then cible:SetNW2String("NA_EtourdiAnim", "") end
        if NA_Liberer then NA_Liberer(cible) end
    end
    if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
end

-- Étape 3 : coup de talon, la cible est écrasée au sol
local function Final(ply, cible)
    if not IsValid(ply) or not ply:Alive() or not IsValid(cible) then return Liberer(ply, cible) end

    Degats(ply, cible, Niv(ply, "degats_final", DEGATS_FINAL))
    Liberer(ply, cible)

    local vel = Vector(0, 0, -Niv(ply, "ecraser", ECRASER))
    if cible.loco then
        cible.loco:SetVelocity(vel)   -- NextBot
    else
        cible:SetVelocity(vel)
    end
end

-- Étape 2 : au sommet, la cible reste suspendue et le lanceur la rejoint
local function Sommet(ply, cible)
    if not IsValid(ply) or not ply:Alive() or not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) then
        return Liberer(ply, cible)
    end

    local delai = Niv(ply, "delai_final", DELAI_FINAL)
    if NA_Etourdir then NA_Etourdir(cible, delai + 0.3) end   -- suspendue en l'air (sv_etourdissement.lua)
    if cible:IsPlayer() then cible:SetNW2String("NA_EtourdiAnim", ANIM_CIBLE) end

    -- le lanceur se place à côté de la cible, face à elle
    local pos = cible:GetPos()
    local dir = pos - ply:GetPos()
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = ply:GetForward() end
    dir:Normalize()
    local dest = pos - dir * DISTANCE_COTE
    local tr = util.TraceHull({
        start = pos, endpos = dest,
        mins = ply:OBBMins(), maxs = ply:OBBMaxs(), filter = { ply, cible },
    })
    ply:SetPos(tr.HitPos)
    ply:SetEyeAngles(Angle(0, dir:Angle().y, 0))
    ply:SetVelocity(-ply:GetVelocity())
    ply:SetMoveType(MOVETYPE_NONE)   -- reste en l'air le temps du coup

    NA_AnimJutsu(ply, ANIM_FINAL)
    timer.Simple(delai, function() Final(ply, cible) end)
end

-- Un NextBot (faux joueur d'entraînement) reste collé au sol quand on lui donne de la
-- vitesse vers le haut : on le soulève donc image par image jusqu'à la hauteur
-- qu'atteindrait un joueur au sommet.
local function Soulever(cible, vitesse, duree)
    local g = GetConVar("sv_gravity"):GetFloat()
    local haut = vitesse * duree - 0.5 * g * duree * duree
    local depart = cible:GetPos()
    local t0 = CurTime()
    local id = "TaijutsuCombo_Haut_" .. cible:EntIndex()
    timer.Create(id, 0, 0, function()
        if not IsValid(cible) then timer.Remove(id) return end
        local k = math.min((CurTime() - t0) / duree, 1)
        cible:SetPos(depart + Vector(0, 0, haut * (1 - (1 - k) * (1 - k))))   -- freine vers le sommet
        if k >= 1 then timer.Remove(id) end
    end)
end

-- Étape 1 : coup de pied relevé, la cible décolle
local function Frapper(ply)
    if not IsValid(ply) or not ply:Alive() then return Liberer(ply) end

    local cible = TrouverCible(ply)
    if not cible then return Liberer(ply) end

    Degats(ply, cible, Niv(ply, "degats", DEGATS))

    local vel = Vector(0, 0, Niv(ply, "lancer", LANCER))
    local delaiSommet = Niv(ply, "delai_sommet", DELAI_SOMMET)
    if cible.loco then
        Soulever(cible, vel.z, delaiSommet)   -- NextBot
    else
        cible:SetVelocity(vel)
    end

    timer.Simple(delaiSommet, function() Sommet(ply, cible) end)
end

net.Receive("taijutsu_combo_cast", function(_, ply)
    if not NA_Debloquee(ply, "taijutsu_combo") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "taijutsu_combo", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_LANCER)   -- animation + pas de coups pendant sa durée (_na_mudra.lua)

    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function() Frapper(ply) end)
end)

hook.Add("PlayerDeath", "TaijutsuCombo_Mort", function(ply)
    if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
    enCours[ply] = nil
end)
hook.Add("PlayerDisconnected", "TaijutsuCombo_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
