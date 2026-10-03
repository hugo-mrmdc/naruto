--========================================================
-- Hyuga : 64 Points du Hakke (SERVEUR)
--
-- Copie de la 32 Points (sv_hyuga_32points.lua) : même zone rectangulaire
-- devant le lanceur, même rafale d'étourdissement. Seuls changements :
-- l'animation (attack_hyuga_64poings, sans le "_slow") et la particule, au
-- sol sous la cible au lieu de sur son buste (cl_hyuga_64points.lua).
--========================================================

if not SERVER then return end

util.AddNetworkString("hyuga_64points_cast")
util.AddNetworkString("hyuga_64points_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS_TICK  = 8      -- dégâts à chaque tick de la rafale
local INTERVALLE   = 0.2    -- secondes entre deux ticks
local ETOURDI      = 4      -- secondes d'étourdissement de la cible (= durée totale de la rafale)
local PORTEE       = 300    -- longueur du rectangle devant le lanceur
local RAYON        = 50     -- demi-largeur ET demi-hauteur du rectangle (developer 1 pour le voir)

local RECHARGE     = 26     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 45     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local ANIM_APPEL   = "attack_hyuga_64poings"
local ANIM_DUREE_DEFAUT = 0.8   -- si la séquence est introuvable sur le modèle (comme _na_mudra.lua)
local ANIM_DUREE_MAX    = 6     -- durée maximum de l'invulnérabilité/figement (couvre le pire cas d'étourdi, cf. Niv plus bas)

local SON_IMPACT   = "physics/body/body_medium_impact_hard3.wav"
--========================================================

resource.AddFile("particles/patlick_atgparticules.pcf")
resource.AddFile("particles/ctg_hyuga_nael.pcf")

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "hyuga_64points", stat, base) end

local enCours = {}
local pret    = {}
local figesLanceur   = {}   -- lanceur -> position à maintenir (Think, plus bas)
local protegeChute   = {}   -- lanceur -> true tant qu'on ignore les dégâts de chute (jusqu'à l'atterrissage)

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Même zone que la Paume du Hakke (server/hyuga/sv_hyuga_paume.lua) : un
-- rectangle devant le regard complet du lanceur (pitch inclus).
local function CiblesDevant(ply, portee, rayon)
    local origine = ply:GetShootPos()
    local ang = ply:EyeAngles()
    local avant, droite, haut = ang:Forward(), ang:Right(), ang:Up()
    local trouvees = {}

    for _, ent in ipairs(ents.FindInSphere(origine, portee + rayon)) do
        if not EstCible(ent, ply) then continue end

        local delta = ent:WorldSpaceCenter() - origine
        local x, y, z = delta:Dot(avant), delta:Dot(droite), delta:Dot(haut)
        if x >= 0 and x <= portee and math.abs(y) <= rayon and math.abs(z) <= rayon then
            trouvees[#trouvees + 1] = ent
        end
    end
    return trouvees
end

-- invulnérabilité du lanceur pendant la technique (comme sv_mokuton_protection.lua)
hook.Add("EntityTakeDamage", "HyugaHakke64_Invuln", function(cible)
    if IsValid(cible) and cible:IsPlayer() and cible:GetNW2Bool("NA_Hakke64Invuln", false) then
        return true
    end
end)

-- pas de dégâts de chute pendant la technique NI à la retombée juste après
-- (s'il était en l'air au lancer, il retombe d'un coup à la libération :
-- la protection dure jusqu'à ce qu'il touche vraiment le sol, cf. Think plus bas)
hook.Add("GetFallDamage", "HyugaHakke64_PasDeChute", function(ply)
    if protegeChute[ply] then return 0 end
end)

-- Un tick de la rafale : dégâts, tant que la cible est valide (arrêt sinon).
-- Ne retombe pas si elle est en l'air : sécurité en plus de NA_Etourdir
-- (Freeze pour les joueurs, position maintenue pour PNJ/nextbot).
local function InfligerTick(ply, ent, degats)
    if not IsValid(ply) or not IsValid(ent) or not EstCible(ent, ply) then return false end

    local dmg = DamageInfo()
    dmg:SetDamage(degats)
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_CLUB)
    dmg:SetDamagePosition(ent:WorldSpaceCenter())
    ent:TakeDamageInfo(dmg)
    ent:EmitSound(SON_IMPACT, 75, math.random(95, 110), 0.6)

    if ent:IsPlayer() then
        ent:SetVelocity(-ent:GetVelocity())
    elseif ent.NA_Hakke64Pos then
        ent:SetPos(ent.NA_Hakke64Pos)
        ent:SetVelocity(vector_origin)
    end

    return true
end

-- Étourdit la cible (etourdi, peut durer plus longtemps que l'animation) et
-- lui inflige un tick de dégâts toutes les "intervalle" secondes, mais
-- seulement pendant "dureeRafale" (= durée réelle de l'animation) : les
-- dégâts ne doivent pas continuer une fois l'animation terminée à l'écran.
local function Rafale(ply, ent, degats, intervalle, etourdi, dureeRafale)
    if NA_Etourdir then NA_Etourdir(ent, etourdi) end
    if not ent:IsPlayer() then ent.NA_Hakke64Pos = ent:GetPos() end   -- position à maintenir si en l'air

    net.Start("hyuga_64points_fx")
        net.WriteEntity(ply)
        net.WriteEntity(ent)
        net.WriteFloat(etourdi)   -- pour que les particules disparaissent pile à la fin du stun (cl_hyuga_64points.lua)
    net.Broadcast()

    local id = "HyugaHakke64_Rafale_" .. ent:EntIndex() .. "_" .. tostring(CurTime())
    local nb = math.max(1, math.floor(dureeRafale / intervalle))
    timer.Create(id, intervalle, nb, function()
        if not InfligerTick(ply, ent, degats) then
            timer.Remove(id)
            if IsValid(ent) then ent.NA_Hakke64Pos = nil end
        end
    end)
end

net.Receive("hyuga_64points_cast", function(_, ply)
    if not NA_Debloquee(ply, "hyuga_64points") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local portee, rayon = Niv(ply, "portee", PORTEE), Niv(ply, "rayon", RAYON)
    local cibles = CiblesDevant(ply, portee, rayon)

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "hyuga_64points", recharge) end   -- recharge visible dans la barre

    -- personne dans la zone : coût + recharge seulement, sans animation
    if #cibles == 0 then return end
    enCours[ply] = true

    local degats, intervalle, etourdi = Niv(ply, "degats", DEGATS_TICK), Niv(ply, "intervalle", INTERVALLE), Niv(ply, "etourdi", ETOURDI)

    -- le figement du lanceur et la rafale (dégâts + particules) durent aussi
    -- longtemps que l'étourdissement de la cible (etourdi), pas juste le clip
    -- d'origine qui peut être plus court — sinon tout s'arrête avant la fin
    -- du stun. L'anim boucle à vitesse normale tant que NA_Hakke64PoingsFin
    -- est dans le futur (séquence forcée côté client, cl_hyuga_64points.lua,
    -- comme cl_etourdi_anim.lua / cl_hyuga_tourbillon.lua).
    local seqId = ply:LookupSequence(ANIM_APPEL)
    local natDuree = (seqId and seqId >= 0) and ply:SequenceDuration(seqId) or ANIM_DUREE_DEFAUT
    local duree = math.Clamp(math.max(natDuree, etourdi), 0, ANIM_DUREE_MAX)

    -- PAS NA_AnimJutsu ici : elle joue l'anim sur un gesture slot séparé
    -- (AddVCDSequenceToGestureSlot, jutsu_anim_cl.lua) qui se coupe tout seul
    -- après une lecture et vient percuter/masquer la boucle qu'on force sur
    -- la séquence de BASE juste en dessous (cl_hyuga_64points.lua) : d'où le
    -- "ça joue une fois et plus jamais". On bloque juste les coups (NA_Mudra),
    -- comme le Tourbillon Divin (sv_hyuga_tourbillon.lua), et l'anim vient
    -- entièrement de la boucle forcée côté client.
    if NA_Mudra then NA_Mudra(ply, duree) end
    ply:SetNW2Float("NA_Hakke64PoingsFin", CurTime() + duree)
    ply:SetNW2Float("NA_Hakke64PoingsDebut", CurTime())   -- référence de temps pour piloter le cycle de l'anim (cl_hyuga_64points.lua)

    ply:SetNW2Bool("NA_Hakke64Invuln", true)
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu tant que ça dure (_na_registre.lua)
    ply:Freeze(true)   -- immobilisé pendant toute la technique (au sol comme en l'air, ne retombe pas)
    ply:SetGravity(0)  -- coupe aussi la gravité (en plus du repositionnement) : plus aucun affaissement
    ply:SetMoveType(MOVETYPE_NONE)   -- plus aucun déplacement physique, même en l'air (la gravité ne s'applique plus du tout)

    -- la rafale part TOUT DE SUITE (en même temps que l'animation), pas après :
    -- sinon les dégâts n'arrivent qu'une fois les coups déjà terminés à l'écran.
    for _, ent in ipairs(cibles) do
        Rafale(ply, ent, degats, intervalle, etourdi, duree)
    end
    if GetConVar("developer"):GetInt() > 0 then
        local mins = Vector(0, -rayon, -rayon)
        local maxs = Vector(portee, rayon, rayon)
        debugoverlay.BoxAngles(ply:GetShootPos(), mins, maxs, ply:EyeAngles(), 1, Color(255, 140, 60, 20))
    end

    -- le lanceur aussi reste bien à la même place (sécurité en plus de Freeze,
    -- comme pour la cible touchée) : remis à sa position de départ À CHAQUE
    -- FRAME serveur (pas juste toutes les intervalle secondes, sinon il
    -- retombe un peu puis se fait "téléporter" en arrière : effet saccadé).
    figesLanceur[ply] = ply:GetPos()
    protegeChute[ply] = true

    timer.Simple(duree, function()
        enCours[ply] = nil
        figesLanceur[ply] = nil
        if IsValid(ply) then
            ply:SetNW2Bool("NA_Hakke64Invuln", false)
            ply:SetNW2Bool("NA_Canalise", false)
            ply:Freeze(false)
            ply:SetGravity(1)
            ply:SetMoveType(MOVETYPE_WALK)
        end
    end)
end)

hook.Add("Think", "HyugaHakke64_MaintienLanceur", function()
    for ply, pos in pairs(figesLanceur) do
        if not IsValid(ply) then
            figesLanceur[ply] = nil
        else
            ply:SetPos(pos)
            ply:SetVelocity(vector_origin)
        end
    end

    -- protection anti-chute : levée seulement une fois la technique finie
    -- (figesLanceur déjà vidé) ET les pieds vraiment posés au sol
    for ply in pairs(protegeChute) do
        if not IsValid(ply) then
            protegeChute[ply] = nil
        elseif not figesLanceur[ply] and ply:IsOnGround() then
            protegeChute[ply] = nil
        end
    end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "HyugaHakke64_Mort", function(ply)
    enCours[ply] = nil
    figesLanceur[ply] = nil
    protegeChute[ply] = nil
    ply:SetNW2Bool("NA_Hakke64Invuln", false)
    ply:SetNW2Bool("NA_Canalise", false)
    ply:Freeze(false)
    ply:SetGravity(1)
    ply:SetMoveType(MOVETYPE_WALK)
end)

hook.Add("PlayerDisconnected", "HyugaHakke64_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
    figesLanceur[ply] = nil
    protegeChute[ply] = nil
end)
