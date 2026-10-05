--========================================================
-- Jiton : Sarcophage de sable (SERVEUR)
--
-- On vise un ennemi à portée. Après les mudras, un sarcophage de sable se
-- referme sur la cible touchée (particule [1]_sand_sarcophag,
-- particles/atg_faris.pcf) :
--   - elle prend des dégâts UNE SEULE FOIS, au moment où le sable la saisit ;
--   - elle est étourdie DUREE secondes (étourdissement commun,
--     sv_etourdissement.lua), avec le sarcophage sur elle tant qu'elle l'est.
--
-- Réseau : "jiton_sarcophage_fx" (cible + durée) -> cl_jiton_sarcophage.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("jiton_sarcophage_cast")
util.AddNetworkString("jiton_sarcophage_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 800    -- distance maximale de la cible
local TAILLE_VISEE  = 20     -- demi-taille de la hitbox de visée (plus grand = plus facile de viser)
                             -- visible avec : developer 1

local DUREE         = 3      -- secondes d'étourdissement
local DEGATS        = 20     -- dégâts, une seule fois

local RECHARGE      = 20     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.5    -- incantation avant le sarcophage
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_APPEL     = "naruto_sound/jutsu/jishaku/jishaku6.wav"
local SON_PRISE     = "naruto_sound/jutsu/jishaku/jishaku1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jiton_sarcophage", stat, base) end

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Ennemi visé : boîte lancée depuis les yeux le long du regard, jusqu'au
-- premier mur ; on prend la cible valable la plus proche (comme le Cube Jinton)
local function TrouverCible(ply)
    local oeil = ply:EyePos()
    local taille = Niv(ply, "hitbox", TAILLE_VISEE)
    local t = Vector(taille, taille, taille)
    local portee = Niv(ply, "portee", PORTEE)

    -- le mur est mesuré avec un simple RAYON : avec la boîte, le sol la coupait très tôt dès qu'on visait bas
    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.SweptBox(oeil, mur.HitPos, -t, t, angle_zero, 2, cible and Color(0, 255, 0, 40) or Color(255, 60, 60, 40))
    end

    return cible
end

local function Emprisonner(ply, cible)
    local duree = Niv(ply, "duree", DUREE)

    local dmg = DamageInfo()
    dmg:SetDamage(Niv(ply, "degats", DEGATS))
    dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
    dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
    dmg:SetDamageType(DMG_CRUSH)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)

    if NA_Etourdir then NA_Etourdir(cible, duree) end
    cible:EmitSound(SON_PRISE, 75, math.random(90, 105), 0.8)

    net.Start("jiton_sarcophage_fx")
        net.WriteEntity(cible)
        net.WriteFloat(duree)
    net.Broadcast()
end

net.Receive("jiton_sarcophage_cast", function(_, ply)
    if not NA_Debloquee(ply, "jiton_sarcophage") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cible = TrouverCible(ply)

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "jiton_sarcophage", recharge) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    ply:EmitSound(SON_APPEL, 70, 90, 0.8)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        -- la cible a pu mourir ou s'éloigner pendant l'incantation
        local portee = Niv(ply, "portee", PORTEE)
        if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > portee * 1.2 then return end
        Emprisonner(ply, cible)
    end)
end)

hook.Add("PlayerDeath", "JitonSarcophage_Mort", function(ply)
    enCours[ply] = nil
end)

hook.Add("PlayerDisconnected", "JitonSarcophage_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
