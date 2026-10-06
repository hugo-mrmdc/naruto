--========================================================
-- Étourdissement commun (SERVEUR)
--
--   NA_Etourdir(ent, secondes)  -> immobilise un joueur / PNJ pendant ce temps
--   NA_EstEtourdi(ent)          -> true s'il est étourdi
--
-- Joueurs : Freeze + NW2Bool "NA_Etourdi" (animation : cl_etourdi_anim.lua,
-- jutsus bloqués : _na_registre.lua). PNJ : maintenus sur place.
-- Plusieurs étourdissements se cumulent : on garde la fin la plus tardive.
--========================================================

local etourdis = {}   -- entité -> true

function NA_EstEtourdi(ent)
    return IsValid(ent) and (ent.NA_EtourdiFin or 0) > CurTime()
end

-- true si un cube Jinton tient la cible
local function CubeActif(ent)
    for _, cube in ipairs(ents.FindByClass("jinton_cube")) do
        if cube.Actif and cube:GetCible() == ent then return true end
    end
    return false
end
NA_CubeActif = CubeActif

-- Joueur : MOVETYPE_NONE = plus aucune vitesse, poussée ni gravité ne le déplace (en plus du Freeze et du SetPos).
local function Verrouiller(ply)
    local mt = ply:GetMoveType()
    if mt == MOVETYPE_WALK or mt == MOVETYPE_NONE then   -- NONE : posé par le cube Jinton, on le restaure aussi
        ply:SetMoveType(MOVETYPE_NONE)
        ply.NA_EtourdiMT = true
    end
end

local function Deverrouiller(ply)
    if ply.NA_EtourdiMT then
        ply.NA_EtourdiMT = nil
        if ply:GetMoveType() == MOVETYPE_NONE then ply:SetMoveType(MOVETYPE_WALK) end
    end
end

-- anim (facultatif) : nom de séquence propre à ce stun (sinon act_stunning en boucle).
-- uneFois (facultatif) : true -> l'anim est jouée une fois puis figée au lieu de boucler.
-- Effacées à la fin du stun. Ex : NA_Etourdir(cible, 2, "m_beaten_...", true)
-- souple (facultatif) : type du stun.
--   false / nil = stun FERME : la cible est fixée et rien ne la déplace, quoi qu'il arrive.
--   true        = stun SOUPLE : la cible est fixée, MAIS une technique qui la projette (NA_Projeter, ex :
--                 taijutsu) l'emporte quand même ; elle est refixée là où elle atterrit.
-- Si plusieurs stuns se cumulent, un stun ferme rend toute la cible ferme jusqu'à la fin.
function NA_Etourdir(ent, duree, anim, uneFois, souple)
    if not IsValid(ent) or duree <= 0 then return end
    if anim then
        ent:SetNW2String("NA_EtourdiAnim", anim)
        ent:SetNW2Bool("NA_EtourdiUneFois", uneFois and true or false)
    elseif not NA_EstEtourdi(ent) then
        -- nouveau stun sans anim propre : anim de base, on efface celle laissée par un stun précédent
        ent:SetNW2String("NA_EtourdiAnim", "")
        ent:SetNW2Bool("NA_EtourdiUneFois", false)
    end
    local deja = etourdis[ent] and NA_EstEtourdi(ent)   -- avant de poser le nouveau stun
    ent.NA_EtourdiFin = math.max(ent.NA_EtourdiFin or 0, CurTime() + duree)
    etourdis[ent] = true

    -- NA_Etourdi : posé dans tous les cas (même hors joueur), c'est lui que
    -- lisent les animations d'étourdissement (cl_etourdi_anim.lua pour les
    -- vrais joueurs, na_faux_joueur.lua pour le mannequin d'entraînement).
    ent:SetNW2Bool("NA_Etourdi", true)

    -- fixé à l'endroit où le stun le prend (joueurs comme PNJ) : il ne bouge plus du tout
    -- type du stun : un seul stun ferme suffit pour que la cible soit ferme
    if deja then
        ent.NA_EtourdiSouple = ent.NA_EtourdiSouple and souple and true or false
    else
        ent.NA_EtourdiSouple = souple and true or false
    end
    if not ent.NA_EtourdiSouple then ent.NA_EtourdiProjete = nil end   -- stun ferme : refixée tout de suite

    -- TOUS les stuns fixent la cible là où elle est
    ent.NA_EtourdiPos = ent.NA_EtourdiPos or ent:GetPos()

    if ent:IsPlayer() then
        ent:Freeze(true)
        ent:SetVelocity(-ent:GetVelocity())
        if not ent.NA_EtourdiProjete then Verrouiller(ent) end
    else
        if ent:IsNPC() then
            ent:ClearSchedule()
            ent:StopMoving()
        end
    end
end

-- Une technique (taijutsu...) qui PROJETTE une cible : si elle est sous un stun SOUPLE, elle est emportée
-- (position et vitesse libres) puis refixée là où elle atterrit (ou après 'max' secondes). Sous un stun
-- FERME ou un cube Jinton, rien ne bouge. Retourne true si la cible peut être emportée.
-- À appeler juste avant de lui donner sa vitesse.
function NA_Projeter(ent, max)
    if not IsValid(ent) or not etourdis[ent] or not ent.NA_EtourdiSouple or CubeActif(ent) then return false end
    ent.NA_EtourdiProjete = CurTime() + (max or 1.5)
    ent.NA_EtourdiProjeteDepuis = CurTime()
    if ent:IsPlayer() then
        if ent.NA_EtourdiMT and ent:GetMoveType() == MOVETYPE_NONE then ent:SetMoveType(MOVETYPE_WALK) end   -- libre le temps du vol
        ent:SetGroundEntity(NULL)
    end
    return true
end

local function Liberer(ent)
    etourdis[ent] = nil
    if not IsValid(ent) then return end
    ent.NA_EtourdiFin = nil
    ent.NA_EtourdiPos = nil
    ent.NA_EtourdiSouple = nil
    ent.NA_EtourdiProjete = nil
    -- l'anim de CE stun s'arrête dans tous les cas : si le cube Jinton tient encore la cible,
    -- elle reprend l'anim de base du stun Jinton
    ent:SetNW2String("NA_EtourdiAnim", "")
    ent:SetNW2Bool("NA_EtourdiUneFois", false)
    if CubeActif(ent) then return end   -- le cube Jinton le tient encore : il le libérera

    ent:SetNW2Bool("NA_Etourdi", false)
    if ent:IsPlayer() then
        ent:Freeze(false)
        Deverrouiller(ent)
    end
end
NA_Liberer = Liberer

hook.Add("Think", "NA_Etourdissement", function()
    local now = CurTime()
    for ent in pairs(etourdis) do
        if not IsValid(ent) then
            etourdis[ent] = nil
        elseif now >= (ent.NA_EtourdiFin or 0) then
            Liberer(ent)
        elseif ent.NA_EtourdiProjete then
            -- emportée par une technique : libre jusqu'à l'atterrissage, puis refixée à sa nouvelle place
            local au_sol = ent.loco and ent.loco:IsOnGround() or ent:IsOnGround()
            if now >= ent.NA_EtourdiProjete or (now - ent.NA_EtourdiProjeteDepuis > 0.3 and au_sol) then
                ent.NA_EtourdiProjete = nil
                if ent.NA_EtourdiPos then ent.NA_EtourdiPos = ent:GetPos() end
                if ent:IsPlayer() then ent:SetVelocity(-ent:GetVelocity()) Verrouiller(ent) end
            end
        elseif ent:IsPlayer() then
            ent:SetVelocity(-ent:GetVelocity())
            if ent.NA_EtourdiPos then ent:SetPos(ent.NA_EtourdiPos) end   -- ni poussée ni glissade
        elseif ent.NA_EtourdiPos then
            ent:SetPos(ent.NA_EtourdiPos)
            ent:SetVelocity(vector_origin)
            if ent:IsNPC() then ent:StopMoving() end
        end
    end
end)

hook.Add("PlayerDeath", "NA_Etourdissement_Mort", function(ply)
    if etourdis[ply] then Liberer(ply) end
end)
