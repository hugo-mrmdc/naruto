--========================================================
-- Animation de saut (CLIENT)
--
-- En l'air, GMod joue l'animation de saut du type de prise de l'arme tenue
-- (poings, mains vides, épée...) : ça donne les mains jointes devant soi, comme si on
-- tenait un pistolet. Ce fichier remplace cette animation par une autre,
-- choisie parmi celles du modèle du joueur.
--
-- Commandes :
--   na_saut_anim NOM     animation de saut à utiliser (défaut : jump_knife) ;
--                        "" = animation de saut d'origine de GMod
--   na_saut_liste        affiche les animations de saut disponibles sur ton modèle
--   na_saut_essai NOM    joue cette animation pendant 3 s sans avoir à sauter,
--                        pour comparer les poses (puis na_saut_anim NOM pour la garder)
--
-- Le coup d'épée en l'air et le double saut gardent leur propre animation
-- (naruto_arme_base.lua, sh_double_saut.lua) : ce fichier ne s'occupe que du saut « nu ».
--========================================================

local cvAnim = CreateClientConVar("na_saut_anim", "jump_knife", true, false,
    "Animation de saut (\"\" = animation d'origine de GMod)")

local function Seq(ply, nom)
    if not nom or nom == "" then return end
    local seq = ply:LookupSequence(nom)
    if seq and seq >= 0 then return seq end
end

-- essai en cours : joue une animation quelques secondes, au sol comme en l'air
local essai   -- { nom, fin }

-- Le joueur est-il dans un état où une autre animation doit passer avant ?
local function AutreAnimation(ply)
    if ply:InVehicle() or ply:WaterLevel() >= 2 then return true end
    if ply:GetMoveType() ~= MOVETYPE_WALK then return true end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return true end
    if ply:GetNW2Bool("NA_Etourdi", false) or ply:GetNW2Bool("NA_RechargeChakra", false) then return true end
    if ply:GetNW2Bool("NA_Canalise", false) or ply:GetNW2Bool("NA_Golem", false) then return true end
    if (ply:GetNWBool("MokutonRide", false) or ply:GetNWBool("InkutonRide", false)) then return true end
    if ply:GetNW2Float("NA_FrappeFin", 0) > CurTime() then return true end   -- frappe terrestre Senju (cl_senju_frappe.lua)

    -- Les mudras se superposent au saut ; seuls les jutsus qui remplacent
    -- l'animation principale prennent aussi la main sur les jambes.
    local jutsu = Jutsu and Jutsu.Anim and Jutsu.Anim.EnLair and Jutsu.Anim.EnLair(ply)
    if jutsu and not jutsu.upperBody then return true end

    -- un coup d'arme donné en l'air a sa propre animation (naruto_arme_base.lua)
    local g = ply.NA_GesteArme
    if g and g.seq and CurTime() - g.debut < g.duree then return true end
    return false
end

local function SequenceDeSaut(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply == LocalPlayer() and essai then
        if CurTime() < essai.fin then return Seq(ply, essai.nom) end
        essai = nil
    end

    if ply:OnGround() or AutreAnimation(ply) then return end
    return Seq(ply, cvAnim:GetString())
end

hook.Add("CalcMainActivity", "NA_Saut_Anim", function(ply)
    local seq = SequenceDeSaut(ply)
    if seq then return ACT_MP_JUMP, seq end
end)

-- forcée à chaque image : GMod ne la remplace pas par celle de l'arme
hook.Add("UpdateAnimation", "NA_Saut_Anim_Force", function(ply)
    local seq = SequenceDeSaut(ply)
    if not seq then return end
    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

--------------------------------------------------------
-- Commandes
--------------------------------------------------------
concommand.Add("na_saut_liste", function()
    local ply = LocalPlayer()
    print("[Saut] animations de saut sur ton modèle (" .. ply:GetModel() .. ") :")
    local trouve = 0
    for i = 0, ply:GetSequenceCount() - 1 do
        local nom = ply:GetSequenceName(i)
        if nom and string.find(string.lower(nom), "jump", 1, true) then
            print("   " .. nom)
            trouve = trouve + 1
        end
    end
    print(string.format("[Saut] %d trouvée(s). Actuelle : \"%s\"", trouve, cvAnim:GetString()))
end, nil, "Liste les animations de saut du modèle.")

concommand.Add("na_saut_essai", function(ply, cmd, args)
    local nom = args[1]
    local joueur = LocalPlayer()
    if not nom or not Seq(joueur, nom) then
        print("[Saut] usage : na_saut_essai NOM   (voir la liste avec na_saut_liste)")
        return
    end
    essai = { nom = nom, fin = CurTime() + 3 }
    print("[Saut] essai de \"" .. nom .. "\" pendant 3 s. Pour la garder : na_saut_anim " .. nom)
end, nil, "Joue une animation de saut pendant 3 s pour la comparer.")
