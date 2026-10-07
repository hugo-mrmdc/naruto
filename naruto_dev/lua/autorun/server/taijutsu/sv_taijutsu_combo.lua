--========================================================
-- Taijutsu : Enchaînement aérien (SERVEUR)
--
--   1. Coup de pied relevé (m_attack_hand_backkick) : la cible touchée
--      devant le lanceur est envoyée en l'air.
--   2. Au sommet, la cible reste suspendue (étourdie, animation
--      M_Beaten_SpinBlowOff) et le lanceur la rejoint.
--   3. Coup de talon plongeant (m_attack_aerial_hand_turnheeldropkick) : dégâts
--      et la cible est écrasée au sol.
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_combo_cast")
util.AddNetworkString("taijutsu_hitb_fx")   -- particule d'impact (cl_taijutsu_hitfx.lua)
util.AddNetworkString("taijutsu_sol_fx")    -- poussière quand la cible retouche le sol

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

local ANIM_LANCER    = "m_attack_hand_backkick"
local ANIM_VITESSE   = 2      -- vitesse de lecture de l'animation (2 = deux fois plus vite)
local ANIM_COUPE     = 0.35   -- l'animation contient 2 coups de pied : on la coupe après le premier (secondes réelles)
local ANIM_FINAL     = "m_attack_aerial_hand_turnheeldropkick"
local ANIM_CIBLE     = "M_Beaten_SpinBlowOff"
local DISTANCE_COTE  = 70     -- à quelle distance de la cible le lanceur se place
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "taijutsu_combo", stat, base) end

local enCours = {}
local pret    = {}

-- Pendant toute la technique : ni coups de poing (NA_Mudra, _na_mudra.lua) ni autre jutsu (NA_Canalise, _na_registre.lua)
local function Verrouiller(ply)
    ply:SetNW2Bool("NA_Canalise", true)
end

-- Rend la main quand l'animation en cours (donc le verrou des coups, NA_MudraFin) est finie
local function Deverrouiller(ply)
    if not IsValid(ply) then return end
    local reste = math.max(ply:GetNW2Float("NA_MudraFin", 0) - CurTime(), 0)
    timer.Simple(reste, function()
        if IsValid(ply) and not enCours[ply] then ply:SetNW2Bool("NA_Canalise", false) end
    end)
end

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

local function ParticuleImpact(cible)
    net.Start("taijutsu_hitb_fx")
        net.WriteVector(cible:WorldSpaceCenter())
    net.Broadcast()
end

local function Degats(ply, cible, montant)
    local dmg = DamageInfo()
    dmg:SetDamage(montant)
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)
    ParticuleImpact(cible)
end

local function Liberer(ply, cible)
    enCours[ply] = nil
    if IsValid(cible) then
        if NA_Liberer then NA_Liberer(cible) end
    end
    if IsValid(ply) and ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
    Deverrouiller(ply)   -- attend la fin de l'animation en cours avant de rendre les jutsus
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

    -- poussière quand la cible retouche le sol
    local t0 = CurTime()
    local id = "TaijutsuCombo_Sol_" .. cible:EntIndex()
    timer.Create(id, 0.05, 0, function()
        if not IsValid(cible) or CurTime() - t0 > 2 then timer.Remove(id) return end
        if CurTime() - t0 < 0.1 then return end
        local au_sol = cible.loco and cible.loco:IsOnGround() or cible:IsOnGround()
        if not au_sol then return end
        timer.Remove(id)
        net.Start("taijutsu_sol_fx")
            net.WriteVector(cible:GetPos())
        net.Broadcast()
    end)
end

-- Étape 2 : au sommet, la cible reste suspendue et le lanceur la rejoint
local function Sommet(ply, cible)
    if not IsValid(ply) or not ply:Alive() or not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) then
        return Liberer(ply, cible)
    end

    local delai = Niv(ply, "delai_final", DELAI_FINAL)
    if NA_Etourdir then NA_Etourdir(cible, delai + 0.3, ANIM_CIBLE, true, true) end   -- suspendue en l'air, anim jouée une fois (sv_etourdissement.lua)

    -- le lanceur se place à côté de la cible, face à elle
    local pos = cible:GetPos()
    local dir = pos - ply:GetPos()
    dir.z = 0
    if dir:LengthSqr() < 1 then dir = ply:GetForward() end
    dir:Normalize()
    -- place libre à DISTANCE_COTE de la cible : on essaie d'abord derrière lanceur->cible, puis sur les
    -- côtés, puis de l'autre côté (mur, décor...). Jamais dans la cible ni dans le décor.
    local dest
    for _, rot in ipairs({ 0, 45, -45, 90, -90, 135, -135, 180 }) do
        local d = Angle(0, rot, 0):Forward()
        local v = Vector(dir.x * d.x - dir.y * d.y, dir.x * d.y + dir.y * d.x, 0)   -- dir tourné de rot degrés
        local essai = pos - v * DISTANCE_COTE
        -- décor seulement (props, joueurs, PNJ ignorés), hull un peu plus étroite et relevée : une cible
        -- fixée au sol (stun lourd) ne doit pas faire échouer le trace sur le sol ou une marche
        local haut = Vector(0, 0, 8)
        local mins, maxs = ply:OBBMins(), ply:OBBMaxs()
        mins.x, mins.y, maxs.x, maxs.y = mins.x * 0.8, mins.y * 0.8, maxs.x * 0.8, maxs.y * 0.8
        maxs.z = maxs.z - 8
        local tr = util.TraceHull({
            start = pos + haut, endpos = essai + haut,
            mins = mins, maxs = maxs, filter = { ply, cible },
            mask = MASK_PLAYERSOLID_BRUSHONLY,
        })
        if not tr.Hit and not tr.StartSolid then dest = essai break end
    end
    ply:SetPos(dest or pos - dir * DISTANCE_COTE)
    ply:SetEyeAngles(Angle(0, dir:Angle().y, 0))
    ply:SetVelocity(-ply:GetVelocity())
    ply:SetMoveType(MOVETYPE_NONE)   -- reste en l'air le temps du coup

    NA_AnimJutsu(ply, ANIM_FINAL)
    NA_Mudra(ply, delai + 0.2)   -- pas de coups jusqu'au coup de talon
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
    NA_Mudra(ply, Niv(ply, "delai_sommet", DELAI_SOMMET) + 0.2)   -- pas de coups jusqu'à ce que le lanceur rejoigne la cible

    -- l'animation de la cible démarre dès l'impact. Pas de NA_Etourdir ici : il la figerait
    -- sur place et annulerait l'élan. Le vrai stun arrive au sommet (Sommet) et garde la même anim.
    cible:SetNW2String("NA_EtourdiAnim", ANIM_CIBLE)
    cible:SetNW2Bool("NA_EtourdiUneFois", true)
    cible:SetNW2Int("NA_EtourdiAnimId", cible:GetNW2Int("NA_EtourdiAnimId", 0) + 1)
    cible:SetNW2Bool("NA_Etourdi", true)

    if NA_Projeter then NA_Projeter(cible) end   -- sous stun souple : emportée ; stun ferme : ne bouge pas (sv_etourdissement.lua)
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

    NA_AnimJutsu(ply, ANIM_LANCER, ANIM_COUPE, ANIM_VITESSE)   -- animation + pas de coups pendant sa durée (_na_mudra.lua)
    Verrouiller(ply)
    NA_Mudra(ply, Niv(ply, "delai_impact", DELAI_IMPACT) + 0.1)

    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function() Frapper(ply) end)
end)

hook.Add("PlayerDeath", "TaijutsuCombo_Mort", function(ply)
    if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
    enCours[ply] = nil
    ply:SetNW2Bool("NA_Canalise", false)
end)
hook.Add("PlayerDisconnected", "TaijutsuCombo_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
