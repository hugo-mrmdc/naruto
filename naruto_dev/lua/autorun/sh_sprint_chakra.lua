--========================================================
-- Course de chakra : uniquement vers l'avant (PARTAGÉ serveur + client)
--
-- En arrière ou sur le côté, la course de chakra ne s'applique pas : la vitesse
-- retombe à celle de la course normale, le chakra ne se consomme pas et
-- l'animation de course de chakra ne se joue pas.
--
-- Fait dans SetupMove, exécuté par le serveur ET en prédiction par le client :
-- le changement de vitesse est immédiat, sans à-coup.
--========================================================

if SERVER then AddCSLuaFile() end

NA_SprintChakra = NA_SprintChakra or {}
local C = NA_SprintChakra

--========================================================
-- RÉGLAGES
--========================================================
-- Angle maximal par rapport au regard pour que la course de chakra s'applique.
--   50 : avant et diagonales avant seulement
--   90 : avant, diagonales et côtés (Q / D seuls) ; l'arrière refusé
--  180 : toutes les directions, arrière compris
C.ANGLE_MAX = 180

-- En course de chakra sur le côté ou en arrière, le corps se tourne dans la
-- direction de la course et garde l'animation de la course droite (cl_sprint_chakra.lua).
C.TOURNER_CORPS  = true
C.VITESSE_ROTATION = 720    -- degrés / seconde pour que le corps s'oriente

-- Vitesse maximale hors de l'axe pendant la course de chakra
-- (doit correspondre à VITESSE_COURSE dans sv_sprint_chakra.lua)
C.VITESSE_HORS_AXE = 340

-- Sauts pendant la course de chakra : la vitesse horizontale en l'air ne peut
-- pas dépasser celle de la course (plus d'élan en plus à chaque saut, plus de
-- sauts enchaînés qui accélèrent). 1.0 = exactement la vitesse de course.
C.SAUT_VITESSE_MAX = 1.0

-- Sauter pendant la course de chakra l'arrête : le saut se fait comme en course normale.
C.SAUT_NORMAL     = 200     -- hauteur du saut (= SAUT_NORMAL de sv_sprint_chakra.lua)
C.SAUT_GARDE_ELAN = false   -- true = on garde la vitesse de chakra pendant ce saut
--========================================================

-- Direction demandée : avant / côté (valeurs positives ou négatives)
function C.VersLAvant(avant, cote)
    if avant == 0 and cote == 0 then return false end
    return math.deg(math.atan2(math.abs(cote), avant)) <= C.ANGLE_MAX
end

-- Même test à partir des touches du joueur (côté serveur)
function C.ToucheVersLAvant(ply)
    local avant = (ply:KeyDown(IN_FORWARD) and 1 or 0) - (ply:KeyDown(IN_BACK) and 1 or 0)
    local cote  = (ply:KeyDown(IN_MOVERIGHT) and 1 or 0) - (ply:KeyDown(IN_MOVELEFT) and 1 or 0)
    return C.VersLAvant(avant, cote)
end

-- Même test à partir du déplacement réel (côté client, pour les autres joueurs)
function C.MouvementVersLAvant(ply)
    local vel = ply:GetVelocity()
    vel.z = 0
    if vel:LengthSqr() < 1 then return false end
    local diff = math.abs(math.NormalizeAngle(vel:Angle().y - ply:EyeAngles().y))
    return diff <= C.ANGLE_MAX
end

hook.Add("SetupMove", "NA_SprintChakra_Direction", function(ply, mv)
    if not ply:GetNW2Bool("NA_ChakraRun", false) then return end

    -- saut : il arrête la course de chakra et part comme un saut normal
    if mv:KeyPressed(IN_JUMP) and ply:IsOnGround() then
        ply:SetJumpPower(C.SAUT_NORMAL)
        if not C.SAUT_GARDE_ELAN then
            local vel = mv:GetVelocity()
            local horiz = Vector(vel.x, vel.y, 0)
            if horiz:Length() > C.VITESSE_HORS_AXE then
                horiz = horiz:GetNormalized() * C.VITESSE_HORS_AXE
                mv:SetVelocity(Vector(horiz.x, horiz.y, vel.z))
            end
            mv:SetMaxClientSpeed(C.VITESSE_HORS_AXE)
            mv:SetMaxSpeed(C.VITESSE_HORS_AXE)
        end
        if SERVER and NA_StopChakraRun then NA_StopChakraRun(ply) end
        return
    end

    if C.VersLAvant(mv:GetForwardSpeed(), mv:GetSideSpeed()) then return end

    -- arrière ou côté : plafonné à la vitesse de course normale
    local v = math.min(C.VITESSE_HORS_AXE, mv:GetMaxClientSpeed())
    mv:SetMaxClientSpeed(v)
    mv:SetMaxSpeed(v)
end)

-- Sauts : le moteur ajoute un élan à chaque saut, proportionnel à la vitesse.
-- À la vitesse de chakra, cela donne des sauts qui partent trop loin et qui
-- accélèrent si on les enchaîne. On plafonne la vitesse horizontale en l'air.
hook.Add("FinishMove", "NA_SprintChakra_Saut", function(ply, mv)
    if not ply:GetNW2Bool("NA_ChakraRun", false) then return end
    if ply:IsOnGround() and not mv:KeyDown(IN_JUMP) then return end

    local limite = C.VersLAvant(mv:GetForwardSpeed(), mv:GetSideSpeed())
        and ply:GetRunSpeed() or C.VITESSE_HORS_AXE
    limite = limite * C.SAUT_VITESSE_MAX

    local vel = mv:GetVelocity()
    local horiz = Vector(vel.x, vel.y, 0)
    local v = horiz:Length()
    if v <= limite then return end

    horiz:Mul(limite / v)
    mv:SetVelocity(Vector(horiz.x, horiz.y, vel.z))
end)
