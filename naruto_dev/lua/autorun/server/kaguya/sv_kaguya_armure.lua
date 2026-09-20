--========================================================
-- Kaguya : Armure d'os (SERVEUR)
--
-- Buff sur soi : pendant DUREE secondes, une armure d'os
-- (models/clan/ame/kaguya/kim_armor.mdl) apparaît sur le lanceur, fusionnée à
-- son squelette : tout le monde la voit, et elle suit ses animations.
-- Tant qu'elle tient, il encaisse beaucoup moins de dégâts.
--
-- Réseau : NW2Bool "NA_ArmureOs" et NW2Float "NA_ArmureOsFin"
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

local DUREE        = 15     -- secondes du buff
local REDUCTION    = 0.40   -- dégâts reçus en moins (0.40 = -40 %)
local MALUS_VITESSE = 0     -- vitesse de course en moins, en unités (0 = aucun malus)

local RECHARGE     = 30     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 25     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant l'armure
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "physics/body/body_medium_break3.wav"
local SON_IMPACT   = "physics/body/body_medium_scrape_rough_loop1.wav"   -- quand l'armure encaisse
local SON_FIN      = "physics/body/body_medium_break2.wav"
--========================================================

local enCours = {}
local pret    = {}

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_ArmureOs", false)
end

local function Arreter(ply)
    if not IsValid(ply) then return end
    timer.Remove("kaguya_armure_" .. ply:EntIndex())



    if Actif(ply) then
        if ply:Alive() then ply:EmitSound(SON_FIN, 75, 100, 0.7) end
        if MALUS_VITESSE > 0 then ply:SetRunSpeed(ply:GetRunSpeed() + MALUS_VITESSE) end
    end

    ply:SetNW2Bool("NA_ArmureOs", false)
    ply:SetNW2Float("NA_ArmureOsFin", 0)
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
    if not IsValid(ply) or not ply:Alive() then return end
    Arreter(ply)

    PublierPlacement(ply)


    ply:SetNW2Bool("NA_ArmureOs", true)
    ply:SetNW2Float("NA_ArmureOsFin", CurTime() + DUREE)
    ply:EmitSound(SON_DEBUT, 80, 90, 0.9)

    if MALUS_VITESSE > 0 then ply:SetRunSpeed(math.max(50, ply:GetRunSpeed() - MALUS_VITESSE)) end

    timer.Create("kaguya_armure_" .. ply:EntIndex(), DUREE, 1, function() Arreter(ply) end)
end

net.Receive("kaguya_armure_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() or Actif(ply) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if CHAKRA_COUT > 0 then
        if chakra < CHAKRA_COUT then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - CHAKRA_COUT)
    end

    enCours[ply] = true
    pret[ply] = CurTime() + RECHARGE
    if NA_CD then NA_CD.Set(ply, "kaguya_armure", RECHARGE) end   -- recharge visible dans la barre

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Résistance
----------------------------------------------------------
hook.Add("EntityTakeDamage", "KaguyaArmure_Reduction", function(cible, dmg)
    if REDUCTION <= 0 or not cible:IsPlayer() or not Actif(cible) then return end
    dmg:ScaleDamage(1 - REDUCTION)
    if SON_IMPACT ~= "" then cible:EmitSound(SON_IMPACT, 70, 130, 0.5) end
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KaguyaArmure_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "KaguyaArmure_Spawn", Arreter)

hook.Add("PlayerDisconnected", "KaguyaArmure_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
