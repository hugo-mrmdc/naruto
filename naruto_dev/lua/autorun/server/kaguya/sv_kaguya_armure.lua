--========================================================
-- Kaguya : Armure d'os (SERVEUR)
--
-- Technique à activer / désactiver (même touche) :
--   - une armure d'os (models/clan/ame/kaguya/kim_armor.mdl) apparaît sur le
--     lanceur, fusionnée à son squelette : tout le monde la voit, et elle suit
--     ses animations ;
--   - tant qu'elle est active, il encaisse beaucoup moins de dégâts ;
--   - elle consomme du chakra chaque seconde (la régénération AUTOMATIQUE est
--     coupée, mais on peut recharger avec R en même temps : sv_sprint_chakra.lua) ;
--     à 0 chakra, elle se désactive.
--
-- Réseau : NW2Bool "NA_ArmureOs" (active)
--========================================================

if not SERVER then return end

util.AddNetworkString("kaguya_armure_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local MODELE       = "models/clan/ame/kaguya/kim_armor.mdl"

-- Placement de l'armure. Elle est dessinée par tous les clients
-- (cl_kaguya_armure.lua) : calée à chaque image sur l'os de la colonne, donc elle
-- suit l'animation même en pleine course, tout en acceptant un décalage.
-- Les valeurs sont envoyées aux clients : c'est bien ici qu'on les change.
-- Réglage en jeu (l'armure doit être active) :
--   kaguya_armure_placer <avant> <droite> <haut> <tangage> <lacet> <roulis> <taille>
local OS           = "ValveBiped.Bip01_Spine4"   -- os de référence (celui du modèle)
local DECALAGE     = Vector(-3, 0, 3)            -- avant / droite / haut, dans le repère de l'os
local ROTATION     = Angle(-90, 90, 0)
local ECHELLE      = 1

local REDUCTION    = 40    -- % de dégâts reçus en moins
local MALUS_VITESSE = 0     -- vitesse de course en moins, en unités (0 = aucun malus)

local CHAKRA_SEC   = 4      -- chakra consommé par seconde
local CHAKRA_MINI  = 20     -- chakra requis pour l'activer
local RECHARGE     = 10     -- secondes avant de pouvoir la réactiver (après l'arrêt)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant l'armure
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "naruto_sound/jutsu/uchiha/uchiha4.wav"
local SON_IMPACT   = "naruto_sound/jutsu/uchiha/uchiha5.wav"   -- quand l'armure encaisse
local SON_FIN      = "naruto_sound/jutsu/uchiha/uchiha6.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kaguya_armure", stat, base) end

local enCours = {}
local pret    = {}

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_ArmureOs", false)
end

local function Arreter(ply, raison)
    if not IsValid(ply) then return end

    if Actif(ply) then
        local recharge = Niv(ply, "recharge", RECHARGE)
        pret[ply] = CurTime() + recharge
        if NA_CD then NA_CD.Set(ply, "kaguya_armure", recharge) end   -- recharge visible dans la barre

        if ply:Alive() then ply:EmitSound(SON_FIN, 75, 100, 0.7) end
        if Niv(ply, "malus_vitesse", MALUS_VITESSE) > 0 then ply:SetRunSpeed(ply:GetRunSpeed() + Niv(ply, "malus_vitesse", MALUS_VITESSE)) end
        if raison then ply:PrintMessage(HUD_PRINTCENTER, raison) end
    end

    ply:SetNW2Bool("NA_ArmureOs", false)
end
NA_KaguyaArmureFin = Arreter

-- Envoie le modèle et le placement à tous les clients, qui dessinent l'armure
local function PublierPlacement(ply)
    ply:SetNW2String("NA_ArmureModele", MODELE)
    ply:SetNW2String("NA_ArmureOsNom", OS)
    ply:SetNW2Vector("NA_ArmureDecalage", DECALAGE)
    ply:SetNW2Angle("NA_ArmureRotation", ROTATION)
    ply:SetNW2Float("NA_ArmureEchelle", ECHELLE)
end

-- Réglage en direct : kaguya_armure_placer <avant> <droite> <haut> <tangage> <lacet> <roulis> [taille]
concommand.Add("kaguya_armure_placer", function(ply, _, args)
    if not IsValid(ply) or not ply:GetNW2Bool("NA_ArmureOs", false) then
        if IsValid(ply) then ply:ChatPrint("Lance d'abord l'armure d'os.") end
        return
    end

    local n = {}
    for i = 1, 7 do n[i] = tonumber(args[i]) end
    DECALAGE = Vector(n[1] or DECALAGE.x, n[2] or DECALAGE.y, n[3] or DECALAGE.z)
    ROTATION = Angle(n[4] or ROTATION.p, n[5] or ROTATION.y, n[6] or ROTATION.r)
    ECHELLE  = n[7] or ECHELLE
    PublierPlacement(ply)

    ply:ChatPrint(string.format("Armure : DECALAGE = Vector(%g, %g, %g) | ROTATION = Angle(%g, %g, %g) | ECHELLE = %g",
        DECALAGE.x, DECALAGE.y, DECALAGE.z, ROTATION.p, ROTATION.y, ROTATION.r, ECHELLE))
end)

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() or Actif(ply) then return end

    PublierPlacement(ply)

    ply:SetNW2Bool("NA_ArmureOs", true)
    ply:EmitSound(SON_DEBUT, 80, 90, 0.9)

    if Niv(ply, "malus_vitesse", MALUS_VITESSE) > 0 then ply:SetRunSpeed(math.max(50, ply:GetRunSpeed() - Niv(ply, "malus_vitesse", MALUS_VITESSE))) end
end

net.Receive("kaguya_armure_cast", function(_, ply)
    if not IsValid(ply) then return end

    -- déjà active : on la coupe, toujours (avant toute autre vérification)
    if Actif(ply) then return Arreter(ply) end

    if not NA_Debloquee(ply, "kaguya_armure") then return end   -- technique pas encore débloquée (F6)
    if not ply:Alive() or enCours[ply] then return end

    if (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) < Niv(ply, "chakra_mini", CHAKRA_MINI) then
        -- (pas de message)
        return
    end

    enCours[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

-- secours : couper l'armure depuis la console ou le chat
concommand.Add("kaguya_armure_off", function(ply)
    if IsValid(ply) then Arreter(ply) end
end)

----------------------------------------------------------
-- Consommation du chakra (10 fois par seconde)
----------------------------------------------------------
local prochain = 0
hook.Add("Think", "KaguyaArmure_Chakra", function()
    local now = CurTime()
    if now < prochain then return end
    local dt = 0.1
    prochain = now + dt

    for _, ply in ipairs(player.GetAll()) do
        if not Actif(ply) then continue end
        local reste = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - Niv(ply, "chakra", CHAKRA_SEC) * dt
        ply:SetNW2Float("NA_Chakra", math.Clamp(reste, 0, NA_ChakraMax(ply)))
        if reste <= 0 then Arreter(ply, "Chakra épuisé : l'armure d'os se brise") end
    end
end)

----------------------------------------------------------
-- Résistance
----------------------------------------------------------
hook.Add("EntityTakeDamage", "KaguyaArmure_Reduction", function(cible, dmg)
    if Niv(cible, "reduction", REDUCTION) <= 0 or not cible:IsPlayer() or not Actif(cible) then return end
    dmg:ScaleDamage(1 - Niv(cible, "reduction", REDUCTION) / 100)
    if SON_IMPACT ~= "" then cible:EmitSound(SON_IMPACT, 70, 130, 0.5) end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KaguyaArmure_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "KaguyaArmure_Spawn", function(ply) Arreter(ply) end)

hook.Add("PlayerDisconnected", "KaguyaArmure_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
