--========================================================
-- Ailes de papier : DÉPLACEMENT EN VOL (PARTAGÉ serveur + client)
--
-- Le vol passe par le hook "Move", exécuté à la fois par le serveur et, en
-- prédiction, par ton client. Ta position est donc calculée tout de suite chez
-- toi au lieu d'arriver par à-coups depuis le serveur : la caméra ne saccade
-- plus, même en tournant pendant le vol.
--
-- Chargé par autorun/kami_init.lua (des deux côtés).
--========================================================

KamiWings = KamiWings or {}

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs du vol
--========================================================

KamiWings.VITESSE_VOL      = 700   -- vitesse horizontale (ZQSD / WASD)
KamiWings.VITESSE_MONTEE   = 500   -- Espace
KamiWings.VITESSE_DESCENTE = 500   -- Ctrl
KamiWings.INERTIE          = 8     -- plus grand = arrêt plus sec, plus petit = plus planant

-- Flottement : léger va-et-vient vertical, comme si les ailes portaient le corps
KamiWings.FLOTTE_HAUTEUR   = 6     -- amplitude en unités (0 = pas de flottement)
KamiWings.FLOTTE_PERIODE   = 2.5   -- secondes pour un aller-retour complet

-- Le corps pivote en douceur vers la direction de la caméra (degrés par seconde
-- environ multipliés par cette valeur). Plus grand = il suit plus vite.
KamiWings.ROTATION_CORPS   = 20

--========================================================

-- En vol : ailes de papier, ou n'importe quelle technique qui met NW2Bool "NA_Vol"
-- (ex. rayon de dissolution Jinton)
local function EnVol(ply)
    return IsValid(ply) and ply:Alive() and (ply:GetNW2Bool("NA_Wings", false) or ply:GetNW2Bool("NA_Vol", false))
        and not ply:GetNW2Bool("NA_Flotte", false)   -- Boulets noirs Kiminari : flotte sur place (kiminari_init.lua)
end
KamiWings.EnVol = EnVol

hook.Add("Move", "KamiWings_Move", function(ply, mv)
    if not EnVol(ply) then return end

    local dt = FrameTime()
    if dt <= 0 then return true end

    -- direction à plat : la caméra donne le cap, pas la montée
    local ang = Angle(0, mv:GetMoveAngles().y, 0)
    local voulu = Vector(0, 0, 0)

    if mv:KeyDown(IN_FORWARD) then voulu:Add(ang:Forward()) end
    if mv:KeyDown(IN_BACK) then voulu:Sub(ang:Forward()) end
    if mv:KeyDown(IN_MOVERIGHT) then voulu:Add(ang:Right()) end
    if mv:KeyDown(IN_MOVELEFT) then voulu:Sub(ang:Right()) end

    if voulu:LengthSqr() > 0 then
        voulu:Normalize()
        voulu:Mul(KamiWings.VITESSE_VOL)
    end

    if mv:KeyDown(IN_JUMP) then voulu.z = voulu.z + KamiWings.VITESSE_MONTEE end
    if mv:KeyDown(IN_DUCK) then voulu.z = voulu.z - KamiWings.VITESSE_DESCENTE end

    -- flottement : vitesse = dérivée du sinus, donc la position oscille de FLOTTE_HAUTEUR
    -- (ailes seulement ; sans effet quand on monte / descend volontairement)
    if ply:GetNW2Bool("NA_Wings", false) and not mv:KeyDown(IN_JUMP) and not mv:KeyDown(IN_DUCK) then
        local w = 2 * math.pi / KamiWings.FLOTTE_PERIODE
        voulu.z = voulu.z + math.cos(CurTime() * w) * w * KamiWings.FLOTTE_HAUTEUR
    end

    -- accélération douce vers la vitesse voulue (la vitesse est portée par le
    -- moteur, donc prédite elle aussi)
    local vel = LerpVector(math.Clamp(KamiWings.INERTIE * dt, 0, 1), mv:GetVelocity(), voulu)

    local to = mv:GetOrigin()
    local reste = dt

    -- on s'arrête sur les murs/sol au lieu de les traverser, mais on GLISSE dans la
    -- même frame (sinon posé au sol, la descente bloque tout le déplacement horizontal)
    for _ = 1, 3 do
        local tr = util.TraceHull({
            start = to,
            endpos = to + vel * reste,
            mins = ply:OBBMins(),
            maxs = ply:OBBMaxs(),
            filter = ply,
            mask = MASK_PLAYERSOLID,
        })

        if tr.StartSolid then
            -- coincé dans quelque chose : on ne bouge pas plutôt que de s'enfoncer
            mv:SetVelocity(Vector(0, 0, 0))
            return true
        end

        to = tr.HitPos
        if not tr.Hit then break end

        reste = reste * (1 - tr.Fraction)
        vel = vel - tr.HitNormal * vel:Dot(tr.HitNormal)
    end

    mv:SetVelocity(vel)
    mv:SetOrigin(to)

    -- true : le moteur ne rajoute pas sa propre physique (gravité, sol...)
    return true
end)

-- Pas de dégâts de chute tant qu'on vole
hook.Add("GetFallDamage", "KamiWings_NoFall", function(ply)
    if EnVol(ply) then return 0 end
end)

----------------------------------------------------------
-- CLIENT : le corps suit la caméra en douceur
----------------------------------------------------------
if CLIENT then
    -- Le cap est calculé UNE fois par image (PrePlayerDraw peut être appelé plusieurs fois
    -- par image : ombres, reflets... la rotation allait alors trop vite / par à-coups).
    hook.Add("PreRender", "KamiWings_BodyYaw", function()
        for _, ply in ipairs(player.GetAll()) do
            if not EnVol(ply) then
                ply.KamiWingsYaw = nil
                continue
            end

            local cible = ply:EyeAngles().y
            local actuel = ply.KamiWingsYaw or cible

            -- rotation progressive par le chemin le plus court
            local diff = math.NormalizeAngle(cible - actuel)
            ply.KamiWingsYaw = actuel + diff * math.Clamp(KamiWings.ROTATION_CORPS * FrameTime(), 0, 1)
        end
    end)

    -- Appliqué au joueur ET avant de lire l'os des ailes (cl_kami_wings.lua), quel que soit
    -- l'ordre de dessin : sinon les ailes lisent le squelette de l'image précédente et traînent.
    function KamiWings.AppliquerCap(ply)
        if not ply.KamiWingsYaw then return end
        ply:SetRenderAngles(Angle(0, ply.KamiWingsYaw, 0))
        ply:InvalidateBoneCache()   -- sinon les ailes gardent l'ancienne orientation
    end

    hook.Add("PrePlayerDraw", "KamiWings_BodyYaw", function(ply)
        if EnVol(ply) then KamiWings.AppliquerCap(ply) end
    end)
end
