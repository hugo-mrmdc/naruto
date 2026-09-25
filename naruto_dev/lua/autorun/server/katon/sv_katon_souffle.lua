--========================================================
-- Souffle katon (SERVEUR)
--
-- Le joueur souffle un jet de flammes devant lui pendant quelques secondes :
-- un cône (dans la direction du regard) qui blesse et brûle tout ce qu'il touche.
-- Le serveur décide de tout : incantation, recharge, chakra, dégâts.
-- L'effet (izox_katon_dragon_souffle) est affiché par cl_katon_souffle.lua.
--========================================================

if not SERVER then return end

util.AddNetworkString("katon_souffle")        -- client -> serveur : lancer
util.AddNetworkString("katon_souffle_fx")     -- serveur -> clients : début / fin de l'effet

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE         = 3      -- durée du souffle (secondes)
local PORTEE        = 450    -- longueur du jet (unités) ; à régler sur la taille de la particule
local ANGLE         = 18     -- demi-ouverture du cône (degrés)
local DEGATS        = 5      -- dégâts par tick
local INTERVALLE    = 0.25   -- secondes entre deux ticks
local BRULURE_DUREE = 4      -- brûlure appliquée aux cibles (0 = pas de brûlure)
local BRULURE_DPS   = 4
local RECHARGE      = 8      -- secondes après la FIN du souffle avant de pouvoir relancer
local CHAKRA_COUT   = 25     -- chakra au lancement (0 = gratuit)
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA   = 0.8    -- incantation avant le souffle
local ANIM_APPEL    = "nrp_ninjutsu_defend_dragonflamebombs_start"   -- pendant les mudras
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "katon_souffle", stat, base) end

resource.AddFile("particles/1izoxsolvenr.pcf")

local casting = {}
local nextUse = {}
local actifs  = {}   -- joueur -> nom du timer du souffle en cours

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local function EnvoyerFx(ply, duree)
    net.Start("katon_souffle_fx")
        net.WriteEntity(ply)
        net.WriteFloat(duree)   -- 0 = fin
    net.Broadcast()
end

local function Arreter(ply)
    casting[ply] = nil
    if actifs[ply] then
        timer.Remove(actifs[ply])
        actifs[ply] = nil
        EnvoyerFx(ply, 0)
    end
end

local function Souffler(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local duree     = Niv(ply, "duree", DUREE)
    local portee    = Niv(ply, "portee", PORTEE)
    local degats    = Niv(ply, "degats", DEGATS)
    local intervalle = Niv(ply, "intervalle", INTERVALLE)
    local brDuree   = Niv(ply, "brulure_duree", BRULURE_DUREE)
    local brDps     = Niv(ply, "brulure_dps", BRULURE_DPS)
    local cosAngle  = math.cos(math.rad(ANGLE))
    local brule     = {}   -- cible -> fin de la brûlure qu'on lui a mise (pas de brûlure empilée à chaque tick)

    local nom = "katon_souffle_" .. ply:EntIndex()
    actifs[ply] = nom
    EnvoyerFx(ply, duree)
    ply:EmitSound("ambient/fire/mtov_flame2.wav", 80, 90)

    -- l'animation du souffle (haut du corps) est jouée par les clients : cl_katon_souffle.lua
    if NA_Mudra then NA_Mudra(ply, duree) end   -- pas de coups d'arme pendant tout le souffle

    timer.Create(nom, intervalle, math.max(1, math.floor(duree / intervalle)), function()
        if not IsValid(ply) or not ply:Alive() then
            Arreter(ply)
            return
        end

        local origine = ply:EyePos()
        local dir = ply:EyeAngles():Forward()
        local now = CurTime()

        for _, ent in ipairs(ents.FindInCone(origine, dir, portee, cosAngle)) do
            if not EstCible(ent, ply) then continue end

            -- pas à travers les murs
            local vu = util.TraceLine({ start = origine, endpos = ent:WorldSpaceCenter(), mask = MASK_SOLID_BRUSHONLY })
            if vu.Hit then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(degats)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(ply)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            -- brûlure (NA_Bruler : sv_bouledefeut.lua), remise seulement quand la précédente est finie
            if brDuree > 0 and NA_Bruler and (brule[ent] or 0) <= now then
                brule[ent] = now + brDuree
                NA_Bruler(ent, ply, brDuree, brDps)
            end
        end
    end)

    -- fin du souffle : on prévient les clients (le timer s'arrête tout seul)
    timer.Simple(duree, function()
        if IsValid(ply) and actifs[ply] == nom then
            actifs[ply] = nil
            EnvoyerFx(ply, 0)
        end
    end)
end

net.Receive("katon_souffle", function(_, ply)
    if not NA_Debloquee(ply, "katon_souffle") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if casting[ply] or actifs[ply] then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then return end
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - cout))
    end

    -- la recharge démarre après la fin du souffle
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    nextUse[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, "katon_souffle", total) end -- recharge visible dans la barre

    casting[ply] = true

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function()
        if not IsValid(ply) then return end
        casting[ply] = nil
        Souffler(ply)
    end)
end)

hook.Add("PlayerDeath", "KatonSouffle_Death", Arreter)
hook.Add("PlayerDisconnected", "KatonSouffle_Cleanup", function(ply)
    Arreter(ply)
    nextUse[ply] = nil
end)
