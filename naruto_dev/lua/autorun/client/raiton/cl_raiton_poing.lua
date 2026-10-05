--========================================================
-- Raiton : Poing de foudre (CLIENT)
-- Lancement depuis la barre de techniques, puis :
--   - la particule solve_raiton_punch_hand sur le POING DROIT du lanceur tant que NW2Float "NA_RaitonPoingFin" est
--     dans le futur (posé par sv_raiton_poing.lua : bond + plongeon). Vue par tout le monde, suit la main à chaque image.
--   - l'anneau de poussière aux pieds au décollage (auraburst_sharp, comme les Roquettes Shoton) ;
--   - l'onde solve_raiton_chakramode_wave à l'impact (message "raiton_poing_impact").
--========================================================

game.AddParticles("particles/solve_raiton.pcf")
local FX_MAIN   = "solve_raiton_punch_hand"
local FX_ONDE   = "solve_raiton_chakramode_wave"
PrecacheParticleSystem(FX_MAIN)
PrecacheParticleSystem(FX_ONDE)

-- Poussière aux pieds au décollage : EXACTEMENT les particules du saut des Roquettes Shoton (cl_shoton_rockets.lua)
game.AddParticles("particles/solve_impact_autoattack.pcf")
PrecacheParticleSystem("auraburst_sharp")

NA_Cast = NA_Cast or {}
NA_Cast.raiton_poing = function()
    net.Start("raiton_poing_cast")
    net.SendToServer()
end

net.Receive("raiton_poing_sol", function()
    local ply = net.ReadEntity()
    if IsValid(ply) then CreateParticleSystem(ply, "auraburst_sharp", PATTACH_ABSORIGIN) end
end)

net.Receive("raiton_poing_impact", function()
    ParticleEffect(FX_ONDE, net.ReadVector(), angle_zero)
end)

-- Os de la main droite. Les noms d'os ne disent pas toujours quel côté est lequel : on prend les deux mains et on
-- garde comme "droite" celle qui est du côté de ply:GetRight() (vérifié une fois par modèle).
-- Sur les modèles du serveur, la main "droite" du modèle est en fait la main GAUCHE du joueur : on prend l'autre.
-- Mets false si la particule apparaît sur la mauvaise main.
local INVERSER_MAINS = true

local NOMS_D = { "ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "Bip01_R_Hand", "R Hand", "RightHand" }
local NOMS_G = { "ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "Bip01_L_Hand", "L Hand", "LeftHand" }
local cache = {}   -- modèle -> os de la main droite (ou false)

local function Chercher(ply, noms)
    for _, n in ipairs(noms) do
        local id = ply:LookupBone(n)
        if id then return id end
    end
end

-- Os de la main voulue. On repère d'abord quel os est GÉOMÉTRIQUEMENT à droite du joueur (vérifié une fois par modèle),
-- puis on renvoie celui-là, ou l'autre si INVERSER_MAINS.
local function OsMainDroite(ply)
    local modele = ply:GetModel()
    if cache[modele] ~= nil then return cache[modele] or nil end

    local d, g = Chercher(ply, NOMS_D), Chercher(ply, NOMS_G)
    if not (d and g and d ~= g) then
        local seul = d or g   -- un seul os trouvé : on n'a pas le choix
        if seul then cache[modele] = seul end
        return seul
    end

    local md, mg = ply:GetBoneMatrix(d), ply:GetBoneMatrix(g)
    if md and mg then
        local ecart = (md:GetTranslation() - mg:GetTranslation()):Dot(ply:GetRight())
        if math.abs(ecart) > 1 then
            if ecart < 0 then d, g = g, d end   -- le "droit" est en fait du côté gauche : on échange
            local choix = INVERSER_MAINS and g or d
            cache[modele] = choix
            return choix
        end
    end
    return INVERSER_MAINS and g or d   -- pas encore de verdict (os pas encore calculés) : on ne mémorise pas
end

local mains = {}   -- joueur -> { fx, suivi } ; suivi = true si la particule doit être replacée sur l'os à chaque image

local function Couper(ply)
    local m = mains[ply]
    if m and m.fx and m.fx:IsValid() then m.fx:StopEmission(false, true) end
    mains[ply] = nil
end

-- Particule sur le poing droit. Dans l'ordre :
--   1. le point d'attache "anim_attachment_RH" du modèle (la particule le suit exactement, même en plein plongeon) ;
--   2. sinon l'os de la main, replacé à chaque image (SetupBones : sans lui l'os peut être périmé ou absent en l'air,
--      et la particule se retrouve au centre du corps).
local function CreerMain(ply)
    local att = ply:LookupAttachment(INVERSER_MAINS and "anim_attachment_LH" or "anim_attachment_RH")
    if att and att > 0 then
        local fx = CreateParticleSystem(ply, FX_MAIN, PATTACH_POINT_FOLLOW, att)
        if fx then return { fx = fx, suivi = false } end
    end
    local fx = CreateParticleSystemNoEntity(FX_MAIN, ply:WorldSpaceCenter())
    return fx and { fx = fx, suivi = true } or nil
end

local function PosMain(ply)
    ply:SetupBones()
    local os = OsMainDroite(ply)
    local m = os and ply:GetBoneMatrix(os)
    return m and m:GetTranslation() or ply:WorldSpaceCenter()
end

hook.Add("Think", "RaitonPoing_Main", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Float("NA_RaitonPoingFin", 0) > now
        if actif then
            local m = mains[ply]
            if not (m and m.fx:IsValid()) then
                m = CreerMain(ply)
                mains[ply] = m
            end
            if m and m.suivi then m.fx:SetControlPoint(0, PosMain(ply)) end
        elseif mains[ply] then
            Couper(ply)
        end
    end
    -- joueurs partis : on nettoie
    for ply in pairs(mains) do
        if not IsValid(ply) then Couper(ply) end
    end
end)
