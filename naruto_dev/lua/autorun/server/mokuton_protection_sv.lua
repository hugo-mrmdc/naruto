--========================================================
-- Mokuton : Protection de bois (SERVEUR)
--
-- Un cocon de bois (entité mokuton_hobi, lua/entities) se referme autour du lanceur
-- (nr_mokuton_Hobi_close), reste fermé (nr_mokuton_Hobi_close_idle) pendant DUREE secondes puis
-- s'ouvre (nr_mokuton_Hobi_open). Pendant ce temps le lanceur est invincible et se soigne à chaque
-- tick, mais ne peut lancer AUCUN jutsu (refusé par _na_registre.lua, NW2Bool "NA_Hobi").
-- Le serveur décide de tout : recharge, chakra, soin.
--========================================================

if not SERVER then return end

util.AddNetworkString("mokuton_protection_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 6      -- secondes de cocon FERMÉ (sans compter la fermeture et l'ouverture)
local SOIN         = 4      -- points de vie rendus à chaque tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks de soin
local RECHARGE     = 15     -- secondes après la FIN de la technique avant de pouvoir relancer
local CHAKRA_COUT  = 25     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local ECHELLE      = 1      -- taille du cocon (1 = taille d'origine du modèle)
local DECALAGE     = Vector(0, 0, 0)   -- position du cocon par rapport aux pieds du joueur
local ANGLE_YAW    = 0      -- rotation du cocon par rapport au regard du joueur (degrés)
local DUREE_MUDRA  = 0.6    -- incantation avant que le cocon se referme
local ANIM_MUDRA   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_FERME   = "nr_mokuton_Hobi_close"
local ANIM_IDLE    = "nr_mokuton_Hobi_close_idle"
local ANIM_OUVRE   = "nr_mokuton_Hobi_open"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "mokuton_protection", stat, base) end

local pret = {}   -- joueur -> moment où la technique est de nouveau disponible
local cocons = {} -- joueur -> entité
local posFigee = {} -- joueur -> position où il est bloqué
local enMudra = {}  -- joueur -> true pendant les mudras

local function Timer(ply, suffixe) return "mokuton_protection_" .. suffixe .. "_" .. ply:EntIndex() end
local SUFFIXES = { "mudra", "idle", "ouvre", "fin", "soin" }

-- Tout arrêter : cocon retiré, joueur de nouveau visible
local function Arreter(ply)
    for _, s in ipairs(SUFFIXES) do timer.Remove(Timer(ply, s)) end
    if IsValid(cocons[ply]) then cocons[ply]:Remove() end
    cocons[ply] = nil
    enMudra[ply] = nil
    ply:SetNW2Bool("NA_Hobi", false)
    if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end   -- de nouveau libre de bouger
    posFigee[ply] = nil
end

-- Le cocon se referme autour du joueur (après les mudras)
local function Lancer(ply)
    local cocon = ents.Create("mokuton_hobi")
    if not IsValid(cocon) then return end
    cocon.Echelle  = Niv(ply, "echelle", ECHELLE)
    cocon:SetPos(ply:GetPos() + DECALAGE)
    cocon:SetAngles(Angle(0, ply:EyeAngles().y + ANGLE_YAW, 0))
    cocon:Spawn()
    cocons[ply] = cocon
    ply:SetNW2Bool("NA_Hobi", true)
    posFigee[ply] = ply:GetPos()
    ply:SetMoveType(MOVETYPE_NONE)   -- immobile ; la caméra reste libre

    -- 1) fermeture
    local ferme = cocon:Jouer(ANIM_FERME)

    -- 2) cocon fermé pendant DUREE secondes, avec un soin à chaque tick
    local duree = Niv(ply, "duree", DUREE)
    timer.Create(Timer(ply, "idle"), ferme, 1, function()
        if IsValid(cocon) then cocon:Jouer(ANIM_IDLE) end
    end)
    timer.Create(Timer(ply, "soin"), Niv(ply, "intervalle", INTERVALLE), 0, function()
        if not IsValid(ply) then return end
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + Niv(ply, "soin", SOIN)))
    end)

    -- 3) ouverture : plus de soin
    local ouvre = 0
    timer.Create(Timer(ply, "ouvre"), ferme + duree, 1, function()
        timer.Remove(Timer(ply, "soin"))
        if not IsValid(ply) then return end
        if IsValid(cocon) then ouvre = cocon:Jouer(ANIM_OUVRE) end

        -- 4) fin : cocon retiré, jutsus de nouveau possibles, la recharge démarre
        timer.Create(Timer(ply, "fin"), ouvre + 0.2, 1, function()   -- +0.2 : on voit la dernière image avant que le cocon disparaisse
            if not IsValid(ply) then return end
            Arreter(ply)
            local recharge = Niv(ply, "recharge", RECHARGE)
            pret[ply] = CurTime() + recharge
            if NA_CD then NA_CD.Set(ply, "mokuton_protection", recharge) end   -- recharge visible dans la barre
        end)
    end)
end

net.Receive("mokuton_protection_cast", function(_, ply)
    if not NA_Debloquee(ply, "mokuton_protection") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if enMudra[ply] or ply:GetNW2Bool("NA_Hobi", false) or ply:GetNW2Bool("NA_Souterrain", false) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    if NA_StopChakraRun then NA_StopChakraRun(ply) end   -- lancer une technique coupe la course de chakra

    -- mudras, puis le cocon se referme
    enMudra[ply] = true
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_MUDRA)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Create(Timer(ply, "mudra"), mudra, 1, function()
        enMudra[ply] = nil
        if IsValid(ply) and ply:Alive() then Lancer(ply) end
    end)
end)

-- mort ou réapparition : plus de cocon
hook.Add("PlayerDeath", "MokutonProtection_Mort", Arreter)
hook.Add("PlayerSpawn", "MokutonProtection_Spawn", Arreter)
hook.Add("PlayerDisconnected", "MokutonProtection_Nettoyage", function(ply)
    Arreter(ply)
    pret[ply] = nil
    cocons[ply] = nil
end)

-- Filet de sécurité : si quelque chose (dash, poussée...) le déplace quand même, il est remis en place
hook.Add("Think", "MokutonProtection_Immobile", function()
    for ply, pos in pairs(posFigee) do
        if not IsValid(ply) then
            posFigee[ply] = nil
        elseif ply:GetPos():DistToSqr(pos) > 4 then
            ply:SetPos(pos)
            ply:SetLocalVelocity(vector_origin)
        end
    end
end)

-- dans le cocon : aucun dégât, de toute la technique (fermeture et ouverture comprises)
hook.Add("EntityTakeDamage", "MokutonProtection_Invincible", function(cible)
    if cible:IsPlayer() and cible:GetNW2Bool("NA_Hobi", false) then return true end
end)
