--========================================================
-- Taijutsu : Rafale aérienne (SERVEUR) - rang A
--
--   1. Coup de pied (m_attack_aerial_kunai_kick) : la cible touchée devant le
--      lanceur est envoyée en l'air.
--   2. Au sommet, la cible reste suspendue et le lanceur la rejoint.
--   3. Rafale de 5 coups en l'air (une animation par coup, voir ANIMS) : le
--      dernier (coup de pied tournant) écrase la cible au sol.
--
--   Réutilise le déplacement du rang B (NA_TaijutsuAir, sv_taijutsu_combo.lua).
--========================================================

if not SERVER then return end

util.AddNetworkString("taijutsu_rafale_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
-- (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS        = 40     -- dégâts du coup de pied et des 4 premiers coups
local DEGATS_FINAL  = 70     -- dégâts du dernier coup
local LANCER        = 1300   -- vitesse verticale donnée à la cible
local ECRASER       = 1400   -- vitesse vers le bas du dernier coup

local RECHARGE      = 22
local CHAKRA_COUT   = 40
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100

local DELAI_IMPACT  = 0.15   -- début du coup de pied -> la cible décolle
local DELAI_SOMMET  = 0.1    -- décollage -> le lanceur rejoint la cible
local INTERVALLE    = 0.22   -- durée de chaque coup de la rafale (l'animation est coupée à ce moment)
local DELAI_TOUCHE  = 0.09   -- début d'un coup de la rafale -> il touche

local ANIM_VITESSE  = 2      -- vitesse de lecture des animations du lanceur (délais ci-dessus à réduire d'autant)
local ANIM_LANCER   = "m_attack_aerial_kunai_kick"
local ANIM_DEPART_LANCER  = 0.25   -- secondes de l'animation sautées au début (élan trop lent)
local ANIM_VITESSE_LANCER = 3   -- vitesse du coup de pied de lancement (impact DELAI_IMPACT à réduire d'autant)
local ANIM_CIBLE    = "M_Beaten_SpinBlowOff"
local ANIM_CHUTE    = "m_beaten_fall_behind_loop"   -- anim de la cible pendant qu'elle est écrasée vers le sol (en boucle)
local CHUTE_MAX     = 3      -- durée max (secondes) de l'anim de chute si la cible ne touche pas le sol

local TOURS          = 2      -- nombre de fois que la série d'animations est jouée (seul le tout dernier coup écrase)

-- un coup par animation, la série est rejouée TOURS fois
local ANIMS = {
    "m_attack_aerial_cyakrakuckley_cmb02",
    "m_attack_aerial_a_bangles_cmb_02",
    "m_attack_aerial_a_bangles_cmb_05",
    "m_attack_aerial_armhammer",
    "m_attack_aerial_chakrafist_b_turnkick",
}

-- la série complète au 1er tour ; aux tours suivants la 1re animation est retirée
local SERIE = {}
for tour = 1, TOURS do
    for i, anim in ipairs(ANIMS) do
        if tour == 1 or i > 1 then SERIE[#SERIE + 1] = anim end
    end
end
--========================================================

local ID = "taijutsu_rafale"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local enCours, pret = {}, {}

-- Termine la technique : libère la cible, rend le mouvement et les jutsus
local function Fin(ply, cible)
    enCours[ply] = nil
    NA_TaijutsuAir.Liberer(ply, cible)
end

-- Lanceur et cible toujours en vie (sinon la technique s'arrête)
local function Valide(ply, cible)
    if IsValid(ply) and ply:Alive() and IsValid(cible) and not (cible:IsPlayer() and not cible:Alive()) then return true end
    Fin(ply, cible)
    return false
end

-- La cible tombe avec l'animation de chute en boucle, libérée dès qu'elle touche le sol
local function ChuteCible(cible)
    if not NA_Etourdir then return end
    NA_Etourdir(cible, CHUTE_MAX, ANIM_CHUTE, false, true)   -- stun souple : la chute n'est pas bloquée
    if NA_Projeter then NA_Projeter(cible, CHUTE_MAX) end

    local t0 = CurTime()
    local id = "TaijutsuRafale_Chute_" .. cible:EntIndex()
    timer.Create(id, 0.05, 0, function()
        if not IsValid(cible) then timer.Remove(id) return end
        local dt = CurTime() - t0
        local au_sol = cible.loco and cible.loco:IsOnGround() or cible:IsOnGround()
        if dt > CHUTE_MAX or (dt > 0.2 and au_sol) then
            timer.Remove(id)
            if NA_Liberer then NA_Liberer(cible) end
        end
    end)
end

-- Coup n de la rafale : animation, puis dégâts ; le dernier écrase la cible au sol
local function Coup(ply, cible, n)
    if not Valide(ply, cible) then return end

    local final = n == #SERIE
    NA_AnimJutsu(ply, SERIE[n], INTERVALLE, ANIM_VITESSE)

    timer.Simple(DELAI_TOUCHE, function()
        if not Valide(ply, cible) then return end
        local stat, base = "degats", DEGATS
        if final then stat, base = "degats_final", DEGATS_FINAL end
        NA_TaijutsuAir.Degats(ply, cible, Niv(ply, stat, base))
        if not final then return end

        Fin(ply, cible)
        local vel = Vector(0, 0, -Niv(ply, "ecraser", ECRASER))
        ChuteCible(cible)
        if cible.loco then cible.loco:SetVelocity(vel) else cible:SetVelocity(vel) end   -- NextBot : loco
        NA_TaijutsuAir.PoussiereSol(cible)   -- même poussière que le rang B quand la cible retouche le sol
    end)

    if not final then timer.Simple(INTERVALLE, function() Coup(ply, cible, n + 1) end) end
end

-- Étape 2 : au sommet, la cible reste suspendue et le lanceur la rejoint
local function Sommet(ply, cible)
    if not Valide(ply, cible) then return end

    local duree = #SERIE * INTERVALLE
    if NA_Etourdir then NA_Etourdir(cible, duree + 0.3, ANIM_CIBLE, true, true) end   -- stun souple, anim jouée une fois
    NA_TaijutsuAir.Rejoindre(ply, cible)
    NA_Mudra(ply, duree + 0.2)   -- pas de coups d'arme pendant la rafale
    Coup(ply, cible, 1)
end

-- Étape 1 : le coup de pied touche, la cible décolle (sans cible : technique perdue, comme le rang B)
local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return Fin(ply) end

    local A = NA_TaijutsuAir
    local cible = A.TrouverCible(ply)
    if not cible then return Fin(ply) end

    A.Degats(ply, cible, Niv(ply, "degats", DEGATS))

    local lancer = Niv(ply, "lancer", LANCER)
    local sommet = Niv(ply, "delai_sommet", DELAI_SOMMET)
    if NA_Projeter then NA_Projeter(cible) end   -- sous stun souple : emportée ; stun ferme : ne bouge pas
    if cible.loco then A.Soulever(cible, lancer, sommet) else cible:SetVelocity(Vector(0, 0, lancer)) end   -- NextBot : soulevé image par image
    NA_Mudra(ply, sommet + 0.2)

    timer.Simple(sommet, function() Sommet(ply, cible) end)
end

net.Receive("taijutsu_rafale_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end
    if not NA_TaiPoings(ply) then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if chakra < cout then
        -- (pas de message)
        return
    end
    ply:SetNW2Float("NA_Chakra", chakra - cout)

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    enCours[ply] = true
    ply:SetNW2Bool("NA_Canalise", true)   -- pas d'autre jutsu pendant la technique

    NA_AnimJutsu(ply, ANIM_LANCER, DELAI_IMPACT + 0.1, ANIM_VITESSE_LANCER, ANIM_DEPART_LANCER)
    NA_Mudra(ply, DELAI_IMPACT + 0.1)
    timer.Simple(DELAI_IMPACT, function() Lancer(ply) end)
end)

hook.Add("PlayerDeath", "TaijutsuRafale_Mort", function(ply) enCours[ply] = nil end)
hook.Add("PlayerDisconnected", "TaijutsuRafale_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
