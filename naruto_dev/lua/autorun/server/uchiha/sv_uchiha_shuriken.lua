--========================================================
-- Uchiha : Shuriken géant (SERVEUR)
-- Après les mudras, lance un gros shuriken enflammé dans la direction du regard
-- (entité uchiha_giant_shuriken, lua/entities). Blesse et brûle le premier touché.
-- Réseau : "uchiha_shuriken_cast" (client -> serveur)
--========================================================

util.AddNetworkString("uchiha_shuriken_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 50
local ECHELLE      = 1.5    -- taille du modèle (1 = 51 unités de large) ; la zone de touche suit
local VITESSE      = 1800
local DISTANCE_VISEE = 3000  -- si tu ne vises aucun obstacle, point visé à cette distance devant toi
local ECART        = 90     -- distance (unités) entre le shuriken du centre et ceux de gauche / droite
local DUREE_VIE    = 3      -- secondes avant qu'il disparaisse s'il ne touche rien
local RECHARGE     = 8
local CHAKRA_COUT  = 25
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.5    -- incantation avant le lancer
local ANIM_APPEL   = "nrp_ninjutsu_trow_d73nj2_throw"   -- anim_extension_mod6.mdl (comme le shuriken de papier)
local DELAI_LANCER = 0.25   -- délai entre le début de l'animation et le départ du shuriken
--========================================================

local function Niv(ply, stat, base) return NA_Stat(ply, "uchiha_shuriken", stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx90.vtx" }) do
    resource.AddFile("models/clan/konoha/uchiha/nr_tools_bigshuriken." .. ext)
end
resource.AddFile("particles/atg_reworkpvp.pcf")

local pret = {}   -- joueur -> moment où la technique est de nouveau disponible

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local oeil = ply:GetShootPos()
    local regard = ply:GetAimVector()
    local droite = regard:Angle():Right()
    local ecart = Niv(ply, "ecart", ECART)

    -- point visé : là où tu regardes (premier obstacle, sinon DISTANCE_VISEE devant toi)
    local visee = util.TraceLine({ start = oeil, endpos = oeil + regard * DISTANCE_VISEE, filter = ply, mask = MASK_SHOT }).HitPos

    -- un au centre, un à gauche, un à droite : ils partent ensemble et convergent vers le même point
    for _, decal in ipairs({ 0, -ecart, ecart }) do
        local depart = oeil + regard * 40 + droite * decal
        local dir = (visee - depart):GetNormalized()

        local ent = ents.Create("uchiha_giant_shuriken")
        if not IsValid(ent) then return end

        ent:SetPos(depart)
        ent:SetAngles(dir:Angle())
        ent:SetOwner(ply)
        ent.Direction  = dir
        ent.Vitesse    = Niv(ply, "vitesse", VITESSE)
        ent.Degats     = Niv(ply, "degats", DEGATS)
        ent.DureeVie   = Niv(ply, "duree_vie", DUREE_VIE)
        ent.Echelle    = Niv(ply, "echelle", ECHELLE)
        ent.BruleDuree = Niv(ply, "brulure_duree", 4)
        ent.BruleDps   = Niv(ply, "brulure_dps", 4)
        ent:Spawn()
    end

    ply:EmitSound("naruto_sound/jutsu/uchiha/uchiha9.wav", 70, 80)
end

net.Receive("uchiha_shuriken_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "uchiha_shuriken") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "uchiha_shuriken", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL)   -- animation + pas de coups pendant (_na_mudra.lua)
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(math.max(mudra, Niv(ply, "delai_lancer", DELAI_LANCER)), function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "UchihaShuriken_Nettoyage", function(ply) pret[ply] = nil end)
