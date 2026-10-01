--========================================================
-- Inkuton : Dieux d'encre (SERVEUR)
-- Deux dieux (gauche et droite, entité inkuton_dieu) partent tout droit là où tu regardes et frappent
-- le premier ennemi touché.
--
-- Réseau : "inkuton_dieux_cast" (client -> serveur) ; parchemin : "inkuton_chiens_mains"
--========================================================

util.AddNetworkString("inkuton_dieux_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 80     -- par dieu qui frappe
local VITESSE      = 600
local DUREE_VIE    = 3
local ETOURDI      = 2      -- secondes d'étourdissement de la cible
local ECART        = 160    -- distance entre les deux dieux
local DEVANT       = 60
local RECHARGE     = 20
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0
local DELAI        = 0.6
local ANIM_LANCER  = "m_throw_kunai_front"
--========================================================

local ID = "inkuton_dieux"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, n in ipairs({ "loeve_ink_left", "loeve_ink_right" }) do
    for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
        resource.AddFile("models/inkuton/" .. n .. "." .. ext)
    end
end
for _, f in ipairs(file.Find("materials/models/loeve/loeve_ink/*", "GAME")) do
    resource.AddFile("materials/models/loeve/loeve_ink/" .. f)
end

local pret = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end
    local ang = Angle(0, ply:EyeAngles().y, 0)
    local base = ply:GetPos() + ang:Forward() * Niv(ply, "devant", DEVANT)
    local dieux = {}
    for _, gauche in ipairs({ true, false }) do
        local ent = ents.Create("inkuton_dieu")
        if not IsValid(ent) then return end
        ent.Gauche = gauche
        ent:SetPos(base - ang:Right() * (gauche and 1 or -1) * Niv(ply, "ecart", ECART) / 2)
        ent:SetAngles(ang)
        ent:SetOwner(ply)
        ent.Vitesse  = Niv(ply, "vitesse", VITESSE)
        ent.Degats   = Niv(ply, "degats", DEGATS)
        ent.DureeVie = Niv(ply, "duree_vie", DUREE_VIE)
        ent.Etourdi  = Niv(ply, "etourdi", ETOURDI)
        ent:Spawn()
        dieux[#dieux + 1] = ent
    end
    if #dieux == 2 then dieux[1].Frere, dieux[2].Frere = dieux[2], dieux[1] end
end

net.Receive("inkuton_dieux_cast", function(_, ply)
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

    timer.Simple(math.max(mudra, Niv(ply, "delai", DELAI)), function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "InkutonDieux_Nettoyage", function(ply) pret[ply] = nil end)
