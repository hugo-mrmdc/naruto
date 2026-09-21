--========================================================
-- Chinoike : Pluie de sang (SERVEUR)
--
-- On vise un endroit : une pluie de sang tombe sur la zone pendant DUREE
-- secondes (particule izox_chinoike_pluie_bis, particles/1atgyoltix.pcf).
-- Tout ennemi qui reste dessous prend des dégâts à chaque tick.
--
-- Réseau : "chinoike_pluie_zone" (position + durée) -> cl_chinoike_pluie.lua
--========================================================

if not SERVER then return end

util.AddNetworkString("chinoike_pluie_cast")
util.AddNetworkString("chinoike_pluie_zone")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 8      -- secondes de pluie
local INTERVALLE   = 0.5    -- secondes entre deux ticks

local PORTEE       = 800    -- distance max où on peut poser la zone
local RAYON        = 300    -- rayon de la zone qui touche (developer 1 pour la voir)
local HAUTEUR      = 300    -- hauteur de la zone au-dessus du sol

local DEGATS       = 30      -- dégâts par tick et par ennemi
local RALENTI      = 0.75   -- vitesse des ennemis sous la pluie (1 = pas de ralenti)

local RECHARGE     = 22     -- secondes avant de pouvoir relancer (depuis le lancement)
local CHAKRA_COUT  = 35     -- chakra dépensé (0 = gratuit)
local CHAKRA_MAX   = 100    -- = CHAKRA_MAX de sv_sprint_chakra.lua
local DUREE_MUDRA  = 0.5    -- incantation avant la pluie
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local SON_DEBUT    = "ambient/water/water_splash1.wav"
local SON_TICK     = "physics/flesh/flesh_squishy_impact_hard1.wav"
--========================================================

local enCours = {}
local pret    = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Endroit visé, ramené au sol
local function Viser(ply)
    local oeil = ply:EyePos()
    local tr = util.TraceLine({
        start = oeil,
        endpos = oeil + ply:GetAimVector() * PORTEE,
        filter = ply,
    })

    local sol = util.TraceLine({
        start = tr.HitPos + Vector(0, 0, 40),
        endpos = tr.HitPos - Vector(0, 0, 400),
        filter = ply,
        mask = MASK_SOLID_BRUSHONLY,
    })

    return sol.Hit and sol.HitPos or tr.HitPos
end

local function Tick(ply, centre)
    for _, ent in ipairs(ents.FindInSphere(centre + Vector(0, 0, HAUTEUR / 2), RAYON + HAUTEUR)) do
        if not EstCible(ent, ply) then continue end

        -- cylindre : assez près à l'horizontale, et sous la pluie
        local pos = ent:GetPos()
        local ecart = Vector(pos.x - centre.x, pos.y - centre.y, 0):Length()
        local haut = pos.z + ent:OBBMaxs().z
        if ecart > RAYON or haut < centre.z - 20 or pos.z > centre.z + HAUTEUR then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(NA_Stat(ply, "chinoike_pluie", "degats", DEGATS))
        dmg:SetAttacker(IsValid(ply) and ply or game.GetWorld())
        dmg:SetInflictor(IsValid(ply) and ply or game.GetWorld())
        dmg:SetDamageType(DMG_SLASH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
        ent:EmitSound(SON_TICK, 70, math.random(90, 110), 0.6)

        -- ralenti tant qu'ils restent dessous
        if RALENTI < 1 and ent:IsPlayer() then
            ent:SetNW2Float("NA_ChinoikePluieFin", CurTime() + INTERVALLE + 0.1)
        end
    end

    if GetConVar("developer"):GetInt() > 0 then
        debugoverlay.Sphere(centre + Vector(0, 0, HAUTEUR / 2), RAYON, INTERVALLE, Color(255, 120, 120, 20), true)
    end
end

-- ralenti des joueurs sous la pluie
if RALENTI < 1 then
    hook.Add("Move", "ChinoikePluie_Ralenti", function(ply, mv)
        if ply:GetNW2Float("NA_ChinoikePluieFin", 0) > CurTime() then
            mv:SetMaxSpeed(mv:GetMaxSpeed() * RALENTI)
            mv:SetMaxClientSpeed(mv:GetMaxClientSpeed() * RALENTI)
        end
    end)
end

local function Lancer(ply, centre)
    if not IsValid(ply) then return end

    net.Start("chinoike_pluie_zone")
        net.WriteVector(centre)
        net.WriteFloat(DUREE)
    net.Broadcast()

    sound.Play(SON_DEBUT, centre + Vector(0, 0, 60), 90, 90, 1)

    local fin = CurTime() + DUREE
    local nom = "chinoike_pluie_" .. ply:EntIndex() .. "_" .. math.floor(CurTime() * 100)
    timer.Create(nom, INTERVALLE, 0, function()
        if CurTime() >= fin then
            timer.Remove(nom)
            return
        end
        Tick(ply, centre)
    end)
end

net.Receive("chinoike_pluie_cast", function(_, ply)
    if not NA_Debloquee(ply, "chinoike_pluie") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() or enCours[ply] then return end
    if (pret[ply] or 0) > CurTime() then return end

    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if NA_Stat(ply, "chinoike_pluie", "chakra", CHAKRA_COUT) > 0 then
        if chakra < NA_Stat(ply, "chinoike_pluie", "chakra", CHAKRA_COUT) then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - NA_Stat(ply, "chinoike_pluie", "chakra", CHAKRA_COUT))
    end

    enCours[ply] = true
    pret[ply] = CurTime() + NA_Stat(ply, "chinoike_pluie", "recharge", RECHARGE)
    if NA_CD then NA_CD.Set(ply, "chinoike_pluie", NA_Stat(ply, "chinoike_pluie", "recharge", RECHARGE)) end   -- recharge visible dans la barre

    net.Start("Jutsu_Anim_Play")
        net.WriteEntity(ply)
        net.WriteString(ANIM_APPEL)
    net.Broadcast()
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    timer.Simple(DUREE_MUDRA, function()
        enCours[ply] = nil
        if not IsValid(ply) or not ply:Alive() then return end
        Lancer(ply, Viser(ply))
    end)
end)

hook.Add("PlayerDisconnected", "ChinoikePluie_Nettoyage", function(ply)
    enCours[ply] = nil
    pret[ply] = nil
end)
