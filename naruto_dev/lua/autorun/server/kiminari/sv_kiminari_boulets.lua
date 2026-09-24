--========================================================
-- Kiminari : Boulets noirs (SERVEUR)
--
-- Après les mudras, le lanceur fait un bond puis flotte sur place sans pouvoir
-- se déplacer (NW2Bool "NA_Flotte", hook "Move" dans kiminari_init.lua ; "NA_Vol"
-- est mis aussi pour bloquer coups, dash et double saut) et BOULES boules noires
-- apparaissent en éventail dans son dos (particule frappe_noir_pat,
-- particles/patlick_atgparticules.pcf). Elles partent ensuite UNE PAR UNE vers
-- là où il vise au moment du tir ; à l'impact (impact_frappe_noir_pat), tout
-- ennemi dans RAYON prend des dégâts.
-- Position des boules dans le dos : NA_KiminariBoulePos (kiminari_init.lua).
--
-- Réseau : "kiminari_boulets_boules" (lanceur + nombre)  -> boules dans le dos
--          "kiminari_boulets_tir"    (lanceur + n° + départ + arrivée + durée)
--          "kiminari_boulets_fin"    (lanceur)            -> retire celles qui restent
--          -> cl_kiminari_boulets.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("kiminari_boulets_cast")
util.AddNetworkString("kiminari_boulets_boules")
util.AddNetworkString("kiminari_boulets_tir")
util.AddNetworkString("kiminari_boulets_fin")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DEGATS       = 8      -- dégâts par boule
local BOULES       = 10     -- nombre de boules dans le dos
local DELAI        = 0.6    -- secondes entre l'apparition des boules et le premier tir
local INTERVALLE   = 0.25   -- secondes entre deux boules
local VITESSE      = 2200   -- vitesse des boules (unités / seconde)
local RAYON        = 90     -- rayon de l'explosion à l'impact (developer 1 pour le voir)
local PORTEE       = 1500   -- distance max visée

local MONTEE       = 1000   -- élan du bond (hauteur ~ MONTEE / 6, freinage dans kiminari_init.lua)
local FIN_VOL      = 0.5    -- secondes de vol en plus après la dernière boule

local RECHARGE     = 22     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 30     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local DUREE_MUDRA  = 0.3    -- mudras avant l'envol
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_COUPE   = 0.4    -- l'animation de mudras est coupée après ces secondes (0 = entière)
local ANIM_VOL     = "nrp_ninjutsu_attack_aerial_d21nj3_start"   -- jouée en l'air, avant le premier tir
local ANIM_VOL_COUPE = 0    -- l'animation en l'air est coupée après ces secondes (0 = entière)

local SON_ENVOL    = "ambient/energy/zap9.wav"
local SON_CHARGE   = "ambient/energy/electric_loop.wav"
local SON_TIR      = "ambient/energy/zap%d.wav"     -- %d = 1 à 3
local SON_IMPACT   = "ambient/energy/spark%d.wav"   -- %d = 1 à 6
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "kiminari_boulets", stat, base) end

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Point visé : ce que le regard touche dans la portée, sinon le bout de la portée
local function PointVise(ply)
    local debut = ply:EyePos()
    return util.TraceLine({
        start = debut,
        endpos = debut + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply,
        mask = MASK_SHOT,
    }).HitPos
end

local function Impact(ply, point)
    sound.Play(string.format(SON_IMPACT, math.random(1, 6)), point, 80, math.random(90, 110), 1)
    if not IsValid(ply) then return end

    local rayon = Niv(ply, "rayon", RAYON)
    for _, ent in ipairs(ents.FindInSphere(point, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "kiminari_boulets", "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SHOCK)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(point, rayon, 1, Color(80, 80, 120, 30), true)
    end
end

local function Tirer(ply, i, n)
    if not IsValid(ply) or not ply:Alive() then return end

    local depart = NA_KiminariBoulePos(ply, i, n)
    local arrivee = PointVise(ply)
    -- un mur entre la boule et la cible : elle s'écrase dessus
    local tr = util.TraceLine({ start = depart, endpos = arrivee, filter = ply, mask = MASK_SHOT })
    arrivee = tr.HitPos

    local duree = depart:Distance(arrivee) / math.max(Niv(ply, "vitesse", VITESSE), 1)

    net.Start("kiminari_boulets_tir")
        net.WriteEntity(ply)
        net.WriteUInt(i, 6)
        net.WriteVector(depart)
        net.WriteVector(arrivee)
        net.WriteFloat(duree)
    net.Broadcast()

    ply:EmitSound(string.format(SON_TIR, math.random(1, 3)), 75, math.random(105, 120), 0.8)
    timer.Simple(duree, function() Impact(ply, arrivee) end)
end

-- fin du vol : on coupe l'élan, le joueur retombe sur place
local function Fin(ply)
    enCours[ply] = nil
    if not IsValid(ply) then return end
    ply:StopSound(SON_CHARGE)

    if ply:GetNW2Bool("NA_Vol", false) and ply:Alive() then
        ply:SetVelocity(-ply:GetVelocity())
    end
    ply:SetNW2Bool("NA_Vol", false)
    ply:SetNW2Bool("NA_Flotte", false)
    ply.NA_BouletsSansChute = CurTime() + 4   -- pas de dégâts de chute en retombant

    net.Start("kiminari_boulets_fin")
        net.WriteEntity(ply)
    net.Broadcast()
end

local function Envol(ply)
    if not IsValid(ply) or not ply:Alive() then
        Fin(ply)
        return
    end

    ply:SetNW2Bool("NA_Flotte", true)
    ply:SetNW2Bool("NA_Vol", true)
    ply:SetVelocity(Vector(0, 0, Niv(ply, "montee", MONTEE)) - ply:GetVelocity())
    ply:EmitSound(SON_ENVOL, 80, 100, 1)
    ply:EmitSound(SON_CHARGE, 70, 120, 0.6)
    NA_AnimJutsu(ply, ANIM_VOL, Niv(ply, "anim_vol_coupe", ANIM_VOL_COUPE))   -- animation en l'air avant de tirer

    local n = math.floor(Niv(ply, "boules", BOULES))
    local delai = Niv(ply, "delai", DELAI)
    local intervalle = Niv(ply, "intervalle", INTERVALLE)

    net.Start("kiminari_boulets_boules")
        net.WriteEntity(ply)
        net.WriteUInt(n, 6)
    net.Broadcast()

    -- une boule toutes les INTERVALLE secondes après DELAI, puis fin du vol
    local lancement = enCours[ply]
    for i = 1, n do
        timer.Simple(delai + (i - 1) * intervalle, function()
            if enCours[ply] ~= lancement or not IsValid(ply) or not ply:Alive() then return end
            Tirer(ply, i, n)
            if i == n then
                timer.Simple(Niv(ply, "fin_vol", FIN_VOL), function()
                    if enCours[ply] == lancement then Fin(ply) end
                end)
            end
        end)
    end
end

net.Receive("kiminari_boulets_cast", function(_, ply)
    if not NA_Debloquee(ply, "kiminari_boulets") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end
    if ply:GetNW2Bool("NA_Vol", false) or ply:GetNW2Bool("NA_Wings", false) then return end   -- déjà en vol

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    local cout = NA_Stat(ply, "kiminari_boulets", "chakra", CHAKRA_COUT)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    enCours[ply] = CurTime()   -- identifiant du lancement (les tirs d'un ancien lancement s'annulent)
    pret[ply] = CurTime() + NA_Stat(ply, "kiminari_boulets", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kiminari_boulets", NA_Stat(ply, "kiminari_boulets", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_APPEL, Niv(ply, "anim_coupe", ANIM_COUPE))   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function() Envol(ply) end)
end)

----------------------------------------------------------
-- Nettoyage
----------------------------------------------------------
hook.Add("PlayerDeath", "KiminariBoulets_Mort", function(ply)
    if enCours[ply] then Fin(ply) end
end)

hook.Add("GetFallDamage", "KiminariBoulets_SansChute", function(ply)
    if ply:GetNW2Bool("NA_Flotte", false) or (ply.NA_BouletsSansChute or 0) > CurTime() then return 0 end
end)

hook.Add("PlayerDisconnected", "KiminariBoulets_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
