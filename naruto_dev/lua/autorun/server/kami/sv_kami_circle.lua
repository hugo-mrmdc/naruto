--========================================================
-- Kami Circle (SERVEUR)
-- Zone de dégâts autour du lanceur : blesse tout le monde SAUF lui.
-- La zone suit le joueur pendant toute sa durée.
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_circle_cast")
util.AddNetworkString("kami_circle_fx")
util.AddNetworkString("kami_circle_stop")

-- Les particules doivent être déclarées ET précachées côté SERVEUR aussi,
-- sinon l'effet ne part pas chez les clients.
local PCF_PATH = "particles/atg_faris.pcf"
local FX_NAME  = "[2]_paper_tornado"

game.AddParticles(PCF_PATH)
PrecacheParticleSystem(FX_NAME)

-- Téléchargement pour les joueurs qui n'ont pas le contenu.
-- Les textures de ce .pcf viennent de l'addon workshop « ATG 1 ».
resource.AddFile(PCF_PATH)

--[[
    Réglages : modifiables en jeu dans la console serveur, sans redémarrer.
    Les valeurs sont enregistrées (FCVAR_ARCHIVE).

        kami_circle_damage 20     -- dégâts par tick
        kami_circle_tick 0.5      -- secondes entre deux ticks
        kami_circle_radius 220    -- rayon de la zone
        kami_circle_duration 6    -- durée totale
        kami_circle_cooldown 12   -- recharge après la fin

    Exemple : 20 dégâts toutes les 0,5 s pendant 6 s = 12 ticks, 240 dégâts au total
    pour une cible qui reste dedans.
]]
local FLAGS = { FCVAR_ARCHIVE, FCVAR_NOTIFY }

local cvDamage   = CreateConVar("kami_circle_damage", "20", FLAGS, "Kami Circle : dégâts par tick", 0)
local cvTick     = CreateConVar("kami_circle_tick", "0.5", FLAGS, "Kami Circle : secondes entre deux ticks", 0.05, 10)
local cvRadius   = CreateConVar("kami_circle_radius", "220", FLAGS, "Kami Circle : rayon de la zone", 16)
local cvDuration = CreateConVar("kami_circle_duration", "6", FLAGS, "Kami Circle : durée en secondes", 0.5)
local cvCooldown = CreateConVar("kami_circle_cooldown", "12", FLAGS, "Kami Circle : recharge en secondes", 0)

-- false : la zone reste là où elle a été lancée (elle ne suit pas le joueur et
-- ne tourne pas avec la caméra). true : elle suit le lanceur.
local FOLLOW_PLAYER   = false

-- Incantation : mudras, puis animation d'attaque, puis apparition du cercle
local DUREE_MUDRA  = 1.1                        -- durée des mudras avant l'attaque
local DELAI_CERCLE = 0.5                        -- délai entre l'attaque et le cercle

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kami_circle", stat, base) end
local ANIM_ATTAQUE = "nrp_ninjutsu_attack_d28nj3_start"   -- nom exact dans anim_extension_mod7.mdl

local nextCast = {}
local active = {}
local casting = {}   -- incantation en cours (mudras + animation)

local function StopCircle(ply)
    local timerName = active[ply]
    if not timerName then return end
    active[ply] = nil

    -- le nom est mémorisé : un joueur déjà parti n'a plus d'EntIndex fiable
    timer.Remove(timerName)

    if IsValid(ply) then
        ply:SetNWBool("KamiCircle", false)
        net.Start("kami_circle_stop")
            net.WriteEntity(ply)
        net.Broadcast()
    end
end

-- Cible valide : ni le lanceur, ni un mort, ni un objet du décor
local function IsTarget(ent, caster)
    if not IsValid(ent) or ent == caster then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function Damage(caster, center)
    local damage = cvDamage:GetFloat()
    if damage <= 0 then return end

    for _, ent in ipairs(ents.FindInSphere(center, Niv(caster, "rayon", cvRadius:GetFloat()))) do
        if not IsTarget(ent, caster) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(caster, "kami_circle", "degats", damage))
        dmg:SetAttacker(caster)
        dmg:SetInflictor(caster)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
    end
end

-- Joue une séquence sur le joueur chez tous les clients
-- (message réseau du système d'animation de l'addon : autorun/server/jutsu_anim_sv.lua)
local function PlayAnim(ply, seqName)
    if not IsValid(ply) or not seqName or seqName == "" then return end
    NA_AnimJutsu(ply, seqName)   -- animation + pas de coups pendant (_na_mudra.lua)
end

-- Apparition du cercle : appelée à la fin de l'animation
local function SpawnCircle(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local timerName = "kami_circle_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    local duration = Niv(ply, "duree", cvDuration:GetFloat())

    active[ply] = timerName
    ply:SetNWBool("KamiCircle", true)

    local origin = ply:GetPos()
    local endTime = CurTime() + duration

    -- Les particules sont jouées par les clients, attachées au lanceur
    net.Start("kami_circle_fx")
        net.WriteEntity(ply)
        net.WriteFloat(duration)
        net.WriteBool(FOLLOW_PLAYER)
        net.WriteVector(origin)
    net.Broadcast()

    -- (le son des mudras est joué au début de l'incantation, pas ici)

    -- Le minuteur tourne vite et compte lui-même les ticks : changer
    -- kami_circle_tick en pleine zone est pris en compte immédiatement.
    local nextTick = CurTime()

    timer.Create(timerName, 0.05, 0, function()
        -- le lanceur est mort ou parti : la zone s'arrête
        if not IsValid(ply) or not ply:Alive() then
            StopCircle(ply)
            return
        end

        if CurTime() >= endTime then
            StopCircle(ply)
            return
        end

        if CurTime() < nextTick then return end
        nextTick = CurTime() + math.max(Niv(ply, "intervalle", cvTick:GetFloat()), 0.05)

        Damage(ply, FOLLOW_PLAYER and ply:GetPos() or origin)
    end)
end

----------------------------------------------------------
-- Lancement : mudras -> animation d'attaque -> cercle
----------------------------------------------------------
net.Receive("kami_circle_cast", function(_, ply)
    if not NA_Debloquee(ply, "kami_circle") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if active[ply] or casting[ply] then return end
    if (nextCast[ply] or 0) > CurTime() then
        ply:ChatPrint("Kami Circle : encore " .. math.ceil(nextCast[ply] - CurTime()) .. " secondes")
        return
    end

    casting[ply] = true
    nextCast[ply] = CurTime() + Niv(ply, "duree_mudra", DUREE_MUDRA) + Niv(ply, "delai_cercle", DELAI_CERCLE) + Niv(ply, "duree", cvDuration:GetFloat()) + NA_Stat(ply, "kami_circle", "recharge", cvCooldown:GetFloat())
    if NA_CD then NA_CD.Set(ply, "kami_circle", nextCast[ply] - CurTime()) end -- recharge visible dans la barre

    ply:EmitSound("base/mudra_sound_geams.wav", 80, 100)

    if NA_Mudra then NA_Mudra(ply, Niv(ply, "duree_mudra", DUREE_MUDRA)) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    -- fin des mudras : animation d'attaque
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA), function()
        if not IsValid(ply) or not ply:Alive() then
            if IsValid(ply) then casting[ply] = nil end
            return
        end
        PlayAnim(ply, ANIM_ATTAQUE)
    end)

    -- puis le cercle se pose
    timer.Simple(Niv(ply, "duree_mudra", DUREE_MUDRA) + Niv(ply, "delai_cercle", DELAI_CERCLE), function()
        if IsValid(ply) then casting[ply] = nil end
        SpawnCircle(ply)
    end)
end)

hook.Add("PlayerDeath", "KamiCircle_StopOnDeath", function(ply)
    casting[ply] = nil
    StopCircle(ply)
end)

hook.Add("PlayerDisconnected", "KamiCircle_Cleanup", function(ply)
    StopCircle(ply)
    nextCast[ply] = nil
    casting[ply] = nil
end)
