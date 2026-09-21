--========================================================
-- Fuma : Shuriken Céleste (SERVEUR)
--
-- Un shuriken géant apparaît haut dans le ciel au-dessus du point visé et tombe
-- dessus. À l'impact au sol : grosse fumée (big_smoke_base, particles/bigfumee.pcf),
-- dégâts de zone et projection. Le shuriken est l'entité fuma_shuriken_ciel.
--========================================================

if not SERVER then return end

util.AddNetworkString("fuma_ciel_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local PORTEE       = 1000   -- distance maximale du point visé
local HAUTEUR      = 2200   -- hauteur d'apparition au-dessus du point visé
local VITESSE      = 2200   -- vitesse de chute (unités / seconde)
local ECHELLE      = 6      -- taille du shuriken (1 = 107 unités de large)

local DEGATS       = 70     -- dégâts au centre de l'impact
local RAYON         = 260   -- rayon de la zone touchée (dégâts réduits avec la distance)
local POUSSEE      = 450    -- projection des joueurs touchés

local RECHARGE     = 28     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.6    -- incantation avant l'apparition du shuriken
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

SetGlobal2Float("NA_FumaCielPortee", PORTEE)
SetGlobal2Float("NA_FumaCielRayon", RAYON)

local enCours = {}
local pret    = {}

-- Point visé, ramené au sol
local function PointVise(ply)
    local debut = ply:EyePos()
    local tr = util.TraceLine({
        start = debut, endpos = debut + ply:GetAimVector() * PORTEE,
        filter = ply, mask = MASK_SOLID,
    })

    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 16),
        endpos = tr.HitPos - Vector(0, 0, 4000),
        mask = MASK_SOLID_BRUSHONLY,
    })
    return sol.Hit and sol.HitPos or tr.HitPos
end

net.Receive("fuma_ciel_cast", function(_, ply)
    if not NA_Debloquee(ply, "fuma_ciel") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "fuma_ciel", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "fuma_ciel", "chakra", CHAKRA_COUT) then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "fuma_ciel", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "fuma_ciel", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "fuma_ciel", NA_Stat(ply, "fuma_ciel", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local cible = PointVise(ply)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end

        local shuriken = ents.Create("fuma_shuriken_ciel")
        if not IsValid(shuriken) then return end
        shuriken.Vitesse = VITESSE
        shuriken.Echelle = ECHELLE
        shuriken.Degats  = NA_Stat(ply, "fuma_ciel", "degats", DEGATS)
        shuriken.Rayon   = RAYON
        shuriken.Poussee = POUSSEE
        shuriken:SetOwner(ply)
        shuriken:SetPos(cible + Vector(0, 0, HAUTEUR))
        shuriken:Spawn()
    end)
end)

hook.Add("PlayerDisconnected", "FumaCiel_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
