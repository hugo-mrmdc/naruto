--========================================================
-- Jinton : Rayon de dissolution (SERVEUR)
--
-- Pendant DUREE secondes, le lanceur vole (même vol que les ailes de papier,
-- via NW2Bool "NA_Vol", lua/kami/sh_kami_wings_move.lua) et tire un laser de
-- sa main vers là où il vise. Tout ce que le laser traverse prend des dégâts
-- à chaque tick. Le laser est l'entité jinton_laser (lua/entities/jinton_laser.lua).
--========================================================

if not SERVER then return end

util.AddNetworkString("jinton_laser_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE         = 15     -- durée du laser et du vol (secondes)
local PORTEE        = 1500   -- longueur maximale du laser (il s'arrête sur les murs)
local EPAISSEUR     = 18     -- demi-largeur du rayon affiché
local HITBOX        = 45     -- demi-largeur de la zone qui touche (plus grand = plus facile de toucher)
                             -- visible avec developer 1
local DEGATS        = 20     -- dégâts par tick
local INTERVALLE    = 0.25   -- secondes entre deux ticks

local RECHARGE      = 30     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 40     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.6    -- incantation avant le laser
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "jinton_laser", stat, base) end

-- valeurs lues par le client (rendu du laser et hitbox en mode développeur)
SetGlobal2Float("NA_JintonLaserPortee", PORTEE)
SetGlobal2Float("NA_JintonLaserEpaisseur", EPAISSEUR)
SetGlobal2Float("NA_JintonLaserHitbox", HITBOX)

local enCours = {}
local pret    = {}

function NA_JintonLaserFin(ply)
    if not IsValid(ply) then return end
    if IsValid(ply.NA_LaserJinton) then ply.NA_LaserJinton:Remove() end
    ply.NA_LaserJinton = nil

    -- fin du vol : on coupe l'élan, le joueur retombe sur place
    if ply:GetNW2Bool("NA_Vol", false) and ply:Alive() then
        ply:SetVelocity(-ply:GetVelocity())
    end
    ply:SetNW2Bool("NA_Vol", false)
    timer.Remove("jinton_laser_" .. ply:EntIndex())
end

local function Activer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    NA_JintonLaserFin(ply)

    local laser = ents.Create("jinton_laser")
    if not IsValid(laser) then return end
    laser.Degats     = NA_Stat(ply, "jinton_laser", "degats", DEGATS)
    laser.Hitbox     = NA_Stat(ply, "jinton_laser", "hitbox", HITBOX)   -- hitbox par niveau
    laser.Intervalle = Niv(ply, "intervalle", INTERVALLE)
    laser:SetOwner(ply)
    laser:SetPos(ply:GetPos())
    laser:Spawn()
    ply.NA_LaserJinton = laser

    ply:SetNW2Bool("NA_Vol", true)
    ply:SetVelocity(Vector(0, 0, 250))   -- petit décollage

    timer.Create("jinton_laser_" .. ply:EntIndex(), Niv(ply, "duree", DUREE), 1, function()
        NA_JintonLaserFin(ply)
    end)
end

local function Refus(ply, message)
    ply:PrintMessage(HUD_PRINTCENTER, message)
end

net.Receive("jinton_laser_cast", function(_, ply)
    if not NA_Debloquee(ply, "jinton_laser") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end
    if IsValid(ply.NA_LaserJinton) then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "jinton_laser", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "jinton_laser", "chakra", CHAKRA_COUT) then return Refus(ply, "Pas assez de chakra") end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "jinton_laser", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "jinton_laser", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "jinton_laser", NA_Stat(ply, "jinton_laser", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        enCours[ply] = nil
        Activer(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "JintonLaser_Mort", function(ply)
    enCours[ply] = nil
    NA_JintonLaserFin(ply)
end)

hook.Add("PlayerSpawn", "JintonLaser_Spawn", NA_JintonLaserFin)

hook.Add("PlayerDisconnected", "JintonLaser_Nettoyage", function(ply)
    NA_JintonLaserFin(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
