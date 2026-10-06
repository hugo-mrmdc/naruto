--========================================================
-- Taijutsu : Coup de pied relevé (SERVEUR)
--
-- Coup de pied au corps à corps (animation m_attack_hand_lowkicktokickup) : les
-- ennemis dans le cône devant le lanceur prennent des dégâts et sont projetés
-- en l'air. Pas de mudras : l'animation EST la frappe ; elle part DELAI_IMPACT
-- secondes après le lancement.
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_releve_cast")
util.AddNetworkString("taijutsu_hitb_fx")   -- particule d'impact (cl_taijutsu_hitfx.lua)

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 25     -- 1er coup : dégâts seulement
local DEGATS_ENVOL = 25     -- 2e coup : dégâts + la cible monte en l'air
local PORTEE       = 140    -- distance max de la frappe
local ANGLE        = 60     -- demi-angle du cône devant le lanceur (degrés)
local LANCER       = 220   -- vitesse verticale donnée à la cible
local RECUL        = 130   -- petite poussée horizontale, dans le sens du coup (0 = monte tout droit)

local RECHARGE     = 14
local CHAKRA_COUT  = 20
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DELAI_IMPACT = 0.3     -- lancement de l'anim -> 1er coup
local DELAI_ENVOL  = 0.7     -- lancement de l'anim -> 2e coup (à régler selon l'animation)
local ANIM_APPEL   = "m_attack_hand_lowkicktokickup"
local ANIM_CIBLE   = "M_Beaten_SpinBlowOff"   -- animation de la cible projetée
local DUREE_ANIM_MAX = 3                      -- sécurité : on rend la main à la cible après ce délai

local SON_IMPACT   = "dimix/sond/taijutsu/hit6.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "taijutsu_releve", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Un NextBot reste collé au sol quand on lui donne de la vitesse vers le haut :
-- on le soulève image par image jusqu'à la hauteur qu'atteindrait un joueur.
local function Soulever(cible, vitesse)
    local g = GetConVar("sv_gravity"):GetFloat()
    local duree = vitesse / g                       -- temps jusqu'au sommet
    local haut = 0.5 * vitesse * duree
    local depart = cible:GetPos()
    local t0 = CurTime()
    local id = "TaijutsuReleve_Haut_" .. cible:EntIndex()
    timer.Create(id, 0, 0, function()
        if not IsValid(cible) then timer.Remove(id) return end
        local k = math.min((CurTime() - t0) / duree, 1)
        cible:SetPos(depart + Vector(0, 0, haut * (1 - (1 - k) * (1 - k))))
        if k >= 1 then timer.Remove(id) end
    end)
end

-- La cible joue ANIM_CIBLE (une fois) pendant qu'elle monte, via les NW2 lus par
-- cl_etourdi_anim.lua / na_faux_joueur.lua. Pas de NA_Etourdir : il l'immobiliserait
-- et annulerait l'élan. On rend la main dès qu'elle retouche le sol.
local function AnimCible(cible)
    cible:SetNW2String("NA_EtourdiAnim", ANIM_CIBLE)
    cible:SetNW2Bool("NA_EtourdiUneFois", true)
    cible:SetNW2Int("NA_EtourdiAnimId", cible:GetNW2Int("NA_EtourdiAnimId", 0) + 1)
    cible:SetNW2Bool("NA_Etourdi", true)

    local t0 = CurTime()
    local id = "TaijutsuReleve_Anim_" .. cible:EntIndex()
    timer.Create(id, 0.1, 0, function()
        local fini = not IsValid(cible) or (cible:IsPlayer() and not cible:Alive())
            or CurTime() - t0 > DUREE_ANIM_MAX
            or (CurTime() - t0 > 0.4 and cible:IsOnGround())
        if not fini then return end
        timer.Remove(id)
        if not IsValid(cible) then return end
        if NA_EstEtourdi and NA_EstEtourdi(cible) then return end   -- un vrai stun a pris le relais
        if NA_Liberer then NA_Liberer(cible) end   -- efface l'anim ; garde le stun si le cube Jinton tient encore la cible
    end)
end

-- Un coup de l'animation : envol = false -> dégâts seulement ; envol = true -> dégâts + la cible monte en l'air
local function Frapper(ply, envol)
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = Niv(ply, "portee", PORTEE)
    local origine = ply:GetPos()
    local avant = ply:GetForward()
    avant.z = 0
    avant:Normalize()
    local seuil = math.cos(math.rad(ANGLE))
    local lancer = Niv(ply, "lancer", LANCER)
    local recul = Niv(ply, "recul", RECUL)

    for _, ent in ipairs(ents.FindInSphere(ply:WorldSpaceCenter(), portee)) do
        if not EstCible(ent, ply) then continue end

        local dir = ent:GetPos() - origine
        dir.z = 0
        if dir:LengthSqr() > 1 and dir:GetNormalized():Dot(avant) < seuil then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(envol and Niv(ply, "degats_envol", DEGATS_ENVOL) or Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        -- les dégâts ne poussent pas : sans force explicite le moteur en déduit une depuis la position du lanceur
        -- (c'était ce qui envoyait la cible très loin) ; seul le lancer vertical ci-dessous la déplace
        dmg:SetDamageType(bit.bor(DMG_CLUB, DMG_PREVENT_PHYSICS_FORCE))
        dmg:SetDamageForce(vector_origin)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110))
        net.Start("taijutsu_hitb_fx")
            net.WriteVector(ent:WorldSpaceCenter())
        net.Broadcast()

        if envol then
            if NA_Projeter then NA_Projeter(ent) end   -- sous stun souple : emportée ; stun ferme : ne bouge pas (sv_etourdissement.lua)
            AnimCible(ent)
            if ent.loco then
                Soulever(ent, lancer)   -- NextBot
            else
                -- SetVelocity AJOUTE à la vitesse actuelle : on retire d'abord celle de la cible (course, élan du
                -- coup précédent), donc on FIXE exactement la vitesse voulue (monte + petite poussée, recul). Détachée du
                -- sol, sinon le sol mange la poussée. Refait au tick suivant : le moteur / un autre script ne l'écrase pas.
                local voulue = Vector(0, 0, lancer) + avant * recul
                local function Envoyer()
                    if not IsValid(ent) or (ent:IsPlayer() and not ent:Alive()) then return end
                    ent:SetGroundEntity(NULL)
                    ent:SetVelocity(ent:IsPlayer() and (voulue - ent:GetVelocity()) or voulue)   -- joueur : AJOUTE ; PNJ : remplace
                end
                Envoyer()
                timer.Simple(0, Envoyer)
            end
        end
    end
end

net.Receive("taijutsu_releve_cast", function(_, ply)
    if not NA_Debloquee(ply, "taijutsu_releve") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "taijutsu_releve", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant sa durée (_na_mudra.lua)

    -- coup 1 : dégâts seulement ; coup 2 : dégâts + envol
    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function() Frapper(ply, false) end)
    timer.Simple(Niv(ply, "delai_envol", DELAI_ENVOL), function()
        enCours[ply] = nil
        Frapper(ply, true)
    end)
end)

hook.Add("PlayerDeath", "TaijutsuReleve_Mort", function(ply) enCours[ply] = nil end)
hook.Add("PlayerDisconnected", "TaijutsuReleve_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
