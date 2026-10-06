--========================================================
-- Raiton : Poing de foudre (SERVEUR)
--
-- Même principe que le Coup de pied céleste Senju, mais avec le poing :
-- 1. Le lanceur fait un petit bond, puis fonce vers le BAS dans la direction où il regarde (animation ANIM,
--    le poing droit chargé de foudre : particule solve_raiton_punch_hand, affichée par cl_raiton_poing.lua).
--    Le plongeon lui-même est tenu par sh_raiton_poing.lua.
-- 2. À l'atterrissage : onde de foudre (solve_raiton_chakramode_wave), dégâts, projection et étourdissement
--    (STUN secondes) de ceux qui sont touchés.
-- Le serveur décide de tout : chakra, recharge, impact.
--
-- Réseau : "raiton_poing_cast" (client -> serveur), "raiton_poing_impact" (serveur -> clients : onde),
--         "raiton_poing_sol" (serveur -> clients : poussière aux pieds au décollage, comme les Roquettes Shoton)
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_poing_cast")
util.AddNetworkString("raiton_poing_impact")
util.AddNetworkString("raiton_poing_sol")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS         = 50
local RAYON          = 280    -- zone touchée autour de l'impact
local PROJECTION     = 450    -- vitesse horizontale donnée aux ennemis
local PROJ_HAUT      = 280    -- vitesse verticale donnée aux ennemis
local STUN           = 0.5    -- secondes d'étourdissement des ennemis touchés
local DELAI_STUN     = 0.2    -- le stun commence après ce délai : il annule la vitesse, donc sans délai la projection serait perdue
local SAUT           = 600    -- petit bond avant de plonger (de la hauteur pour le plongeon)
local VITESSE        = 1700   -- vitesse du plongeon
local DELAI_PLONGEE  = 0.45   -- secondes de bond avant de foncer
local PLONGEE_MAX    = 2      -- secondes max de plongeon (sécurité si on ne touche jamais le sol)
local PENTE_MINI     = -0.5   -- le plongeon descend au moins de cette pente, même en regardant vers le haut

local CHAKRA_COUT    = 40
local CHAKRA_MAX     = NA_CHAKRA_MAX or 100
local RECHARGE       = 16

local ANIM           = "m_attack_benihien_blastpunch"   -- poing vers le bas
--========================================================

local ID = "raiton_poing"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

resource.AddFile("particles/solve_raiton.pcf")
resource.AddFile("particles/solve_impact_autoattack.pcf")
game.AddParticles("particles/solve_raiton.pcf")
PrecacheParticleSystem("solve_raiton_punch_hand")
PrecacheParticleSystem("solve_raiton_chakramode_wave")

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { plonge, debutPlonge, vitesse } tant que la technique est en cours

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Terminer(ply)
    actifs[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Float("NA_RaitonPoingFin", 0)   -- fin du plongeon ET de la particule de la main (client)
    ply:SetNW2Vector("NA_RaitonPoingDir", vector_origin)
    ply:SetNW2Bool("NA_Canalise", false)
end

local function Atterrir(ply)
    local vitesse = ply:GetVelocity()
    Terminer(ply)
    if not ply:Alive() then return end

    ply:SetVelocity(-vitesse)   -- le plongeon s'arrête net

    -- point d'impact : le sol sous le lanceur
    local tr = util.TraceLine({
        start = ply:GetPos() + Vector(0, 0, 40), endpos = ply:GetPos() - Vector(0, 0, 400),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local pos = tr.Hit and tr.HitPos or ply:GetPos()

    net.Start("raiton_poing_impact")
        net.WriteVector(pos)
    net.Broadcast()
    sound.Play("naruto_sound/jutsu/raiton/raiton3.wav", pos, 90, 80, 1)

    local rayon, degats = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS)
    local proj, haut = Niv(ply, "projection", PROJECTION), Niv(ply, "proj_haut", PROJ_HAUT)
    local stun = Niv(ply, "stun", STUN)

    for _, ent in ipairs(ents.FindInSphere(pos, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        -- projeté en s'éloignant du point d'impact (NA_Propulser : sv_senju_frappe.lua, gère les nextbots)
        local dir = ent:WorldSpaceCenter() - pos
        dir.z = 0
        if dir:LengthSqr() < 1 then dir = ply:GetForward() end
        local v = dir:GetNormalized() * proj + Vector(0, 0, haut)
        -- aucune projection de la cible (pas de transfert de force)

        -- étourdi un instant après la projection : il reste suspendu STUN secondes (sv_etourdissement.lua)
        if stun > 0 and NA_Etourdir then
            timer.Simple(DELAI_STUN, function()
                if EstCible(ent, ply) then NA_Etourdir(ent, stun) end
            end)
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(pos, rayon, 2, Color(120, 180, 255, 20), true)
    end
end

local function Plonger(ply)
    local a = actifs[ply]
    if not a or not IsValid(ply) or not ply:Alive() then return end

    local dir = ply:EyeAngles():Forward()
    dir.z = math.min(dir.z, PENTE_MINI)   -- toujours vers le bas
    dir:Normalize()

    local vitesse = Niv(ply, "vitesse", VITESSE)
    ply:SetNW2Vector("NA_RaitonPoingDir", dir * vitesse)
    ply:SetNW2Float("NA_RaitonPoingFin", CurTime() + PLONGEE_MAX)
    a.plonge = true
    a.debutPlonge = CurTime()
    a.vitesse = vitesse
end

net.Receive("raiton_poing_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end   -- recharge visible dans la barre

    actifs[ply] = { plonge = false }
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)

    NA_AnimJutsu(ply, ANIM)   -- animation + pas de coups pendant (_na_mudra.lua)

    -- anneau de poussière aux pieds au décollage : les mêmes particules que le saut des Roquettes Shoton
    net.Start("raiton_poing_sol")
        net.WriteEntity(ply)
    net.Broadcast()

    -- petit bond (de la hauteur pour plonger) ; la particule de la main est affichée dès maintenant (client : NW2Float "NA_RaitonPoingFin")
    local vel = ply:GetVelocity()
    ply:SetVelocity(Vector(-vel.x, -vel.y, Niv(ply, "saut", SAUT) - vel.z))
    ply:SetNW2Float("NA_RaitonPoingFin", CurTime() + Niv(ply, "delai_plongee", DELAI_PLONGEE) + PLONGEE_MAX)

    timer.Simple(Niv(ply, "delai_plongee", DELAI_PLONGEE), function() Plonger(ply) end)
end)

-- Suivi du plongeon : atterrissage, choc contre un mur, temps écoulé
hook.Add("Think", "RaitonPoing_Suivi", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() then
            Terminer(ply)
        elseif a.plonge then
            -- pas de coups pendant le plongeon : renouvelé seulement quand il s'épuise (évite un envoi réseau à chaque tick)
            if ply:GetNW2Float("NA_MudraFin", 0) - CurTime() < 0.2 then NA_Mudra(ply, 0.5) end

            local t = CurTime() - a.debutPlonge
            local bloque = t > 0.15 and ply:GetVelocity():Length() < a.vitesse * 0.3   -- arrêté par un mur
            if (t > 0.1 and ply:IsOnGround()) or bloque or t > PLONGEE_MAX then
                Atterrir(ply)
            end
        end
    end
end)

-- pas de dégâts de chute pendant la technique
hook.Add("GetFallDamage", "RaitonPoing_SansChute", function(ply)
    if actifs[ply] then return 0 end
end)

hook.Add("PlayerDeath", "RaitonPoing_Mort", function(ply) Terminer(ply) end)
hook.Add("PlayerSpawn", "RaitonPoing_Spawn", function(ply) Terminer(ply) end)
hook.Add("PlayerDisconnected", "RaitonPoing_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
