--========================================================
-- Shoton : Roquettes (SERVEUR)
-- Après le mudra, le lanceur s'élève dans les airs, y reste en suspension et tire 3 roquettes de cristal
-- (entité shoton_rocket) là où il vise, puis redescend (pas de dégâts de chute).
--
-- Réseau : "shoton_rockets_cast" (client -> serveur), "shoton_rocket_boom" (serveur -> clients : explosion)
--========================================================

util.AddNetworkString("shoton_rockets_cast")
util.AddNetworkString("shoton_rocket_boom")
util.AddNetworkString("shoton_rockets_sol")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local NOMBRE      = 3      -- roquettes tirées
local INTERVALLE  = 0.45   -- secondes entre deux tirs
local HAUTEUR     = 450    -- hauteur de montée (unités)
local MONTEE      = 0.9    -- secondes pour monter
local DEGATS      = 60
local EXPLOSION   = 120
local VITESSE     = 1600
local DEVANT      = 130    -- distance de départ devant le lanceur
local RECHARGE    = 25
local CHAKRA_COUT = 60
local CHAKRA_MAX  = NA_CHAKRA_MAX or 100
local DUREE_MUDRA = 0.3
local ANIM_TIR    = { "m_throw_aerial_d55nj1_ple_left", "m_throw_aerial_d55nj1_ple_right" }   -- un tir sur deux, en alternance
local ANIM_APPEL  = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "shoton_rockets"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}
local noChute = {}   -- joueur -> fin de l'immunité à la chute

local function Tirer(ply, i)
    local dir = ply:GetAimVector()
    local ent = ents.Create("shoton_rocket")
    if not IsValid(ent) then return end
    local cote = (i - (Niv(ply, "nombre", NOMBRE) + 1) / 2) * 25   -- roquettes côte à côte
    ent:SetPos(ply:GetShootPos() + dir * Niv(ply, "devant", DEVANT) + ply:GetRight() * cote - Vector(0, 0, 10))
    ent:SetOwner(ply)
    ent.Direction = dir
    ent.Degats    = Niv(ply, "degats", DEGATS)
    ent.Explosion = Niv(ply, "explosion", EXPLOSION)
    ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
    ent:Spawn()
    ply:EmitSound("geams/solve_jutsu/shoton/solve_shoton_shuriken_start.wav", 75, 140, 0.8)
    NA_AnimJutsu(ply, ANIM_TIR[(i - 1) % 2 + 1], Niv(ply, "intervalle", INTERVALLE))   -- coupée avant le tir suivant
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local nom = "ShotonRockets_" .. ply:EntIndex()
    local nombre, interv = Niv(ply, "nombre", NOMBRE), Niv(ply, "intervalle", INTERVALLE)
    local montee, haut = Niv(ply, "montee", MONTEE), Niv(ply, "hauteur", HAUTEUR)
    local t0, tires = CurTime(), 0
    local duree = montee + nombre * interv

    -- montée + suspension : hook "Move" de shoton_init.lua, d'après ces NW2Float
    ply:SetNW2Float("NA_RocketsDebut", t0)
    ply:SetNW2Float("NA_RocketsMontee", montee)
    ply:SetNW2Float("NA_RocketsVitesse", haut / montee)
    ply:SetNW2Float("NA_RocketsFin", t0 + duree)
    ply:SetGroundEntity(NULL)

    timer.Create(nom, 0.03, 0, function()
        local t = CurTime() - t0
        if not IsValid(ply) or not ply:Alive() then
            timer.Remove(nom)
            if IsValid(ply) then ply:SetNW2Float("NA_RocketsFin", 0) end
            return
        end
        if t >= montee and tires < nombre and t >= montee + tires * interv then
            tires = tires + 1
            Tirer(ply, tires)
        end
        if t >= duree then
            timer.Remove(nom)
            noChute[ply] = CurTime() + 5
        end
    end)
end

net.Receive("shoton_rockets_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then
        -- (pas de message)
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_APPEL)
    net.Start("shoton_rockets_sol")   -- poussière aux pieds avant le décollage (cl_shoton_rockets.lua)
        net.WriteEntity(ply)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    -- pas de coups pendant toute la séquence (mudra + montée + tirs)
    if NA_Mudra then NA_Mudra(ply, mudra + Niv(ply, "montee", MONTEE) + Niv(ply, "nombre", NOMBRE) * Niv(ply, "intervalle", INTERVALLE)) end
    timer.Simple(mudra, function() Lancer(ply) end)
end)

hook.Add("EntityTakeDamage", "ShotonRockets_Chute", function(cible, dmg)
    if cible:IsPlayer() and dmg:IsFallDamage() and (noChute[cible] or 0) > CurTime() then return true end
end)

hook.Add("PlayerDisconnected", "ShotonRockets_Nettoyage", function(ply)
    pret[ply], noChute[ply] = nil, nil
    timer.Remove("ShotonRockets_" .. ply:EntIndex())
end)
