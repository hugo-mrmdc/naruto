--========================================================
-- Kaguya : Absorption (SERVEUR)
--
-- Technique de CIBLAGE : on vise un ennemi, un lien se crée entre le lanceur
-- et lui (particule izox_kaguya_attire, particles/1izoxsolvenr.pcf : un bout
-- accroché au lanceur, l'autre à la cible). Tant que le lien tient, la cible
-- perd de la vie et le lanceur en récupère.
-- Le lien casse si la cible meurt, sort de la portée ou si la durée est finie.
--
-- Réseau : NW2Entity "NA_KaguyaAttireCible" sur le lanceur (invalide = pas de
-- lien), affiché par cl_kaguya_danse.lua.
--========================================================

if not SERVER then return end

util.AddNetworkString("kaguya_danse_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 6      -- secondes du lien
local INTERVALLE   = 0.5    -- secondes entre deux ticks

local PORTEE       = 900    -- portée de visée pour accrocher une cible
local PORTEE_CASSE = 1100   -- au-delà de cette distance, le lien casse
local ANGLE_VISEE  = 12     -- tolérance de visée en degrés (plus grand = plus facile)
local A_TRAVERS    = false  -- true = on peut accrocher à travers les murs

local DEGATS       = 12     -- dégâts par tick sur la cible
local SOIN         = 8      -- vie rendue au lanceur par tick

local RECHARGE     = 20     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.4    -- incantation avant l'accroche
local ANIM_APPEL   = "nrp_ninjutsu_attack_rasenganinvisible_attack_end"

local SON_ACCROCHE = "physics/body/body_medium_break3.wav"
local SON_TICK     = "physics/body/body_medium_impact_hard2.wav"
local SON_SOIN     = "items/medshot4.wav"
--========================================================

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Cherche la cible visée : la plus proche du centre de l'écran, dans la portée
local function Chercher(ply)
    local oeil = ply:EyePos()
    local vue  = ply:GetAimVector()
    local meilleure, meilleurEcart

    for _, ent in ipairs(ents.FindInSphere(oeil, PORTEE)) do
        if not EstCible(ent, ply) then continue end

        local vers = ent:WorldSpaceCenter() - oeil
        local dist = vers:Length()
        if dist < 1 then continue end
        vers:Normalize()

        local ecart = math.deg(math.acos(math.Clamp(vers:Dot(vue), -1, 1)))
        if ecart > ANGLE_VISEE then continue end

        if not A_TRAVERS then
            local tr = util.TraceLine({
                start = oeil,
                endpos = ent:WorldSpaceCenter(),
                filter = { ply, ent },
                mask = MASK_SOLID_BRUSHONLY,
            })
            if tr.Hit then continue end
        end

        if not meilleurEcart or ecart < meilleurEcart then
            meilleure, meilleurEcart = ent, ecart
        end
    end

    return meilleure
end

local function Arreter(ply)
    if not IsValid(ply) then return end
    timer.Remove("kaguya_attire_" .. ply:EntIndex())
    ply:SetNW2Entity("NA_KaguyaAttireCible", NULL)
end

-- Rend de la vie au lanceur sans dépasser son maximum
local function Soigner(ply, montant)
    if montant <= 0 then return 0 end
    local rendu = math.min(montant, math.max(ply:GetMaxHealth() - ply:Health(), 0))
    if rendu <= 0 then return 0 end
    ply:SetHealth(ply:Health() + rendu)
    return rendu
end

local function Tick(ply, cible)
    local dmg = DamageInfo()
    dmg:SetDamage(NA_Stat(ply, "kaguya_danse", "degats", DEGATS))
    dmg:SetAttacker(ply)
    dmg:SetInflictor(ply)
    dmg:SetDamageType(DMG_SLASH)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)
    cible:EmitSound(SON_TICK, 70, math.random(95, 110), 0.7)

    if Soigner(ply, NA_Stat(ply, "kaguya_danse", "degats", SOIN)) > 0 then
        ply:EmitSound(SON_SOIN, 60, math.random(95, 105), 0.35)
    end
end

local function Accrocher(ply, cible)
    if not IsValid(ply) or not ply:Alive() or not EstCible(cible, ply) then return end
    Arreter(ply)

    ply:SetNW2Entity("NA_KaguyaAttireCible", cible)
    ply:EmitSound(SON_ACCROCHE, 85, 80, 1)

    local fin = CurTime() + DUREE
    timer.Create("kaguya_attire_" .. ply:EntIndex(), INTERVALLE, 0, function()
        if not IsValid(ply) or not ply:Alive() or CurTime() >= fin
            or not EstCible(cible, ply)
            or ply:GetPos():Distance(cible:GetPos()) > PORTEE_CASSE then
            Arreter(ply)
            return
        end
        Tick(ply, cible)
    end)
end

net.Receive("kaguya_danse_cast", function(_, ply)
    if not NA_Debloquee(ply, "kaguya_danse") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end
    if IsValid(ply:GetNW2Entity("NA_KaguyaAttireCible")) then return end

    -- pas de cible visée : rien ne part, pas de chakra dépensé, pas de message
    local cible = Chercher(ply)
    if not IsValid(cible) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "kaguya_danse", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "kaguya_danse", "chakra", CHAKRA_COUT) then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "kaguya_danse", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "kaguya_danse", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kaguya_danse", NA_Stat(ply, "kaguya_danse", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        if not IsValid(ply) then return end
        -- la cible a pu bouger pendant l'incantation : on revise
        local finale = EstCible(cible, ply) and cible or Chercher(ply)
        Accrocher(ply, finale)
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KaguyaAttire_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "KaguyaAttire_Spawn", Arreter)

hook.Add("PlayerDisconnected", "KaguyaAttire_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)

-- si la cible meurt, le lien s'arrête tout de suite
hook.Add("EntityRemoved", "KaguyaAttire_CibleRetiree", function(ent)
    for _, ply in ipairs(player.GetAll()) do
        if ply:GetNW2Entity("NA_KaguyaAttireCible") == ent then Arreter(ply) end
    end
end)
