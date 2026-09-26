--========================================================
-- Chinoike : Genjutsu du Ketsuryugan (SERVEUR)
--
-- On vise un ennemi à portée. Après les mudras, le Ketsuryugan s'allume sur
-- la cible touchée (particule ketsuryugan_pat, particles/patlick_atgparticules.pcf)
-- et elle tombe dans le genjutsu pendant DUREE secondes :
--   - elle est paralysée (étourdissement commun, sv_etourdissement.lua) ;
--   - des traînées de sang tournent autour d'elle
--     (particule [16]_shield, particles/ctg_chinoike_nael.pcf) ;
--   - elle perd de la vie à chaque tick ;
--   - si c'est un joueur, son écran vire au rouge (cl_chinoike_genjutsu.lua).
--
-- Réseau : "chinoike_genjutsu_oeil"  (cible)            -> Ketsuryugan sur la cible
--          "chinoike_genjutsu_cible" (cible + durée)    -> sang + écran rouge
--========================================================

if not SERVER then return end

util.AddNetworkString("chinoike_genjutsu_cast")
util.AddNetworkString("chinoike_genjutsu_oeil")
util.AddNetworkString("chinoike_genjutsu_cible")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 800    -- distance maximale de la cible
local TAILLE_VISEE  = 20     -- demi-taille de la hitbox de visée (plus grand = plus facile de viser)
                             -- visible avec : developer 1

local DUREE         = 3      -- secondes de genjutsu (paralysie + sang + écran rouge)
local DEGATS        = 6      -- dégâts par tick pendant le genjutsu
local INTERVALLE    = 0.5    -- secondes entre deux ticks

local RECHARGE      = 25     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.5    -- incantation avant le genjutsu
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_OEIL      = "ambient/levels/citadel/weapon_disintegrate2.wav"
local SON_TICK      = "physics/flesh/flesh_squishy_impact_hard1.wav"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "chinoike_genjutsu", stat, base) end

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
    local taille = NA_Stat(ply, "chinoike_genjutsu", "hitbox", TAILLE_VISEE)
    local t = Vector(taille, taille, taille)
    local portee = NA_Stat(ply, "chinoike_genjutsu", "portee", PORTEE)

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

local function Blesser(ply, cible)
    local dmg = DamageInfo()
    dmg:SetDamage(NA_Stat(ply, "chinoike_genjutsu", "degats", DEGATS))
    dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
    dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
    dmg:SetDamageType(DMG_SLASH)
    dmg:SetDamagePosition(cible:WorldSpaceCenter())
    cible:TakeDamageInfo(dmg)
    cible:EmitSound(SON_TICK, 70, math.random(90, 110), 0.6)
end

local function Pieger(ply, cible)
    local duree = NA_Stat(ply, "chinoike_genjutsu", "duree", DUREE)

    -- le Ketsuryugan s'allume sur la cible touchée
    net.Start("chinoike_genjutsu_oeil")
        net.WriteEntity(cible)
    net.Broadcast()
    cible:EmitSound(SON_OEIL, 75, 120, 0.7)

    -- la cible est prise dans le genjutsu
    net.Start("chinoike_genjutsu_cible")
        net.WriteEntity(cible)
        net.WriteFloat(duree)
    net.Broadcast()

    if NA_Etourdir then NA_Etourdir(cible, duree) end

    local fin = CurTime() + duree
    local nom = "chinoike_genjutsu_" .. cible:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(nom, Niv(ply, "intervalle", INTERVALLE), 0, function()
        if CurTime() >= fin + 0.01 or not EstCible(cible, ply) then
            timer.Remove(nom)
            return
        end
        Blesser(ply, cible)
    end)
end

net.Receive("chinoike_genjutsu_cast", function(_, ply)
    if not NA_Debloquee(ply, "chinoike_genjutsu") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cible = TrouverCible(ply)
    if not cible then return end   -- personne dans le viseur : rien n'est dépensé

    local cout = NA_Stat(ply, "chinoike_genjutsu", "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = NA_Stat(ply, "chinoike_genjutsu", "recharge", RECHARGE)
    enCours[ply] = true
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "chinoike_genjutsu", recharge) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        -- la cible a pu mourir ou s'éloigner pendant l'incantation
        local portee = NA_Stat(ply, "chinoike_genjutsu", "portee", PORTEE)
        if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > portee * 1.2 then return end
        Pieger(ply, cible)
    end)
end)

hook.Add("PlayerDisconnected", "ChinoikeGenjutsu_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
