--========================================================
-- Suiton : Prison aqueuse (SERVEUR)
--
-- Vise un ennemi à portée : une prison d'eau l'enferme et il est étourdi
-- (immobilisé, NA_Etourdir : sv_etourdissement.lua) pendant quelques secondes.
-- La prison (atg_prison_aqueuse) est affichée par cl_suiton_prison.lua.
-- Le serveur décide de tout : incantation, recharge, chakra, cible.
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_prison_cast")   -- client -> serveur : lancer
util.AddNetworkString("suiton_prison_fx")     -- serveur -> clients : prison sur une cible

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 800    -- distance maximale de la cible
local TAILLE_VISEE  = 20     -- demi-taille de la hitbox de visée (boîte lancée le long du regard)
local DUREE         = 3      -- durée de la prison et de l'étourdissement (secondes)
local HAUTEUR       = 100    -- hauteur à laquelle la cible est soulevée (unités ; 0 = reste au sol)
local DEGATS        = 4      -- dégâts par tick de la prison (seuls dégâts que la cible subit pendant la prison)
local INTERVALLE    = 0.5    -- secondes entre deux ticks
local RECHARGE      = 12     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.6    -- incantation avant l'apparition de la prison
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_CIBLE    = "nrp_beaten_bellydown_middle_loop"   -- animation de la cible pendant la prison
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "suiton_prison", stat, base) end

resource.AddFile("particles/atg_particules_prison_aqueuse.pcf")

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Ennemi visé : une boîte est lancée depuis les yeux le long du regard, jusqu'au
-- premier mur (ou PORTEE) ; on prend la cible valable la plus proche qu'elle traverse.
local function TrouverCible(ply, portee)
    local oeil = ply:EyePos()
    local t = NA_Stat(ply, "suiton_prison", "hitbox", TAILLE_VISEE)
    local mins, maxs = Vector(-t, -t, -t), Vector(t, t, t)

    local mur = util.TraceHull({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mins = mins, maxs = maxs, mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(ents.FindAlongRay(oeil, mur.HitPos, mins, maxs)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end
    return cible
end

-- Pendant la prison, la cible ne subit AUCUN autre dégât que les ticks de la prison
-- (armes, techniques, brûlure, chute...) : ils sont annulés ici.
local tickPrison = false   -- vrai uniquement pendant un tick de la prison
hook.Add("EntityTakeDamage", "SuitonPrison_Protege", function(cible, dmg)
    if (cible.NA_PrisonFin or 0) > CurTime() and not tickPrison then return true end
end)
hook.Add("PlayerSpawn", "SuitonPrison_Fin", function(ply) ply.NA_PrisonFin = nil end)

-- Un tick de dégâts toutes les INTERVALLE secondes tant que dure la prison
local function Blesser(cible, lanceur, degats, intervalle, duree)
    cible.NA_PrisonFin = math.max(cible.NA_PrisonFin or 0, CurTime() + duree)

    local id = "suiton_prison_tick_" .. cible:EntIndex()
    timer.Create(id, intervalle, math.max(1, math.floor(duree / intervalle)), function()
        if not IsValid(cible) or cible:Health() <= 0 or (cible:IsPlayer() and not cible:Alive()) then
            timer.Remove(id)
            if IsValid(cible) then cible.NA_PrisonFin = nil end
            return
        end
        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(IsValid(lanceur) and lanceur or game.GetWorld())
        dmg:SetInflictor(IsValid(lanceur) and lanceur or game.GetWorld())
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetDamagePosition(cible:WorldSpaceCenter())
        tickPrison = true
        cible:TakeDamageInfo(dmg)
        tickPrison = false
    end)
end

-- La cible monte en douceur (0,4 s) jusqu'à "hauteur" unités, ou jusqu'au plafond s'il y en a un.
-- L'étourdissement la garde en l'air (joueur : vitesse annulée à chaque tick ; PNJ : position maintenue).
local PAS_LEVEE = 8
local function Lever(cible, hauteur, duree)
    if hauteur <= 0 then return end

    -- PNJ / NextBot : leur IA les repose au sol ~10 fois par seconde, et le serveur les remonte
    -- à chaque tick : ils clignotaient entre le sol et la position soulevée. On fige donc leur IA
    -- (COND_NPC_FREEZE, comme le statut d'étourdissement du gamemode) et leur physique le temps de la prison.
    if not cible:IsPlayer() then
        local mouvement = cible:GetMoveType()
        local gravite = cible.loco and cible.loco:GetGravity()
        cible:SetMoveType(MOVETYPE_NONE)
        if cible.loco then cible.loco:SetGravity(0) end
        if cible:IsNPC() then
            cible:SetCondition((COND and COND.NPC_FREEZE) or 67)
        else
            cible:AddEFlags(EFL_NO_THINK_FUNCTION)   -- NextBot : plus de réflexion, donc plus de déplacement
        end

        timer.Simple(duree + 0.1, function()
            if not IsValid(cible) then return end
            cible:SetMoveType(mouvement)
            if cible.loco and gravite then cible.loco:SetGravity(gravite) end
            if cible:IsNPC() then
                cible:SetCondition((COND and COND.NPC_UNFREEZE) or 68)
            else
                cible:RemoveEFlags(EFL_NO_THINK_FUNCTION)
            end
        end)
    end

    local depart = cible:GetPos()
    local tr = util.TraceHull({
        start = depart, endpos = depart + Vector(0, 0, hauteur),
        mins = cible:OBBMins(), maxs = cible:OBBMaxs(),
        filter = cible, mask = MASK_PLAYERSOLID,
    })
    local pas = hauteur * tr.Fraction / PAS_LEVEE

    timer.Create("suiton_prison_levee_" .. cible:EntIndex(), 0.05, PAS_LEVEE, function()
        if not IsValid(cible) or not NA_EstEtourdi(cible) then return end
        local pos = cible:GetPos() + Vector(0, 0, pas)
        cible:SetPos(pos)
        if not cible:IsPlayer() then cible.NA_EtourdiPos = pos end   -- les PNJ sont maintenus à cette position
    end)
end

net.Receive("suiton_prison_cast", function(_, ply)
    if not NA_Debloquee(ply, "suiton_prison") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if enCours[ply] or (pret[ply] or 0) > CurTime() then return end

    local portee = Niv(ply, "portee", PORTEE)
    local cible = TrouverCible(ply, portee)
    if not cible then return end   -- pas de cible visée : rien (ni chakra ni recharge)

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "suiton_prison", recharge) end -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        -- la cible a pu mourir ou s'éloigner pendant l'incantation
        if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > portee * 1.2 then return end

        local duree = Niv(ply, "duree", DUREE)
        if NA_Etourdir then NA_Etourdir(cible, duree) end
        Lever(cible, Niv(ply, "hauteur", HAUTEUR), duree)
        Blesser(cible, ply, Niv(ply, "degats", DEGATS), Niv(ply, "intervalle", INTERVALLE), duree)

        -- animation de la cible pendant la prison (joueurs seulement : lue par cl_etourdi_anim.lua).
        -- Les PNJ gardent leur pose : changer leur séquence côté serveur provoquait
        -- "Bad pstudiohdr in GetSequenceLinearMotion()" sur les modèles sans cette séquence.
        if cible:IsPlayer() then
            cible:SetNW2String("NA_EtourdiAnim", ANIM_CIBLE)
            timer.Simple(duree + 0.1, function()
                if IsValid(cible) and cible:GetNW2String("NA_EtourdiAnim", "") == ANIM_CIBLE then
                    cible:SetNW2String("NA_EtourdiAnim", "")
                end
            end)
        end
        cible:EmitSound("ambient/water/water_splash" .. math.random(1, 3) .. ".wav", 80, 90)

        net.Start("suiton_prison_fx")
            net.WriteEntity(cible)
            net.WriteFloat(duree)
        net.Broadcast()
    end)
end)

hook.Add("PlayerDisconnected", "SuitonPrison_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
