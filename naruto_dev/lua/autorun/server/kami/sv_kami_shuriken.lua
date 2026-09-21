--========================================================
-- Shuriken de papier (SERVEUR)
-- Lance un shuriken de papier dans la direction du regard.
--========================================================

if not SERVER then return end

util.AddNetworkString("kami_shuriken_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================

local DEGATS       = 35     -- dégâts par shuriken
local ECHELLE      = 2.5    -- taille du modèle (1 = taille d'origine) ; la zone de touche suit
local LARGEUR      = 1.1    -- élargit l'étoile sans l'épaissir (1 = normal) ; la zone de touche suit
local HAUTEUR      = 1.5    -- allonge l'étoile en hauteur (1 = normal) ; la zone de touche suit
local VITESSE      = 2200   -- vitesse du projectile
local DUREE_VIE    = 3      -- secondes avant qu'il disparaisse s'il ne touche rien
local NOMBRE       = 1      -- shurikens par lancer (plus de 1 = éventail)
local ECART        = 6      -- écart en degrés entre les shurikens de l'éventail
local RECHARGE     = 1.5    -- secondes entre deux lancers
local CHAKRA_COUT  = 8      -- chakra par lancer (0 = gratuit)
local CHAKRA_MAX   = 100    -- doit correspondre à sv_sprint_chakra.lua
local DELAI_LANCER = 0.25   -- délai entre le début de l'animation et le départ du shuriken
local ANIM_LANCER  = "nrp_ninjutsu_trow_d73nj2_throw"   -- anim_extension_mod6.mdl

--========================================================

resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.mdl")
resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.vvd")
resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.dx90.vtx")
resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.dx80.vtx")
resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.sw.vtx")
resource.AddFile("models/clan/ame/kami/foc_arme_shuriken_papier.phy")
resource.AddFile("materials/jutsu/models/paper shuriken/paper shuriken.vmt")
resource.AddFile("materials/jutsu/models/paper shuriken/paper shuriken.vtf")

local nextUse = {}

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local start = ply:GetShootPos() + ply:GetAimVector() * 20
    local aim = ply:EyeAngles()

    for i = 1, NOMBRE do
        -- en éventail autour du regard si NOMBRE > 1
        local decal = (i - (NOMBRE + 1) / 2) * ECART
        local ang = Angle(aim.p, aim.y + decal, 0)
        local dir = ang:Forward()

        local ent = ents.Create("kami_paper_shuriken")
        if not IsValid(ent) then return end

        ent:SetPos(start)
        ent:SetAngles(Angle(0, ang.y, 0))
        ent:SetOwner(ply)
        ent.Direction = dir
        ent.Vitesse = VITESSE
        ent.Degats = NA_Stat(ply, "kami_shuriken", "degats", DEGATS)
        ent.DureeVie = DUREE_VIE
        ent.Echelle = ECHELLE
        ent.Largeur = LARGEUR
        ent.Hauteur = HAUTEUR
        ent:Spawn()
    end

    ply:EmitSound("weapons/slam/throw.wav", 70, 130)
end

net.Receive("kami_shuriken_cast", function(_, ply)
    if not NA_Debloquee(ply, "kami_shuriken") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end
    if (nextUse[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "kami_shuriken", "chakra", CHAKRA_COUT) > 0 and chakra < NA_Stat(ply, "kami_shuriken", "chakra", CHAKRA_COUT) then
        return
    end

    nextUse[ply] = CurTime() + NA_Stat(ply, "kami_shuriken", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "kami_shuriken", NA_Stat(ply, "kami_shuriken", "recharge", RECHARGE)) end -- recharge visible dans la barre
    if NA_Stat(ply, "kami_shuriken", "chakra", CHAKRA_COUT) > 0 then
        ply:SetNW2Float("NA_Chakra", math.max(0, chakra - NA_Stat(ply, "kami_shuriken", "chakra", CHAKRA_COUT)))
    end

    -- animation de lancer, vue par tout le monde
    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_LANCER)
    net.Broadcast()

    timer.Simple(DELAI_LANCER, function()
        Lancer(ply)
    end)
end)

hook.Add("PlayerDisconnected", "KamiShuriken_Cleanup", function(ply)
    nextUse[ply] = nil
end)
