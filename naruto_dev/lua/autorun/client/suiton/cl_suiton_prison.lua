--========================================================
-- Suiton : Prison aqueuse (CLIENT)
--
-- Technique MAINTENUE : envoie le début du clic droit au serveur (sv_suiton_prison.lua, qui décide
-- de tout), puis son relâchement. Affiche la prison d'eau sur la cible et joue l'animation du
-- lanceur tant que le serveur maintient la prison.
--========================================================

local FX = "atg_prison_aqueuse"   -- particles/atg_particules_prison_aqueuse.pcf (copie de atg_particules.pcf de l'addon ATG)

game.AddParticles("particles/atg_particules_prison_aqueuse.pcf")
PrecacheParticleSystem(FX)

local SEQ_LANCEUR = "nrp_ninjutsu_attack_d45nj1_loop"   -- animation du lanceur tant que la prison tient

-- Lancement (barre de techniques : clic droit sur la technique sélectionnée).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
local tenu = false   -- le clic droit est maintenu : on prévient le serveur au relâchement

NA_Cast = NA_Cast or {}
NA_Cast.suiton_prison = function()
    net.Start("suiton_prison_cast")
        net.WriteBool(true)
    net.SendToServer()
    tenu = true
end

hook.Add("Think", "suiton_prison_relache", function()
    if tenu and not input.IsMouseDown(MOUSE_RIGHT) then
        tenu = false
        net.Start("suiton_prison_cast")
            net.WriteBool(false)
        net.SendToServer()
    end
end)

-- Prison d'eau autour de la cible, en plus de la particule.
-- Le modèle est un cylindre de 104 unités de haut et d'environ 53 de rayon, dont l'origine est en BAS
-- (mesuré dans son .vvd) : il se pose aux pieds de la cible.
local MODELE       = "models/suiton/waterprison.mdl"
local HAUTEUR_MODELE = 104
local MARGE        = 1.35  -- 1 = juste la hauteur de la cible ; plus grand = plus large autour d'elle
local ALPHA        = 255    -- transparence de la prison (255 = celle de son matériau)

-- Case "Sans bulle d'eau" (menu des techniques, clic sur la Prison aqueuse) : 1 = seulement la particule
local cvSansModele = CreateClientConVar("na_prison_sans_modele", "0", true, false, "1 = pas de bulle d'eau (modèle) autour de la cible de la prison aqueuse")

local prisons = {}   -- cible -> { fx = particule, mdl = prison d'eau, fin = fin de la prison }
local poses   = {}   -- lanceur -> { seq, prochain } animation du lanceur

-- la séquence joue-t-elle encore sur une des couches d'animation du joueur ?
local function EnCours(ply, seq)
    for i = 0, 13 do
        if ply:GetLayerSequence(i) == seq and ply:GetLayerWeight(i) > 0 then return true end
    end
    return false
end

-- L'origine du modèle est en bas : on la place pour que le cylindre soit centré en hauteur sur la cible
local function PosPrison(cible, hauteur)
    return cible:GetPos() + Vector(0, 0, (cible:OBBMins().z + cible:OBBMaxs().z) / 2 - hauteur / 2)
end

local function Fin(cible)
    local p = prisons[cible]
    if not p then return end
    if IsValid(p.fx) then p.fx:StopEmission() end
    if IsValid(p.mdl) then p.mdl:Remove() end
    prisons[cible] = nil
end

net.Receive("suiton_prison_fx", function()
    local cible   = net.ReadEntity()
    local lanceur = net.ReadEntity()
    local duree   = net.ReadFloat()

    -- fin de la prison : la prison et la pose du lanceur s'arrêtent
    if duree <= 0 then
        if IsValid(cible) then Fin(cible) end
        if IsValid(lanceur) and poses[lanceur] then
            poses[lanceur] = nil
            lanceur:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
        end
        return
    end
    if not IsValid(cible) then return end

    Fin(cible)
    if IsValid(lanceur) then
        local seq = lanceur:LookupSequence(SEQ_LANCEUR)
        if (not seq or seq < 0) and lanceur == LocalPlayer() then
            MsgC(Color(255, 80, 80), "[Prison] animation introuvable sur ", lanceur:GetModel(), " : ", SEQ_LANCEUR, "\n")
        end
        if seq and seq >= 0 then poses[lanceur] = { seq = seq, prochain = 0 } end
    end

    local mdl = not cvSansModele:GetBool() and ClientsideModel(MODELE, RENDERGROUP_TRANSLUCENT) or nil
    if IsValid(mdl) then
        -- assez haute pour contenir la cible
        local haut = cible:OBBMaxs().z - cible:OBBMins().z
        local echelle = math.max(haut, 60) * MARGE / HAUTEUR_MODELE
        mdl:SetModelScale(echelle, 0)
        mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
        mdl:SetColor(Color(255, 255, 255, ALPHA))
        mdl.Hauteur = echelle * HAUTEUR_MODELE
        mdl:SetPos(PosPrison(cible, mdl.Hauteur))
    end

    prisons[cible] = {
        fx = CreateParticleSystem(cible, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, cible:OBBCenter().z)),
        mdl = mdl,
        fin = CurTime() + duree,
    }
end)

hook.Add("Think", "suiton_prison_fx", function()
    -- pose du lanceur : lancée UNE fois sans "autokill" (elle boucle seule), relancée seulement si elle a
    -- disparu ET qu'aucune autre animation de jutsu (mudras d'une autre technique) n'est en cours
    for lanceur, pose in pairs(poses) do
        if not IsValid(lanceur) or not lanceur:Alive() then
            poses[lanceur] = nil
        elseif CurTime() >= pose.prochain and CurTime() >= (lanceur.NA_AnimFin or 0) and not EnCours(lanceur, pose.seq) then
            pose.prochain = CurTime() + 0.3
            lanceur:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, pose.seq, 0, false)
        end
    end

    for cible, p in pairs(prisons) do
        if not IsValid(cible) or not IsValid(p.fx) or CurTime() > p.fin then
            Fin(cible)
        elseif IsValid(p.mdl) then
            p.mdl:SetPos(PosPrison(cible, p.mdl.Hauteur))   -- la prison suit la cible (et son élévation)
        end
    end
end)
