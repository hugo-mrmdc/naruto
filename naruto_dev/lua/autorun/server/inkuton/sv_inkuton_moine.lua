--========================================================
-- Inkuton : Moine d'encre (SERVEUR)
-- Invoque un moine (entité inkuton_moine) qui reste à côté du lanceur. Il absorbe une part des PV
-- max du lanceur (bouclier) : les dégâts reçus la consomment d'abord, puis le moine disparaît.
-- Il frappe aussi les ennemis à portée.
--
-- Réseau : "inkuton_moine_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains"
--========================================================

util.AddNetworkString("inkuton_moine_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local BOUCLIER     = 30    -- % des PV max du lanceur
local DEGATS       = 20    -- par coup
local PORTEE       = 200
local DUREE        = 20
local RECHARGE     = 25
local CHAKRA_COUT  = 35
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0
local DELAI        = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local ID = "inkuton_moine"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/inkuton/inkutonmonk." .. ext)
end
for _, f in ipairs(file.Find("materials/models/solve/billy/inkutonmonk/*", "GAME")) do
    resource.AddFile("materials/models/solve/billy/inkutonmonk/" .. f)
end

util.PrecacheModel("models/inkuton/inkutonmonk.mdl")   -- chargé au démarrage, pas à la première invocation

local pret   = {}   -- joueur -> moment où la technique est de nouveau disponible
local moines = {}   -- joueur -> son moine

local function Invoquer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if IsValid(moines[ply]) then moines[ply]:Remove() end
    local ent = ents.Create("inkuton_moine")
    if not IsValid(ent) then return end
    local yaw = ply:EyeAngles().y
    ent:SetPos(ply:GetPos() + Angle(0, yaw, 0):Right() * 60)
    ent:SetAngles(Angle(0, yaw, 0))
    ent:SetOwner(ply)
    ent.Bouclier = ply:GetMaxHealth() * Niv(ply, "bouclier", BOUCLIER) / 100
    ent.Degats   = Niv(ply, "degats", DEGATS)
    ent.Portee   = Niv(ply, "portee", PORTEE)
    ent.DureeVie = Niv(ply, "duree", DUREE)
    ent:Spawn()
    moines[ply] = ent
end

-- le bouclier du moine absorbe les dégâts du lanceur
hook.Add("EntityTakeDamage", "InkutonMoine_Bouclier", function(target, dmg)
    if not target:IsPlayer() then return end
    local m = moines[target]
    if not IsValid(m) then return end
    local pris = math.min(dmg:GetDamage(), m.Bouclier)
    m.Bouclier = m.Bouclier - pris
    dmg:SubtractDamage(pris)
end)

net.Receive("inkuton_moine_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
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
    if NA_CD then NA_CD.Set(ply, ID, recharge) end

    NA_AnimJutsu(ply, ANIM_LANCER)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end

    local id = ply:LookupSequence(ANIM_LANCER)
    local duree = (id and id >= 0) and ply:SequenceDuration(id) or 1.2
    net.Start("inkuton_chiens_mains")
        net.WriteEntity(ply)
        net.WriteFloat(duree)
    net.Broadcast()

    timer.Simple(math.max(mudra, Niv(ply, "delai", DELAI)), function() Invoquer(ply) end)
end)

hook.Add("PlayerDisconnected", "InkutonMoine_Nettoyage", function(ply)
    pret[ply] = nil
    if IsValid(moines[ply]) then moines[ply]:Remove() end
    moines[ply] = nil
end)
