--========================================================
-- Doton : Voyage souterrain (SERVEUR)
--
-- Le lanceur passe sous terre pendant DUREE secondes : invisible (NA_Invisible, sv_fumainv.lua), plus aucun dégât, mais pas de saut ni de
-- course de chakra (le saut est retiré dans doton_init.lua, la course dans sv_sprint_chakra.lua).
-- Particule atg_voyage_souterrain agrandie (particles/doton_taupe.pcf, copie de atg_particules3.pcf) posée sur le joueur ;
-- à la sortie, atg_jutsu_petrifiant. E fait sortir tout de suite ; aucun jutsu possible sous terre (_na_registre.lua).
-- Particule sous terre affichée par cl_doton_taupe.lua (message "doton_taupe_fx").
--========================================================

if not SERVER then return end

util.AddNetworkString("doton_taupe_cast")
util.AddNetworkString("doton_taupe_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 6      -- secondes sous terre
local RECHARGE     = 15     -- secondes avant de pouvoir relancer (depuis la SORTIE)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local FX_SORTIE    = "atg_jutsu_petrifiant"   -- particles/atg_particules3.pcf
local ANIM_ENTREE  = "nrp_ninjutsu_defend_subterraneanvoyage"          -- joué en s'enfonçant
local ANIM_SORTIE  = "nrp_ninjutsu_defend_subterraneanvoyage_appear"   -- joué en ressortant
local VITESSE      = 620    -- vitesse de marche ET de course sous terre (course de chakra : 650, sv_sprint_chakra.lua)
local AVANCE_FX   = 0.2    -- secondes AVANT la fin de l'animation d'entrée où l'invisibilité et la particule démarrent
local DUREE_ENTREE_DEFAUT = 1   -- durée de l'animation d'entrée si le modèle ne la trouve pas
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "doton_taupe", stat, base) end

resource.AddFile("particles/atg_particules3.pcf")   -- sortie : atg_jutsu_petrifiant
game.AddParticles("particles/atg_particules3.pcf")
PrecacheParticleSystem(FX_SORTIE)
resource.AddFile("particles/doton_taupe.pcf")   -- copie agrandie de atg_voyage_souterrain
game.AddParticles("particles/doton_taupe.pcf")

local pret = {}   -- joueur -> moment où la technique est de nouveau disponible

-- vitesses d'avant le voyage (le serveur les envoie aux clients, qui prédisent le mouvement avec)
local function RendreVitesse(ply)
    local avant = ply.NA_VitesseAvantTaupe
    if not avant then return end
    ply.NA_VitesseAvantTaupe = nil
    ply:SetWalkSpeed(avant[1])
    ply:SetRunSpeed(avant[2])
end

local function Sortir(ply)
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Souterrain", false) then return end
    timer.Remove("doton_taupe_" .. ply:EntIndex())
    ply:SetNW2Bool("NA_Souterrain", false)
    RendreVitesse(ply)
    NA_Invisible(ply, false)   -- de nouveau visible (sv_fumainv.lua)
    NA_AnimJutsu(ply, ANIM_SORTIE)   -- animation + pas de coups pendant (_na_mudra.lua)

    net.Start("doton_taupe_fx")
        net.WriteEntity(ply)
        net.WriteBool(false)
    net.Broadcast()
    ParticleEffect(FX_SORTIE, ply:GetPos(), angle_zero)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "doton_taupe", recharge) end   -- recharge visible dans la barre
end

net.Receive("doton_taupe_cast", function(_, ply)
    if not NA_Debloquee(ply, "doton_taupe") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply:GetNW2Bool("NA_Souterrain", false) then return end   -- déjà sous terre
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    if NA_StopChakraRun then NA_StopChakraRun(ply) end   -- plus de course de chakra (sv_sprint_chakra.lua)
    ply:SetNW2Bool("NA_Souterrain", true)
    ply.NA_VitesseAvantTaupe = { ply:GetWalkSpeed(), ply:GetRunSpeed() }
    ply:SetWalkSpeed(VITESSE)
    ply:SetRunSpeed(VITESSE)
    NA_AnimJutsu(ply, ANIM_ENTREE)   -- animation + pas de coups pendant (_na_mudra.lua)
    -- juste avant la FIN de l'animation d'entrée : invisible (sv_fumainv.lua) et particule sous terre (sauf si on est déjà ressorti)
    local id = ply:LookupSequence(ANIM_ENTREE)
    local entree = (id and id >= 0) and ply:SequenceDuration(id) or DUREE_ENTREE_DEFAUT
    timer.Simple(math.max(math.min(entree, 3) - AVANCE_FX, 0), function()   -- 3 s max, comme NA_AnimJutsu
        if not IsValid(ply) or not ply:GetNW2Bool("NA_Souterrain", false) then return end
        NA_Invisible(ply, true)
        net.Start("doton_taupe_fx")
            net.WriteEntity(ply)
            net.WriteBool(true)
        net.Broadcast()
    end)

    timer.Create("doton_taupe_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function() Sortir(ply) end)
end)

-- E : ressortir tout de suite
hook.Add("KeyPress", "DotonTaupe_Sortir", function(ply, key)
    if key == IN_USE then Sortir(ply) end
end)

-- sous terre : aucun dégât (chutes comprises)
hook.Add("EntityTakeDamage", "DotonTaupe_Invulnerable", function(cible)
    if cible:IsPlayer() and cible:GetNW2Bool("NA_Souterrain", false) then return true end
end)

-- mort ou réapparition : on n'est plus sous terre (sans particule de sortie)
local function Arreter(ply)
    timer.Remove("doton_taupe_" .. ply:EntIndex())
    if not ply:GetNW2Bool("NA_Souterrain", false) then return end
    ply:SetNW2Bool("NA_Souterrain", false)
    RendreVitesse(ply)
    NA_Invisible(ply, false)
    net.Start("doton_taupe_fx")
        net.WriteEntity(ply)
        net.WriteBool(false)
    net.Broadcast()
end
hook.Add("PlayerDeath", "DotonTaupe_Mort", Arreter)
hook.Add("PlayerSpawn", "DotonTaupe_Spawn", Arreter)

hook.Add("PlayerDisconnected", "DotonTaupe_Nettoyage", function(ply)
    timer.Remove("doton_taupe_" .. ply:EntIndex())
    pret[ply] = nil
end)
