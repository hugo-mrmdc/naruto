--========================================================
-- Dash / pas chassé (PARTAGÉ serveur + client)
--
-- Un appui sur la touche de dash propulse le joueur dans la direction de ses
-- touches de déplacement et joue l'animation qui va avec :
--   avant   -> nrp_base_dashstep_front
--   gauche  -> nrp_base_dashstep_left
--   droite  -> nrp_base_dashstep_right
--   arrière -> nrp_base_dashstep_behind
-- Sans touche de direction, le dash part vers l'avant.
--
-- Le client détecte la touche et prévient le serveur, qui vérifie (recharge,
-- chakra, étourdissement...) puis applique la poussée et diffuse l'animation.
--========================================================

if SERVER then AddCSLuaFile() end

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local ACTIF         = true
local TOUCHE        = KEY_Q   -- touche du dash (KEY_Q, KEY_C, KEY_ALT...)

local FORCE         = 1000    -- vitesse de la poussée
local DUREE         = 0.25    -- secondes pendant lesquelles la vitesse est tenue
                              -- (sans ça, le frottement du sol mange le dash et
                              --  il est bien plus court qu'en l'air)
local GLISSE        = true    -- true = plus aucun frottement au sol pendant le dash
local SAUT          = 0       -- petit décollage du sol (0 = reste collé)
local RECHARGE      = 0.9     -- secondes entre deux dashs
local COUT_CHAKRA   = 8       -- chakra dépensé par dash (0 = gratuit)
local CHAKRA_MAX    = 100     -- = CHAKRA_MAX de sv_sprint_chakra.lua

local AU_SOL        = false   -- true = dash uniquement au sol
local DASH_EN_LAIR  = 1       -- nombre de dashs en l'air par saut (0 = aucun)
local LAIR_A_PLAT   = true    -- true = le dash en l'air coupe la chute (dash bien horizontal)
local LAIR_SAUT     = 0       -- petit décollage du dash en l'air (remplace SAUT)
local EN_ACCROUPI   = false   -- true = dash possible accroupi
local ARRETE_COURSE = false   -- true = le dash coupe la course de chakra

local SON           = "player/suit_sprint.wav"   -- "" = pas de son

local ANIMS = {
    avant   = "nrp_base_dashstep_front",
    gauche  = "nrp_base_dashstep_left",
    droite  = "nrp_base_dashstep_right",
    arriere = "nrp_base_dashstep_behind",
}
--========================================================

----------------------------------------------------------
-- Maintien de la vitesse (serveur ET client, en prédiction)
--
-- Au sol, le frottement freine tout de suite : la même poussée donne un dash
-- beaucoup plus court qu'en l'air. On garde donc la vitesse du dash pendant
-- DUREE secondes, au sol comme en l'air, pour que ce soit pareil partout.
----------------------------------------------------------
hook.Add("SetupMove", "NA_Dash_Maintien", function(ply, mv)
    local fin = ply:GetNW2Float("NA_DashFin", 0)
    if fin <= CurTime() then return end

    local vitesse = ply:GetNW2Vector("NA_DashVel", vector_origin)
    if vitesse:LengthSqr() < 1 then return end

    local vel = mv:GetVelocity()
    vel.x, vel.y = vitesse.x, vitesse.y
    mv:SetVelocity(vel)

    -- pendant le dash, les touches de déplacement ne freinent pas la glissade
    mv:SetForwardSpeed(0)
    mv:SetSideSpeed(0)
end)

if SERVER then
    util.AddNetworkString("na_dash")

    local pret = {}

    local function Possible(ply)
        if not ACTIF or not IsValid(ply) or not ply:Alive() then return false end
        if (pret[ply] or 0) > CurTime() then return false end
        if ply:GetMoveType() ~= MOVETYPE_WALK then return false end   -- noclip, échelle, vol
        if ply:InVehicle() or ply:WaterLevel() >= 2 then return false end
        if not ply:IsOnGround() then
            -- en l'air : nombre de dashs limité, remis à zéro en retouchant le sol
            if AU_SOL or DASH_EN_LAIR <= 0 then return false end
            if (ply.NA_DashsEnLair or 0) >= DASH_EN_LAIR then return false end
        end
        if not EN_ACCROUPI and ply:Crouching() then return false end
        if NA_EstEtourdi and NA_EstEtourdi(ply) then return false end
        if ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Vol", false) then return false end
        if ply:GetNWBool("MokutonRide", false) then return false end
        if COUT_CHAKRA > 0 and ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) < COUT_CHAKRA then return false end
        return true
    end

    -- Direction demandée par les touches, ramenée dans le monde
    local function Direction(ply)
        local avant = (ply:KeyDown(IN_FORWARD) and 1 or 0) - (ply:KeyDown(IN_BACK) and 1 or 0)
        local cote  = (ply:KeyDown(IN_MOVERIGHT) and 1 or 0) - (ply:KeyDown(IN_MOVELEFT) and 1 or 0)

        local nom = "avant"
        if avant == 0 and cote == 0 then
            avant = 1
        elseif math.abs(avant) >= math.abs(cote) then
            nom = avant > 0 and "avant" or "arriere"
        else
            nom = cote > 0 and "droite" or "gauche"
        end

        local ang = ply:EyeAngles()
        ang.p, ang.r = 0, 0
        local dir = ang:Forward() * avant + ang:Right() * cote
        dir.z = 0
        if dir:LengthSqr() < 0.01 then dir = ang:Forward() end
        dir:Normalize()

        return dir, nom
    end

    net.Receive("na_dash", function(_, ply)
        if not Possible(ply) then return end

        pret[ply] = CurTime() + RECHARGE
        if COUT_CHAKRA > 0 then
            ply:SetNW2Float("NA_Chakra", math.max(ply:GetNW2Float("NA_Chakra", CHAKRA_MAX) - COUT_CHAKRA, 0))
        end
        if ARRETE_COURSE and NA_StopChakraRun then NA_StopChakraRun(ply) end

        local dir, nom = Direction(ply)
        local enLair = not ply:IsOnGround()
        ply.NA_DashsEnLair = enLair and (ply.NA_DashsEnLair or 0) + 1 or 0

        -- on remplace la vitesse horizontale au lieu de l'ajouter, sinon le
        -- dash s'additionne à la course et part beaucoup trop loin
        local vel = ply:GetVelocity()
        local pousse = Vector(-vel.x, -vel.y, 0) + dir * FORCE
        if enLair then
            if LAIR_A_PLAT then pousse.z = pousse.z - vel.z end   -- on efface la chute
            pousse.z = pousse.z + LAIR_SAUT
        else
            pousse.z = pousse.z + SAUT
        end
        ply:SetVelocity(pousse)

        -- la vitesse est tenue pendant DUREE : au sol le frottement ne la
        -- mange plus, le dash fait la même distance qu'en l'air
        ply:SetNW2Vector("NA_DashVel", dir * FORCE)
        ply:SetNW2Float("NA_DashFin", CurTime() + DUREE)
        if GLISSE then
            ply:SetFriction(0)
            timer.Simple(DUREE, function()
                if IsValid(ply) then ply:SetFriction(1) end
            end)
        end

        local anim = ANIMS[nom]
        if anim and anim ~= "" then
            net.Start("Jutsu_Anim_Play")
                net.WriteEntity(ply)
                net.WriteString(anim)
            net.Broadcast()
        end

        if SON ~= "" then ply:EmitSound(SON, 60, math.random(100, 115), 0.5) end
    end)

    -- en retouchant le sol, les dashs en l'air sont de nouveau disponibles
    hook.Add("OnPlayerHitGround", "NA_Dash_Atterrissage", function(ply)
        ply.NA_DashsEnLair = 0
    end)

    hook.Add("PlayerSpawn", "NA_Dash_Spawn", function(ply)
        ply.NA_DashsEnLair = 0
        ply:SetNW2Float("NA_DashFin", 0)
        ply:SetFriction(1)
    end)

    hook.Add("PlayerDisconnected", "NA_Dash_Nettoyage", function(ply) pret[ply] = nil end)
    return
end

----------------------------------------------------------
-- CLIENT : détection de la touche
----------------------------------------------------------
local appuye = false
local prochain = 0

hook.Add("Think", "NA_Dash_Touche", function()
    if not ACTIF then return end

    local bas = input.IsKeyDown(TOUCHE)
    if not bas then
        appuye = false
        return
    end
    if appuye then return end
    appuye = true

    -- on ne dashe pas en train d'écrire, dans un menu ou avec le curseur
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if gui.IsGameUIVisible() or vgui.CursorVisible() or ply:IsTyping() then return end
    if CurTime() < prochain then return end
    prochain = CurTime() + RECHARGE

    net.Start("na_dash")
    net.SendToServer()
end)
