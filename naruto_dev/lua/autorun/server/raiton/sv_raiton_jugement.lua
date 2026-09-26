--========================================================
-- Raiton : Jugement de l'éclair (SERVEUR)
--
-- Sans incantation, la foudre tombe là où le lanceur regarde à ce moment (PORTEE
-- max ; au-delà, au sol sous le point de portée max) : la particule execution_eclair_pat
-- (particles/patlick_atgparticules.pcf) y apparaît, et tout ennemi dans le rayon prend des dégâts et
-- est étourdi DUREE secondes (NA_Etourdir, sv_etourdissement.lua).
-- Même principe que la Frappe noire du Kiminari. Particule affichée par cl_raiton_jugement.lua
-- (message "raiton_jugement_fx").
--========================================================

if not SERVER then return end

util.AddNetworkString("raiton_jugement_cast")
util.AddNetworkString("raiton_jugement_fx")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 30     -- dégâts de la foudre
local DUREE        = 1.5    -- secondes d'étourdissement
local RAYON        = 180    -- rayon autour du point visé (developer 1 pour le voir)
local PORTEE       = 900    -- distance max du point visé
local RECHARGE     = 14     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_FX     = 1.5    -- secondes de la particule sur le point frappé
local ANIM_APPEL   = "m_ni_def_ninjutsu_d25nj3"
local ANIM_VITESSE = 2      -- vitesse de l'animation (1 = normale, 2 = deux fois plus vite)
local DELAI_FOUDRE = 0.4   -- secondes entre le début de l'animation et la chute de la foudre

local SON_DECHARGE = "ambient/energy/zap9.wav"
local SON_TOUCHE   = "ambient/energy/spark%d.wav"   -- %d = 1 à 6
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "raiton_jugement", stat, base) end

resource.AddFile("particles/patlick_atgparticules.pcf")
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("execution_eclair_pat")

local pret   = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Point visé : ce que le regard touche dans la portée, sinon le sol sous le point de portée max
local function PointVise(ply)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut,
        endpos = debut + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply,
        mask = MASK_SOLID,
    })
    if tr.Hit then return tr.HitPos end

    local sol = util.TraceLine({
        start = tr.HitPos,
        endpos = tr.HitPos - Vector(0, 0, 4000),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.HitPos
end

local function Foudre(ply, point)
    if not IsValid(ply) or not ply:Alive() then return end
    sound.Play(SON_DECHARGE, point, 95, 90, 1)

    -- la foudre est affichée chez tout le monde
    net.Start("raiton_jugement_fx")
        net.WriteVector(point)
        net.WriteFloat(DUREE_FX)
    net.Broadcast()

    local rayon = Niv(ply, "rayon", RAYON)
    local duree = Niv(ply, "duree", DUREE)

    for _, ent in ipairs(ents.FindInSphere(point, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        if NA_Etourdir then NA_Etourdir(ent, duree) end
        ent:EmitSound(string.format(SON_TOUCHE, math.random(1, 6)), 75, math.random(95, 110), 0.8)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(point, rayon, 2, Color(120, 180, 255, 20), true)
    end
end

net.Receive("raiton_jugement_cast", function(_, ply)
    if not NA_Debloquee(ply, "raiton_jugement") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
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
    if NA_CD then NA_CD.Set(ply, "raiton_jugement", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)   -- animation + pas de coups pendant (_na_mudra.lua)
    timer.Simple(Niv(ply, "delai_foudre", DELAI_FOUDRE), function()
        if IsValid(ply) then Foudre(ply, PointVise(ply)) end   -- point visé au moment où la foudre part
    end)
end)

hook.Add("PlayerDisconnected", "RaitonJugement_Nettoyage", function(ply)
    pret[ply] = nil
end)
