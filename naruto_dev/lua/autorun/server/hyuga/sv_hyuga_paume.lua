--========================================================
-- Hyuga : Paume du Hakke (SERVEUR)
--
-- Frappe à distance courte : un long rectangle devant le lanceur (PORTEE de
-- long, RAYON de large/haut), orienté EXACTEMENT sur le regard (pitch inclus,
-- comme la particule) : dégâts et projection vers l'arrière sur tout ennemi
-- dans la zone, avec une explosion de chakra (Hyuga_shinoz_2) sur le lanceur.
-- Pas de mudras : l'animation (m_attack_chakrafista_palm_large) EST la frappe ;
-- la frappe part DELAI_IMPACT secondes après (le temps que le bras parte).
--========================================================

if not SERVER then return end

util.AddNetworkString("hyuga_paume_cast")
util.AddNetworkString("hyuga_paume_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 32     -- dégâts de la frappe
local PORTEE       = 300    -- longueur du rectangle devant le lanceur (~portée visuelle de la particule)
local RAYON        = 50     -- demi-largeur ET demi-hauteur du rectangle (developer 1 pour le voir)
local RECUL        = 550    -- projection vers l'arrière
local SOULEVE      = 80     -- projection vers le haut

local RECHARGE     = 8      -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 12     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DELAI_IMPACT = 0.65   -- secondes entre le lancer de l'animation et la frappe
local FX_DISTANCE  = 15     -- longueur de la particule (départ -> arrivée)
local ANIM_APPEL   = "m_attack_chakrafista_palm_large"

local SON_LANCER   = "naruto_sound/jutsu/hyuga/hyuga2.wav"
local SON_IMPACT   = "naruto_sound/jutsu/hyuga/hyuga1.wav"
--========================================================

resource.AddFile("particles/ctg_hyuga_jutsus.pcf")

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "hyuga_paume", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Origine + orientation EXACTEMENT comme la particule (ply:GetShootPos() /
-- ply:GetAimVector()) : le rectangle suit le regard complet (pitch inclus),
-- pas juste l'horizontale.
local function OrigineFrappe(ply)
    return ply:GetShootPos()
end

-- Cibles dans le rectangle devant le lanceur : longueur "portee" vers l'avant,
-- largeur/hauteur "rayon" de chaque côté (repère local du regard).
local function CiblesDevant(ply, portee, rayon)
    local origine = OrigineFrappe(ply)
    local ang = ply:EyeAngles()
    local avant, droite, haut = ang:Forward(), ang:Right(), ang:Up()
    local trouvees = {}

    for _, ent in ipairs(ents.FindInSphere(origine, portee + rayon)) do
        if not EstCible(ent, ply) then continue end

        -- centre du corps de la cible (pas ses pieds) : l'origine est aux yeux du lanceur
        local delta = ent:WorldSpaceCenter() - origine
        local x, y, z = delta:Dot(avant), delta:Dot(droite), delta:Dot(haut)
        if x >= 0 and x <= portee and math.abs(y) <= rayon and math.abs(z) <= rayon then
            trouvees[#trouvees + 1] = ent
        end
    end
    return trouvees
end

local function Frapper(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local portee = Niv(ply, "portee", PORTEE)
    local rayon = Niv(ply, "rayon", RAYON)
    local recul = Niv(ply, "recul", RECUL)
    local souleve = Niv(ply, "souleve", SOULEVE)

    -- la particule part TOUJOURS sur le lanceur, touche ou pas : c'est la
    -- frappe elle-même (chakra qui jaillit de la paume), pas une confirmation
    -- de dégâts. Départ/arrivée envoyés pour orienter la particule dans le
    -- sens du regard (comme kiminari_laser_fx).
    local depart = ply:GetShootPos() + ply:GetAimVector() * 20
    local arrivee = depart + ply:GetAimVector() * FX_DISTANCE
    net.Start("hyuga_paume_fx")
        net.WriteEntity(ply)
        net.WriteVector(depart)
        net.WriteVector(arrivee)
    net.Broadcast()

    for _, ent in ipairs(CiblesDevant(ply, portee, rayon)) do

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        -- expulsé loin du lanceur, et un peu vers le haut
        local direction = ent:GetPos() - ply:GetPos()
        direction.z = 0
        if direction:LengthSqr() < 1 then direction = ply:GetAimVector() end
        local vel = direction:GetNormalized() * recul + Vector(0, 0, souleve)
        -- aucune projection de la cible (pas de transfert de force)

        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110), 0.8)
    end

    if GetConVar("developer"):GetInt() > 0 then
        local mins = Vector(0, -rayon, -rayon)
        local maxs = Vector(portee, rayon, rayon)
        debugoverlay.BoxAngles(OrigineFrappe(ply), mins, maxs, ply:EyeAngles(), 1, Color(120, 180, 255, 20))
    end
end

net.Receive("hyuga_paume_cast", function(_, ply)
    if not NA_Debloquee(ply, "hyuga_paume") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = true
    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "hyuga_paume", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant sa durée (_na_mudra.lua)
    ply:EmitSound(SON_LANCER, 70, 100)

    local delai = Niv(ply, "delai_impact", DELAI_IMPACT)
    timer.Simple(delai, function()
        enCours[ply] = nil
        Frapper(ply)
    end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "HyugaPaume_Mort", function(ply) enCours[ply] = nil end)

hook.Add("PlayerDisconnected", "HyugaPaume_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
