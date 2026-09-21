--========================================================
-- Kaguya : Légion d'os (SERVEUR)
--
-- Des os jaillissent autour du lanceur pendant DUREE secondes : tout ennemi
-- dans le rayon prend des dégâts à chaque tick. La particule
-- [12]_kaguya_legion_bones (particles/atg_farisv2.pcf) tourne autour de lui,
-- affichée par cl_kaguya_legion.lua : tout le monde la voit.
--
-- Réseau : NW2Bool "NA_LegionOs" et NW2Float "NA_LegionOsFin"
--========================================================

if not SERVER then return end

util.AddNetworkString("kaguya_legion_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 8      -- secondes de la technique
local RAYON        = 180    -- rayon de la zone qui touche (developer 1 pour la voir)
local HAUTEUR      = 90     -- demi-hauteur de la zone (cylindre autour du joueur)
local DEGATS       = 12     -- dégâts par tick
local INTERVALLE   = 0.5    -- secondes entre deux ticks

local RECHARGE     = 25     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la légion
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "physics/body/body_medium_break3.wav"
local SON_TICK     = "physics/body/body_medium_impact_hard2.wav"
--========================================================

SetGlobal2Float("NA_LegionOsRayon", RAYON)

local enCours = {}
local pret    = {}

local function Actif(ply)
    return IsValid(ply) and ply:GetNW2Bool("NA_LegionOs", false)
end

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Arreter(ply)
    if not IsValid(ply) then return end
    timer.Remove("kaguya_legion_" .. ply:EntIndex())
    ply:SetNW2Bool("NA_LegionOs", false)
    ply:SetNW2Float("NA_LegionOsFin", 0)
end

local function Tick(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local base = ply:GetPos()
    local centre = base + Vector(0, 0, HAUTEUR / 2)

    for _, ent in ipairs(ents.FindInSphere(centre, RAYON + 40)) do
        if not EstCible(ent, ply) then continue end

        -- cylindre : assez près à l'horizontale, et à la bonne hauteur
        local pos = ent:GetPos()
        local ecart = Vector(pos.x - base.x, pos.y - base.y, 0):Length()
        local haut = pos.z + ent:OBBMaxs().z
        local bas = pos.z + ent:OBBMins().z
        if ecart > RAYON or haut < base.z - 20 or bas > base.z + HAUTEUR then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "kaguya_legion", "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(SON_TICK, 70, math.random(95, 110), 0.7)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(centre, RAYON, INTERVALLE, Color(255, 240, 210, 20), true)
    end
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    Arreter(ply)

    ply:SetNW2Bool("NA_LegionOs", true)
    ply:SetNW2Float("NA_LegionOsFin", CurTime() + DUREE)
    ply:EmitSound(SON_DEBUT, 85, 80, 1)

    local fin = CurTime() + DUREE
    timer.Create("kaguya_legion_" .. ply:EntIndex(), INTERVALLE, 0, function()
        if not IsValid(ply) or not ply:Alive() or CurTime() >= fin then
            Arreter(ply)
            return
        end
        Tick(ply)
    end)
end

net.Receive("kaguya_legion_cast", function(_, ply)
    if not NA_Debloquee(ply, "kaguya_legion") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() or Actif(ply) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "kaguya_legion", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "kaguya_legion", "chakra", CHAKRA_COUT) then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "kaguya_legion", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "kaguya_legion", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kaguya_legion", NA_Stat(ply, "kaguya_legion", "recharge", RECHARGE)) end   -- recharge visible dans la barre

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
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KaguyaLegion_Mort", function(ply)
    enCours[ply] = nil
    Arreter(ply)
end)

hook.Add("PlayerSpawn", "KaguyaLegion_Spawn", Arreter)

hook.Add("PlayerDisconnected", "KaguyaLegion_Nettoyage", function(ply)
    Arreter(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
