--========================================================
-- Mokuton : Golem de bois (PARTAGÉ serveur + client)
--
-- Le joueur devient le golem (models/mokuton/nr_mokuton_golem.mdl) : NW2Bool "NA_Golem" posé par
-- autorun/server/mokuton/mokuton_golem_sv.lua. Ici, ce qui doit tourner des DEUX côtés (prédiction) :
--   - animations : nr_golem_idle / nr_golem_walk, et nr_golem_atk1..3 pendant une attaque ;
--   - le clic gauche ne tire plus avec l'arme : il lance l'attaque du golem (lue par le serveur) ;
--   - la boîte de collision du joueur est celle du golem (SetHull), remise à la normale ensuite.
--========================================================

if SERVER then AddCSLuaFile() end

NA_GOLEM = NA_GOLEM or {}

--========================================================
-- RÉGLAGES
--========================================================
NA_GOLEM.MODELE  = "models/mokuton/nr_mokuton_golem.mdl"
NA_GOLEM.ECHELLE = 0.25    -- taille du modèle (1 = ~945 unités de haut ; à 0,25 : ~236, environ 3 fois un joueur)
NA_GOLEM.HULL_MINS = Vector(-40, -40, 0)
NA_GOLEM.HULL_MAXS = Vector(40, 40, 220)     -- boîte de collision debout
NA_GOLEM.VUE       = 200                     -- hauteur des yeux (caméra)
NA_GOLEM.VITESSE_ANIM = 1.5   -- vitesse des animations d'attaque et de repos (1 = normale) ; la marche suit ta vitesse réelle

local ANIM_IDLE = "nr_golem_idle"
local ANIM_WALK = "nr_golem_walk"
local ANIM_ATK  = { "nr_golem_atk1", "nr_golem_atk2", "nr_golem_atk3" }
--========================================================

-- Attaque : le clic gauche ne tire plus avec l'arme.
-- ATTENTION : la commande est modifiée CÔTÉ CLIENT avant d'être envoyée au serveur, qui ne verrait donc plus jamais
-- le clic. Le client détecte donc lui-même le clic (souris, comme les autres techniques : voir plus bas) et PRÉVIENT
-- le serveur par un message ; la touche est ensuite retirée de la commande pour que l'arme ne tire pas.
hook.Add("StartCommand", "MokutonGolem_Touches", function(ply, cmd)
    if not ply:GetNW2Bool("NA_Golem", false) then return end
    cmd:RemoveKey(bit.bor(IN_ATTACK, IN_ATTACK2))
end)

if CLIENT then
    local toucheAtk = false

    -- lu directement sur la souris (une fois par appui) ; pas dans le chat, un menu ou avec le curseur
    hook.Add("Think", "MokutonGolem_Clic", function()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() or not lp:GetNW2Bool("NA_Golem", false) then
            toucheAtk = false
            return
        end

        local clic = input.IsMouseDown(MOUSE_LEFT)
        local libre = not (vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or vgui.CursorVisible() or lp:IsTyping())
        if clic and not toucheAtk and libre then
            net.Start("mokuton_golem_atk")
            net.SendToServer()
        end
        toucheAtk = clic
    end)
end

-- Séquence du golem selon ce qu'il fait
hook.Add("CalcMainActivity", "MokutonGolem_Anim", function(ply, vel)
    if not ply:GetNW2Bool("NA_Golem", false) then return end

    local n = ply:GetNW2Int("NA_GolemAtk", 0)
    local nom
    if n > 0 and ply:GetNW2Float("NA_GolemAtkFin", 0) > CurTime() then
        nom = ANIM_ATK[n]
    elseif vel:Length2D() > 20 then
        nom = ANIM_WALK
    else
        nom = ANIM_IDLE
    end

    local id = ply:LookupSequence(nom)
    if id and id >= 0 then return ACT_INVALID, id end
end)

-- Vitesse de lecture : la marche suit la vitesse réelle, l'attaque repart de zéro à chaque coup
hook.Add("UpdateAnimation", "MokutonGolem_Vitesse", function(ply, vel)
    if not ply:GetNW2Bool("NA_Golem", false) then return end

    if ply:GetNW2Float("NA_GolemAtkFin", 0) > CurTime() then
        local debut = ply:GetNW2Float("NA_GolemAtkDebut", 0)
        if ply.NA_GolemAtkVu ~= debut then
            ply.NA_GolemAtkVu = debut
            ply:SetCycle(0)
        end
        ply:SetPlaybackRate(NA_GOLEM.VITESSE_ANIM)
    else
        local id = ply:GetSequence()
        local vitesse = vel:Length2D()
        local base = ply:GetSequenceGroundSpeed(id)
        if vitesse > 20 and base and base > 1 then
            ply:SetPlaybackRate(math.Clamp(vitesse / base, 0.3, 2.5))
        else
            ply:SetPlaybackRate(NA_GOLEM.VITESSE_ANIM)   -- repos
        end
    end
    return true
end)

-- Boîte de collision : celle du golem tant qu'il est actif, la normale ensuite (des deux côtés, pour la prédiction)
timer.Create("MokutonGolem_Hull", 0.1, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local golem = ply:GetNW2Bool("NA_Golem", false)
        if golem and not ply.NA_GolemHull then
            ply.NA_GolemHull = true
            ply:SetHull(NA_GOLEM.HULL_MINS, NA_GOLEM.HULL_MAXS)
            ply:SetHullDuck(NA_GOLEM.HULL_MINS, NA_GOLEM.HULL_MAXS)
            ply:SetViewOffset(Vector(0, 0, NA_GOLEM.VUE))
            ply:SetViewOffsetDucked(Vector(0, 0, NA_GOLEM.VUE))
        elseif not golem and ply.NA_GolemHull then
            ply.NA_GolemHull = nil
            ply:ResetHull()
            ply:SetViewOffset(Vector(0, 0, 64))
            ply:SetViewOffsetDucked(Vector(0, 0, 28))
        end
    end
end)
