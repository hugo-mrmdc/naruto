--========================================================
-- Jinton : Cube de confinement (SERVEUR)
--
-- Vise un ennemi à portée : un cube l'enferme, il est immobilisé (stun)
-- et subit des dégâts à chaque tick, avec la particule solve_geams_01_j.
-- Le cube lui-même est l'entité jinton_cube (lua/entities/jinton_cube.lua).
--========================================================

if not SERVER then return end

util.AddNetworkString("jinton_cube_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE        = 900    -- distance maximale de la cible
local TAILLE_VISEE  = 20     -- demi-taille de la hitbox de visée (boîte lancée le long du regard)
                             -- plus grand = plus facile de viser. Visible avec : developer 1

local DUREE         = 4      -- durée du cube et du stun (secondes)
local DEGATS        = 10      -- dégâts par tick
local INTERVALLE    = 0.2    -- secondes entre deux ticks
local ECHELLE       = 1.1    -- taille du cube (1 = 72 unités de côté, la taille d'un joueur)

local RECHARGE      = 1     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT   = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX    = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA   = 0.6    -- incantation avant l'apparition du cube
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local enCours = {}   -- joueur -> true pendant l'incantation
local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Valeurs lues par le client pour afficher la hitbox en mode développeur
SetGlobal2Float("NA_JintonCubePortee", PORTEE)
SetGlobal2Float("NA_JintonCubeVisee", TAILLE_VISEE)

-- Ennemi visé : une boîte (hitbox de visée) est lancée depuis les yeux le long du
-- regard, jusqu'au premier mur (ou PORTEE). Parmi TOUT ce qu'elle traverse, on
-- prend la cible valable la plus proche : un objet quelconque devant la cible
-- (prop, entité invisible...) ne la cache plus.
local function TrouverCible(ply, portee)
    local oeil = ply:EyePos()
    local t = Vector(TAILLE_VISEE, TAILLE_VISEE, TAILLE_VISEE)

    -- la boîte s'arrête au premier mur
    local mur = util.TraceHull({
        start = oeil, endpos = oeil + ply:GetAimVector() * portee,
        mins = -t, maxs = t, mask = MASK_SOLID_BRUSHONLY,
    })
    local fin = mur.HitPos

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(ents.FindAlongRay(oeil, fin, -t, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end
    local tr = { HitPos = fin }

    -- mode développeur : la hitbox reste affichée 2 s à chaque lancement
    if GetConVar("developer"):GetInt() > 0 then
        local couleur = cible and Color(0, 255, 0, 40) or Color(255, 60, 60, 40)
        debugoverlay.SweptBox(oeil, tr.HitPos, -t, t, angle_zero, 2, couleur)
        if cible then debugoverlay.Box(cible:GetPos(), cible:OBBMins(), cible:OBBMaxs(), 2, Color(0, 255, 0, 60)) end
    end

    return cible
end

-- developer 1 : explique dans la console pourquoi un lancement est refusé
local function Diag(ply, ...)
    if GetConVar("developer"):GetInt() <= 0 then return end
    local msg = "[Cube Jinton] " .. table.concat({ ... }, " ")
    print(msg)
    ply:PrintMessage(HUD_PRINTCONSOLE, string.sub(msg, 1, 240))
end

local function Refus(ply, message)
    ply:PrintMessage(HUD_PRINTCENTER, message)
end

net.Receive("jinton_cube_cast", function(_, ply)
    if not NA_Debloquee(ply, "jinton_cube") then return end   -- technique pas encore débloquée (F6)

    if not IsValid(ply) then return end
    if not ply:Alive() then return Diag(ply, "refusé : lanceur mort") end
    if enCours[ply] then return Diag(ply, "refusé : incantation déjà en cours") end
    if (pret[ply] or 0) > CurTime() then
        return Diag(ply, "refusé : recharge, encore", string.format("%.1f s", pret[ply] - CurTime()))
    end

    local cible = TrouverCible(ply, PORTEE)
    if not cible then   -- sinon silencieux
        if GetConVar("developer"):GetInt() > 0 then
            local oeil, t = ply:EyePos(), Vector(TAILLE_VISEE, TAILLE_VISEE, TAILLE_VISEE)
            local vus = {}
            for _, e in ipairs(ents.FindAlongRay(oeil, oeil + ply:GetAimVector() * PORTEE, -t, t)) do
                -- on ne liste que les joueurs / PNJ (avec leur vie), pas les morceaux de décor
                if e ~= ply and (e:IsPlayer() or e:IsNPC() or e:IsNextBot()) then
                    vus[#vus + 1] = tostring(e) .. " PV=" .. e:Health()
                end
            end
            Diag(ply, "refusé : aucune cible dans la hitbox. Traversé :", #vus > 0 and table.concat(vus, ", ") or "rien")
        end
        return
    end
    Diag(ply, "cible :", tostring(cible))

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "jinton_cube", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "jinton_cube", "chakra", CHAKRA_COUT) then return Refus(ply, "Pas assez de chakra") end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "jinton_cube", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "jinton_cube", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "jinton_cube", NA_Stat(ply, "jinton_cube", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    -- mudras (animation vue par tout le monde)
    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        -- la cible a pu mourir ou s'éloigner pendant l'incantation
        if not EstCible(cible, ply) or cible:GetPos():Distance(ply:GetPos()) > PORTEE * 1.2 then
            return Diag(ply, "annulé : la cible est morte ou partie pendant l'incantation")
        end

        -- un seul cube à la fois par cible
        for _, cube in ipairs(ents.FindByClass("jinton_cube")) do
            if cube:GetCible() == cible then cube:Remove() end
        end

        local cube = ents.Create("jinton_cube")
        if not IsValid(cube) then return end
        cube.Duree      = DUREE
        cube.Degats     = NA_Stat(ply, "jinton_cube", "degats", DEGATS)
        cube.Intervalle = INTERVALLE
        cube.Echelle    = ECHELLE
        cube:SetOwner(ply)
        cube:SetCible(cible)
        cube:SetPos(cible:WorldSpaceCenter())
        cube:Spawn()
        Diag(ply, "cube posé sur", tostring(cible))
    end)
end)

hook.Add("PlayerDisconnected", "JintonCube_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
