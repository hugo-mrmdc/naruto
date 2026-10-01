--========================================================
-- Inkuton : Singes d'encre (SERVEUR)
-- On vise un ennemi (comme le genjutsu Uchiha). Le lanceur déroule son parchemin, puis trois singes
-- partent vers la cible et la rattrapent à coup sûr, même si elle bouge (entité inkuton_singe).
-- Accrochés à elle, pendant DUREE secondes : elle est ralentie, subit des dégâts sur la durée et ne peut
-- plus lancer de jutsu (NW2Bool "NA_Singes", lu par _na_registre.lua). Elle reste ensuite MARQUEE
-- MARQUE secondes : le lanceur la voit à travers les murs (cl_inkuton_singes.lua).
--
-- Réseau : "inkuton_singes_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains" (sv_inkuton_chiens.lua)
--========================================================

util.AddNetworkString("inkuton_singes_cast")
util.AddNetworkString("inkuton_singes_refus")   -- serveur -> client : lancement refusé

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local PORTEE       = 1000   -- distance maximale de la cible
local TAILLE_VISEE = 25     -- demi-taille de la hitbox de visée
local DEGATS_TICK  = 10     -- dégâts à chaque tick
local INTERVALLE   = 1      -- secondes entre deux ticks
local DUREE        = 5      -- secondes pendant lesquelles les singes restent accrochés
local MARQUE       = 8      -- secondes de marquage APRÈS la fin de l'effet
local RALENTI      = 0.4    -- vitesse de déplacement de la cible (1 = normal)
local VITESSE      = 420
local NOMBRE       = 3      -- nombre de singes
local DECALAGE     = 0.3    -- secondes entre le départ de deux singes
local ECART        = 40
local DEVANT       = 60
local RECHARGE     = 14
local CHAKRA_COUT  = 30
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0
local DELAI_SINGES = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "inkuton_singes", stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/inkuton/inkutonmonkey." .. ext)
end
for _, f in ipairs(file.Find("materials/models/solve/billy/inkutonmonkey/*", "GAME")) do
    resource.AddFile("materials/models/solve/billy/inkutonmonkey/" .. f)
end
game.AddParticles("particles/solve_inkuton_geams.pcf")

local pret    = {}   -- joueur -> moment où la technique est de nouveau disponible
local effets  = {}   -- cible -> { fin, marque, lanceur, singes, prochain, degats, intervalle }

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- id : technique dont on lit portée / hitbox (les serpents réutilisent cette visée : NA_InkutonCible)
local function TrouverCible(ply, id)
    id = id or "inkuton_singes"
    local oeil = ply:EyePos()
    local t = Vector(1, 1, 1) * NA_Stat(ply, id, "hitbox", TAILLE_VISEE)
    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * NA_Stat(ply, id, "portee", PORTEE),
        mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, distMin = nil, math.huge
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < distMin then cible, distMin = ent, d end
        end
    end
    return cible
end
NA_InkutonCible = TrouverCible
NA_InkutonEstCible = EstCible

-- Ennemi le plus proche de "pos" dans "rayon", pas derrière un mur (singes et serpents sans cible visée)
function NA_InkutonChercher(pos, lanceur, rayon)
    local oeil = pos + Vector(0, 0, 20)
    local meilleur, dMin = nil, rayon ^ 2
    for _, ent in ipairs(ents.FindInSphere(pos, rayon)) do
        if EstCible(ent, lanceur) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < dMin and not util.TraceLine({ start = oeil, endpos = ent:WorldSpaceCenter(), mask = MASK_SOLID_BRUSHONLY }).Hit then
                meilleur, dMin = ent, d
            end
        end
    end
    return meilleur
end

--------------------------------------------------------
-- Effet sur la cible
--------------------------------------------------------
local function Retirer(cible, e)
    for _, s in ipairs(e.singes) do
        if IsValid(s) then s:Remove() end
    end
    e.singes = {}
    if IsValid(cible) then
        cible:SetNW2Bool("NA_Singes", false)
        if cible:IsPlayer() then cible:SetLaggedMovementValue(1) end
    end
end

-- appelé par l'entité inkuton_singe quand elle atteint la cible
function NA_SingeAccrocher(singe, cible)
    local lanceur = singe:GetOwner()
    local e = effets[cible]
    if not e then
        local duree = IsValid(lanceur) and Niv(lanceur, "duree", DUREE) or DUREE
        e = {
            lanceur = lanceur, singes = {},
            fin = CurTime() + duree,
            prochain = CurTime() + INTERVALLE,
            degats = IsValid(lanceur) and Niv(lanceur, "degats", DEGATS_TICK) or DEGATS_TICK,
            intervalle = IsValid(lanceur) and Niv(lanceur, "intervalle", INTERVALLE) or INTERVALLE,
            marque = IsValid(lanceur) and Niv(lanceur, "marque", MARQUE) or MARQUE,
        }
        e.prochain = CurTime() + e.intervalle
        effets[cible] = e

        cible:SetNW2Bool("NA_Singes", true)
        if cible:IsPlayer() then
            cible:SetLaggedMovementValue(IsValid(lanceur) and Niv(lanceur, "ralenti", RALENTI) or RALENTI)
        end
        cible:SetNW2Entity("NA_SingeMarqueDe", lanceur)
    end
    cible:SetNW2Float("NA_SingeMarqueFin", e.fin + e.marque)

    -- le singe grimpe sur le corps de la cible, à un endroit au hasard
    singe:SetParent(cible)
    singe:SetLocalPos(singe.Offset or vector_origin)   -- l'endroit visé pendant la course
    singe:SetLocalAngles(singe.AngAccroche or angle_zero)   -- tourné vers le corps de la cible
    e.singes[#e.singes + 1] = singe
end

hook.Add("Think", "InkutonSinges_Effet", function()
    local now = CurTime()
    for cible, e in pairs(effets) do
        if not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) then
            if IsValid(cible) then cible:SetNW2Float("NA_SingeMarqueFin", 0) end
            Retirer(cible, e)
            effets[cible] = nil
        elseif now >= e.fin then
            Retirer(cible, e)
            effets[cible] = nil   -- la marque (NA_SingeMarqueFin) continue seule
        elseif now >= e.prochain then
            e.prochain = now + e.intervalle
            local dmg = DamageInfo()
            dmg:SetDamage(e.degats)
            dmg:SetAttacker(IsValid(e.lanceur) and e.lanceur or game.GetWorld())
            dmg:SetInflictor(IsValid(e.lanceur) and e.lanceur or game.GetWorld())
            dmg:SetDamageType(DMG_GENERIC)
            cible:TakeDamageInfo(dmg)
        end
    end
end)

--------------------------------------------------------
-- Lancement
--------------------------------------------------------
local function Lancer(ply, cible)
    if not IsValid(ply) or not ply:Alive() or not IsValid(cible) then return end

    local yaw = ply:EyeAngles().y
    local avant = Angle(0, yaw, 0):Forward()
    local droite = Angle(0, yaw, 0):Right()
    local nombre = Niv(ply, "nombre", NOMBRE)
    local ecart = Niv(ply, "ecart", ECART)
    local base = ply:GetPos() + avant * Niv(ply, "devant", DEVANT)

    -- ils sautent un par un, à DECALAGE secondes d'intervalle
    local decalage = Niv(ply, "decalage", DECALAGE)
    for i = 1, nombre do
        timer.Simple((i - 1) * decalage, function()
            if not IsValid(ply) or not ply:Alive() or not IsValid(cible) then return end
            local ent = ents.Create("inkuton_singe")
            if not IsValid(ent) then return end
            local decal = (i - (nombre + 1) / 2) * ecart   -- répartis de part et d'autre du lanceur
            ent:SetPos(base + droite * decal)
            ent:SetAngles(Angle(0, yaw, 0))
            ent:SetOwner(ply)
            ent.Index, ent.Total = i, nombre
            ent.Cible   = cible
            ent.Vitesse = Niv(ply, "vitesse", VITESSE)
            ent:Spawn()
        end)
    end
end

net.Receive("inkuton_singes_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "inkuton_singes") then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    -- refus : le client a déjà lancé sa recharge locale en appuyant, on la lui fait annuler
    local function Refuser(message)
        if message then ply:PrintMessage(HUD_PRINTCENTER, message) end
        net.Start("inkuton_singes_refus")
        net.Send(ply)
    end

    local cible = TrouverCible(ply)
    if not cible then Refuser() return end   -- sans message   -- personne dans le viseur : rien n'est dépensé

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            Refuser("Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "inkuton_singes", recharge) end

    NA_AnimJutsu(ply, ANIM_LANCER)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    -- parchemin + particule de main (même rendu que les chiens)
    local id = ply:LookupSequence(ANIM_LANCER)
    local duree = (id and id >= 0) and ply:SequenceDuration(id) or 1.2
    net.Start("inkuton_chiens_mains")
        net.WriteEntity(ply)
        net.WriteFloat(duree)
    net.Broadcast()

    timer.Simple(math.max(mudra, Niv(ply, "delai_singes", DELAI_SINGES)), function() Lancer(ply, cible) end)
end)

hook.Add("PlayerDisconnected", "InkutonSinges_Nettoyage", function(ply) pret[ply] = nil end)
