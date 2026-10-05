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
-- Un golem a un TYPE (NW2String "NA_GolemType" posé par le serveur ; "mokuton" par défaut). Chaque type donne son modèle, sa
-- taille, sa boîte de collision, ses animations et le message réseau de son clic d'attaque. Mokuton : mokuton_golem_sv.lua ;
-- Doton : doton_golem_sv.lua (lv_golem_dot, animations lv_idle1 / walk / lv_attack1 / lv_death1).
NA_GOLEM.TYPES = {
    mokuton = {
        modele = "models/mokuton/nr_mokuton_golem.mdl",
        echelle = 0.25,   -- taille du modèle (1 = ~945 unités de haut ; à 0,25 : ~236, environ 3 fois un joueur)
        hull_mins = Vector(-40, -40, 0), hull_maxs = Vector(40, 40, 220),   -- boîte de collision debout
        vue = 200,                                                           -- hauteur des yeux (caméra)
        vitesse_anim = 1.5,   -- vitesse des animations d'attaque et de repos (1 = normale) ; la marche suit ta vitesse réelle
        idle = "nr_golem_idle", walk = "nr_golem_walk", atk = { "nr_golem_atk1", "nr_golem_atk2", "nr_golem_atk3" },
        net_atk = "mokuton_golem_atk",
    },
    doton = {
        modele = "models/nature/doton/lv_golem_dot.mdl",
        echelle = 0.55,   -- ~350 unités de haut à l'échelle 1 : ~190 à 0,55, soit environ 2,5 fois un joueur
        hull_mins = Vector(-40, -40, 0), hull_maxs = Vector(40, 40, 190),
        vue = 170,
        vitesse_anim = 1,
        idle = "lv_idle1", walk = "walk", atk = { "lv_attack1" }, mort = "lv_death1",
        net_atk = "doton_golem_atk",
    },
}

-- compatibilité (Mokuton) : les réglages du type mokuton restent accessibles comme avant
NA_GOLEM.MODELE       = NA_GOLEM.TYPES.mokuton.modele
NA_GOLEM.ECHELLE      = NA_GOLEM.TYPES.mokuton.echelle
NA_GOLEM.HULL_MINS    = NA_GOLEM.TYPES.mokuton.hull_mins
NA_GOLEM.HULL_MAXS    = NA_GOLEM.TYPES.mokuton.hull_maxs
NA_GOLEM.VUE          = NA_GOLEM.TYPES.mokuton.vue
NA_GOLEM.VITESSE_ANIM = NA_GOLEM.TYPES.mokuton.vitesse_anim

-- type du golem d'un joueur
function NA_GOLEM.Type(ply)
    return NA_GOLEM.TYPES[ply:GetNW2String("NA_GolemType", "mokuton")] or NA_GOLEM.TYPES.mokuton
end
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
            net.Start(NA_GOLEM.Type(lp).net_atk)
            net.SendToServer()
        end
        toucheAtk = clic
    end)
end

-- Séquence du golem selon ce qu'il fait (mort -> attaque -> marche -> repos)
hook.Add("CalcMainActivity", "MokutonGolem_Anim", function(ply, vel)
    if not ply:GetNW2Bool("NA_Golem", false) then return end
    local t = NA_GOLEM.Type(ply)

    local nom
    if t.mort and ply:GetNW2Float("NA_GolemMortFin", 0) > CurTime() then
        nom = t.mort
    else
        local n = ply:GetNW2Int("NA_GolemAtk", 0)
        if n > 0 and ply:GetNW2Float("NA_GolemAtkFin", 0) > CurTime() then
            nom = t.atk[n]
        elseif vel:Length2D() > 20 then
            nom = t.walk
        else
            nom = t.idle
        end
    end

    local id = nom and ply:LookupSequence(nom)
    if id and id >= 0 then return ACT_INVALID, id end
end)

-- Vitesse de lecture : la marche suit la vitesse réelle, l'attaque repart de zéro à chaque coup, la mort se joue une fois
hook.Add("UpdateAnimation", "MokutonGolem_Vitesse", function(ply, vel)
    if not ply:GetNW2Bool("NA_Golem", false) then return end
    local t = NA_GOLEM.Type(ply)

    if t.mort and ply:GetNW2Float("NA_GolemMortFin", 0) > CurTime() then
        local debut, fin = ply:GetNW2Float("NA_GolemMortDebut", 0), ply:GetNW2Float("NA_GolemMortFin", 0)
        ply:SetCycle(math.Clamp((CurTime() - debut) / math.max(fin - debut, 0.1), 0, 0.999))   -- jouée une seule fois, sans boucle
        ply:SetPlaybackRate(0)
        return true
    end

    if ply:GetNW2Float("NA_GolemAtkFin", 0) > CurTime() then
        local debut = ply:GetNW2Float("NA_GolemAtkDebut", 0)
        if ply.NA_GolemAtkVu ~= debut then
            ply.NA_GolemAtkVu = debut
            ply:SetCycle(0)
        end
        ply:SetPlaybackRate(t.vitesse_anim)
    else
        local id = ply:GetSequence()
        local vitesse = vel:Length2D()
        local base = ply:GetSequenceGroundSpeed(id)
        if vitesse > 20 and base and base > 1 then
            ply:SetPlaybackRate(math.Clamp(vitesse / base, 0.3, 2.5))
        else
            ply:SetPlaybackRate(t.vitesse_anim)   -- repos
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
            local t = NA_GOLEM.Type(ply)
            ply:SetHull(t.hull_mins, t.hull_maxs)
            ply:SetHullDuck(t.hull_mins, t.hull_maxs)
            ply:SetViewOffset(Vector(0, 0, t.vue))
            ply:SetViewOffsetDucked(Vector(0, 0, t.vue))
        elseif not golem and ply.NA_GolemHull then
            ply.NA_GolemHull = nil
            ply:ResetHull()
            ply:SetViewOffset(Vector(0, 0, 64))
            ply:SetViewOffsetDucked(Vector(0, 0, 28))
        end
    end
end)
