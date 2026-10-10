--========================================================
-- Kenjutsu : Aller-retour (SERVEUR) - rang B
--
-- Une arme blanche en main : le lanceur repère l'ennemi le plus proche puis le
-- traverse en dash (il passe derrière lui), puis repasse de l'autre côté,
-- en jouant l'animation de balayage (M_SD_Attack_BlackHien_RoundTripSlashing)
-- à chaque passage. À chaque passage, le coup touche, blesse et étourdit
-- les ennemis autour du lanceur, avec la particule de hit.
--========================================================

if not SERVER then return end

util.AddNetworkString("kenjutsu_allerretour_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.kenjutsu_allerretour)
--========================================================
local DEGATS       = 35     -- par passage
local PORTEE       = 700    -- distance max à laquelle la cible est repérée au lancement
local RAYON        = 35     -- demi-largeur ET demi-hauteur du rectangle du passage
local ETOURDI     = 1.2    -- secondes d'étourdissement de la cible
local DELAI_IMPACT = 0.3    -- secondes d'animation avant que le coup touche (au milieu du dash)
local TOURS        = 2      -- nombre de passages
local DERRIERE     = 130    -- distance dont le lanceur dépasse la cible
local DUREE_DASH   = 0.3    -- secondes de dash par passage (vraie durée)
local VITESSE_ANIM = 2      -- vitesse de lecture de l'animation (2 = deux fois plus vite)
local ENCHAINE     = 0.8    -- part de la durée d'un tour après laquelle le suivant démarre (1 = fin exacte ; moins = sans pause)

local CHAKRA_COUT  = 25
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local RECHARGE     = 16

local ANIM         = "M_SD_Attack_BlackHien_RoundTripSlashing"
local DUREE_DEFAUT = 1.2    -- durée d'un tour si la séquence n'est pas lisible côté serveur
local FX_HIT       = "solve_ken_nrm_hit_03"   -- sur chaque cible touchée (particles/solve_kenjutsu_expert.pcf)
local SON_IMPACT   = "dimix/sond/taijutsu/hit6.wav"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "kenjutsu_allerretour", stat, base) end

game.AddParticles("particles/solve_kenjutsu_expert.pcf")
PrecacheParticleSystem(FX_HIT)

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local actifs = {}   -- joueur -> { cible } pendant les passages

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- arme blanche = toute arme Naruto sauf les poings
local function ArmeBlanche(ply)
    local arme = IsValid(ply) and ply:GetActiveWeapon()
    if not IsValid(arme) or arme:GetClass() == "naruto_poings" then return false end
    return weapons.IsBasedOn(arme:GetClass(), "naruto_arme_base")
end

-- cible = ennemi le plus proche dans la boîte lancée le long du regard (comme le cube jinton)
local function ChercherCible(ply)
    local oeil = ply:EyePos()
    local portee = Niv(ply, "portee", PORTEE)
    local fin = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * portee, mask = MASK_SOLID_BRUSHONLY }).HitPos
    local r = Niv(ply, "rayon", RAYON)

    local meilleur, dmin
    for _, ent in ipairs(NA_FindAlongRay(oeil, fin, Vector(r, r, r))) do
        if not EstCible(ent, ply) then continue end
        local d = oeil:DistToSqr(ent:WorldSpaceCenter())
        if not dmin or d < dmin then meilleur, dmin = ent, d end
    end
    return meilleur
end

-- fin de la technique : stop net, collisions et frottement rétablis
local function Terminer(ply)
    local a = actifs[ply]
    actifs[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Bool("NA_Canalise", false)
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    if a and a.orientation then ply:SetEyeAngles(a.orientation) end   -- on retrouve l'orientation du début
    ply:SetVelocity(-ply:GetVelocity())
end

local function Frapper(ply)
    if not IsValid(ply) or not ply:Alive() or not actifs[ply] then return end

    -- hitbox = rectangle le long du passage (départ -> but), demi-largeur/hauteur "rayon"
    local a = actifs[ply]
    local rayon = Niv(ply, "rayon", RAYON)
    local axe = a.but - a.depart
    local long = axe:Length()
    if long < 1 then return end
    axe = axe / long
    local droite = axe:Cross(vector_up):GetNormalized()
    local centre = ply:WorldSpaceCenter() - ply:GetPos() + a.depart   -- départ à hauteur du corps

    for _, ent in ipairs(ents.FindInSphere(centre + axe * (long / 2), long / 2 + rayon * 2)) do
        if not EstCible(ent, ply) then continue end
        local delta = ent:WorldSpaceCenter() - centre
        local x, y, z = delta:Dot(axe), delta:Dot(droite), delta.z
        if x < -rayon or x > long + rayon or math.abs(y) > rayon or math.abs(z) > rayon then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        if NA_Etourdir then NA_Etourdir(ent, Niv(ply, "etourdi", ETOURDI), nil, nil, true) end   -- sv_etourdissement.lua
        ent:EmitSound(SON_IMPACT, 75, math.random(95, 110))
        ParticleEffect(FX_HIT, ent:WorldSpaceCenter(), angle_zero)
    end
end

-- un passage : le lanceur se tourne vers la cible et la dépasse en dash (aller comme retour)
local function Tour(ply, n, duree)
    local a = actifs[ply]
    if not a or not IsValid(ply) or not ply:Alive() then Terminer(ply) return end
    if not IsValid(a.cible) or not EstCible(a.cible, ply) then Terminer(ply) return end   -- cible morte ou partie

    local vers = a.cible:GetPos() - ply:GetPos()
    vers.z = 0
    if vers:LengthSqr() < 1 then vers = ply:GetForward() end
    vers:Normalize()

    -- trajectoire en ligne droite jusqu'à la hauteur de la cible, indépendante de la vue (déplacée dans le Think plus bas)
    local depart = ply:GetPos()
    local but = a.cible:GetPos() + vers * DERRIERE
    but.z = a.cible:GetPos().z   -- se place à la hauteur de la cible (en l'air aussi)
    a.depart, a.but, a.debut = depart, but, CurTime()
    a.angle = Angle(0, vers:Angle().y, 0)   -- face au sens du passage
    ply:SetEyeAngles(a.angle)

    NA_AnimJutsu(ply, ANIM, nil, VITESSE_ANIM)   -- animation accélérée + pas de coups pendant (_na_mudra.lua)
    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT) / VITESSE_ANIM, function() Frapper(ply) end)

    if n >= Niv(ply, "tours", TOURS) then
        timer.Simple(duree, function() if actifs[ply] == a then Terminer(ply) end end)
    else
        timer.Simple(duree, function() if actifs[ply] == a then Tour(ply, n + 1, duree) end end)
    end
end

-- déplacement du lanceur : interpolation départ -> but, arrêtée par les murs ; la vue reste verrouillée sur le passage
hook.Add("Think", "Kenjutsu_AllerRetour_Dash", function()
    for ply, a in pairs(actifs) do
        if not a.but or not IsValid(ply) then continue end
        local f = a.debut and math.min((CurTime() - a.debut) / DUREE_DASH, 1) or 1
        if f >= 1 then a.debut = nil end   -- passage fini : le lanceur reste suspendu à sa place jusqu'au suivant

        local mins, maxs = ply:GetHull()
        local haut = Vector(0, 0, 4)   -- trace décollée du sol : à ras du sol elle collait et le lanceur ne bougeait pas
        local tr = util.TraceHull({
            start = ply:GetPos() + haut, endpos = LerpVector(f, a.depart, a.but) + haut,
            mins = mins, maxs = maxs, filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY,
        })
        ply:SetPos(tr.HitPos - haut)
        ply:SetLocalVelocity(vector_origin)
        ply:SetEyeAngles(a.angle)
    end
end)

net.Receive("kenjutsu_allerretour_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "kenjutsu_allerretour") then return end   -- technique pas encore débloquée (F6)
    if actifs[ply] or ply:GetNW2Bool("NA_Canalise", false) then return end
    if (pret[ply] or 0) > CurTime() then return end
    if not ArmeBlanche(ply) then return end

    local cible = ChercherCible(ply)
    if not cible then return end   -- personne à traverser : rien n'est dépensé

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then return end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "kenjutsu_allerretour", recharge) end   -- recharge visible dans la barre

    local seq = ply:LookupSequence(ANIM)
    local duree = ((seq and seq >= 0) and math.max(ply:SequenceDuration(seq), 0.3) or DUREE_DEFAUT) / VITESSE_ANIM * ENCHAINE
    duree = math.max(duree, DUREE_DASH)

    actifs[ply] = { cible = cible, orientation = ply:EyeAngles() }   -- orientation de départ, rendue à la fin
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu / dash / double saut pendant (_na_registre.lua)
    ply:SetCollisionGroup(COLLISION_GROUP_WEAPON)   -- traverse les autres joueurs pendant la technique
    Tour(ply, 1, duree)
end)

hook.Add("PlayerDeath", "Kenjutsu_AllerRetour_Mort", function(ply) if actifs[ply] then Terminer(ply) end end)
hook.Add("PlayerDisconnected", "Kenjutsu_AllerRetour_Nettoyage", function(ply)
    actifs[ply] = nil
    pret[ply] = nil
end)
