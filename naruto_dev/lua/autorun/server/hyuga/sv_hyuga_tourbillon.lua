--========================================================
-- Hyuga : Tourbillon Divin (SERVEUR)
--
-- Rotation défensive : le lanceur tourne sur lui-même (animation en boucle)
-- pendant DUREE secondes, avec des impulsions de dégâts + projection vers
-- l'extérieur toutes les INTERVALLE secondes, dans un rayon autour de lui.
-- La particule [0]_Tourbillon_Divin (solve_hyuga_dome.pcf) tourne avec lui
-- pendant toute la durée, puis l'animation de fin se joue.
--========================================================

if not SERVER then return end

util.AddNetworkString("hyuga_tourbillon_cast")
util.AddNetworkString("hyuga_tourbillon_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 15     -- dégâts à chaque impulsion
local INTERVALLE   = 0.5    -- secondes entre deux impulsions
local DUREE        = 2.5    -- durée totale de la rotation (secondes)
local RAYON        = 200    -- rayon des impulsions autour du lanceur
local RECUL        = 900    -- projection vers l'extérieur
local SOULEVE      = 200    -- projection vers le haut

local VITESSE_MARCHE = 320   -- vitesse de déplacement pendant la rotation (normale hors technique : 200)
local VITESSE_COURSE = 450   -- vitesse en courant pendant la rotation (normale hors technique : 340)

local RECHARGE     = 16     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local ANIM_LOOP    = "m_ni_def_ninjutsu_palmrotation_loop"
local ANIM_FIN     = "m_ni_def_ninjutsu_palmrotation_end"

local SON_TOURNE   = "naruto_sound/jutsu/hyuga/hyuga3.wav"
local SON_IMPACT   = "naruto_sound/jutsu/hyuga/hyuga1.wav"
--========================================================

resource.AddFile("particles/solve_hyuga_dome.pcf")
resource.AddFile("particles/patlick_atgparticules.pcf")

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "hyuga_tourbillon", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Une impulsion : dégâts + projection vers l'extérieur, centrée sur le lanceur
local function Impulsion(ply, rayon, degats, recul, souleve)
    if not IsValid(ply) or not ply:Alive() then return end
    local centre = ply:GetPos() + Vector(0, 0, 10)

    for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        local sortie = ent:GetPos() - centre
        sortie.z = 0
        if sortie:LengthSqr() < 1 then sortie = VectorRand() sortie.z = 0 end
        local vel = sortie:GetNormalized() * recul + Vector(0, 0, souleve)
        if ent.loco then
            ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
        else
            ent:SetVelocity(vel)
        end

        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110), 0.6)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(centre, rayon, INTERVALLE, Color(170, 200, 255, 20), true)
    end
end

net.Receive("hyuga_tourbillon_cast", function(_, ply)
    NA_SonJutsu(ply)
    if not NA_Debloquee(ply, "hyuga_tourbillon") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = Niv(ply, "chakra", CHAKRA_COUT)
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
    if NA_CD then NA_CD.Set(ply, "hyuga_tourbillon", recharge) end   -- recharge visible dans la barre

    local duree = Niv(ply, "duree", DUREE)
    local intervalle = Niv(ply, "intervalle", INTERVALLE)
    local rayon = Niv(ply, "rayon", RAYON)
    local degats = Niv(ply, "degats", DEGATS)
    local recul = Niv(ply, "recul", RECUL)
    local souleve = Niv(ply, "souleve", SOULEVE)

    -- Séquence PRINCIPALE forcée côté client (cl_hyuga_tourbillon.lua, comme
    -- cl_etourdi_anim.lua) : elle ne redémarre qu'au changement de séquence,
    -- donc la boucle du modèle tourne en continu sans redémarrer sans arrêt.
    ply:SetNW2Float("NA_TourbillonFin", CurTime() + duree)
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu tant que ça dure (_na_registre.lua)
    if NA_Mudra then NA_Mudra(ply, duree) end   -- pas de coups pendant toute la rotation
    ply:EmitSound(SON_TOURNE, 70, 100)

    -- pas de course de chakra ni de double saut pendant la rotation
    -- (NA_Canalise, vérifié dans sv_sprint_chakra.lua et sh_double_saut.lua),
    -- mais vitesse de déplacement de base augmentée en compensation.
    if NA_StopChakraRun then NA_StopChakraRun(ply) end
    local vitesseAvant = { marche = ply:GetWalkSpeed(), course = ply:GetRunSpeed() }
    ply:SetWalkSpeed(VITESSE_MARCHE)
    ply:SetRunSpeed(VITESSE_COURSE)

    net.Start("hyuga_tourbillon_fx")
        net.WriteEntity(ply)
        net.WriteFloat(duree)
    net.Broadcast()

    -- première impulsion tout de suite (sinon la première poussée arrive
    -- après un délai d'intervalle, ça ne "expulse" pas dès le lancement)
    Impulsion(ply, rayon, degats, recul, souleve)

    local id = "HyugaTourbillon_" .. ply:EntIndex()
    local nb = math.max(1, math.floor(duree / intervalle))
    timer.Create(id, intervalle, nb, function()
        Impulsion(ply, rayon, degats, recul, souleve)
    end)

    timer.Simple(duree, function()
        enCours[ply] = nil
        timer.Remove(id)
        if IsValid(ply) then
            ply:SetNW2Bool("NA_Canalise", false)
            ply:SetWalkSpeed(vitesseAvant.marche)
            ply:SetRunSpeed(vitesseAvant.course)
            ply:StopSound(SON_TOURNE)

            -- animation de fin (jouée une fois, sans boucler) : le client
            -- (cl_hyuga_tourbillon.lua) la joue tant que NA_TourbillonFinAnim
            -- est dans le futur, pour sa propre durée naturelle.
            local seqFin = ply:LookupSequence(ANIM_FIN)
            local dureeFin = (seqFin and seqFin >= 0) and ply:SequenceDuration(seqFin) or 0.5
            ply:SetNW2Float("NA_TourbillonFinAnim", CurTime() + dureeFin)
        end
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "HyugaTourbillon_Mort", function(ply)
    enCours[ply] = nil
    timer.Remove("HyugaTourbillon_" .. ply:EntIndex())
    ply:SetNW2Bool("NA_Canalise", false)
    ply:StopSound(SON_TOURNE)
end)

hook.Add("PlayerDisconnected", "HyugaTourbillon_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
    timer.Remove("HyugaTourbillon_" .. ply:EntIndex())
end)
