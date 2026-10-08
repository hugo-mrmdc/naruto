--========================================================
-- Inkuton : Chiens d'encre (SERVEUR)
-- Le lanceur déroule un parchemin (scrollkhalid.mdl, main gauche) pendant son
-- animation de lancer ; trois chiens d'encre (saidog_black.mdl) partent côte à
-- côte, tout droit devant lui (entité inkuton_chien, lua/entities).
-- Réseau : "inkuton_chiens_cast" (client -> serveur), "inkuton_chiens_mains" (serveur -> clients :
-- parchemin + particule de la main droite, voir cl_inkuton_chiens.lua)
--========================================================

util.AddNetworkString("inkuton_chiens_cast")
util.AddNetworkString("inkuton_chiens_mains")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 35
local VITESSE      = 900
local DUREE_VIE    = 1.5    -- secondes avant que les chiens disparaissent s'ils ne touchent rien
local ECHELLE      = 1      -- taille du modèle ; la zone de touche suit
local ECART        = 40     -- distance (unités) entre deux chiens
local DEVANT       = 60     -- distance de départ devant le lanceur
local RECHARGE     = 8
local CHAKRA_COUT  = 25
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0
local DELAI_CHIENS = 0.6    -- délai entre le début de l'animation et le départ des chiens
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "inkuton_chiens", stat, base) end

-- téléchargement pour les joueurs qui n'ont pas le contenu
for _, nom in ipairs({ "saidog", "scrollkhalid" }) do
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
        resource.AddFile("models/inkuton/" .. nom .. "." .. ext)
    end
end
for _, dossier in ipairs({ "models/solve/billy/saidog", "models/solve/billy/mariokhalid" }) do
    for _, f in ipairs(file.Find("materials/" .. dossier .. "/*", "GAME")) do
        resource.AddFile("materials/" .. dossier .. "/" .. f)
    end
end
resource.AddFile("particles/solve_inkuton_geams.pcf")
game.AddParticles("particles/solve_inkuton_geams.pcf")
PrecacheParticleSystem("solve_inkuton_start_hand")
PrecacheParticleSystem("solve_inkuton_dog_impact")

local pret = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- direction à plat : les chiens courent au sol
    local yaw = ply:EyeAngles().y
    local avant = Angle(0, yaw, 0):Forward()
    local droite = Angle(0, yaw, 0):Right()
    local ecart = Niv(ply, "ecart", ECART)
    local base = ply:GetPos() + avant * Niv(ply, "devant", DEVANT)

    -- un au centre, un à gauche, un à droite : ils partent ensemble, en ligne droite
    for _, decal in ipairs({ 0, -ecart, ecart }) do
        local ent = ents.Create("inkuton_chien")
        if not IsValid(ent) then return end

        ent:SetPos(base + droite * decal)
        ent:SetAngles(Angle(0, yaw, 0))
        ent:SetOwner(ply)
        ent.Direction = avant
        ent.Vitesse   = Niv(ply, "vitesse", VITESSE)
        ent.Degats    = Niv(ply, "degats", DEGATS)
        ent.DureeVie  = Niv(ply, "duree_vie", DUREE_VIE)
        ent.Echelle   = Niv(ply, "echelle", ECHELLE)
        ent:Spawn()
    end
end

net.Receive("inkuton_chiens_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "inkuton_chiens") then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    local recharge = Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + recharge
    if NA_CD then NA_CD.Set(ply, "inkuton_chiens", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_LANCER)   -- animation + pas de coups pendant (_na_mudra.lua)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    -- parchemin (main gauche) + particule (main droite) pendant toute l'animation
    local id = ply:LookupSequence(ANIM_LANCER)
    local duree = (id and id >= 0) and ply:SequenceDuration(id) or 1.2
    net.Start("inkuton_chiens_mains")
        net.WriteEntity(ply)
        net.WriteFloat(duree)
    net.Broadcast()

    timer.Simple(math.max(mudra, Niv(ply, "delai_chiens", DELAI_CHIENS)), function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "InkutonChiens_Nettoyage", function(ply) pret[ply] = nil end)
