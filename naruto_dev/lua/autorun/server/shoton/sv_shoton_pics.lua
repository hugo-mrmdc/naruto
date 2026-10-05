--========================================================
-- Shoton : Pics de cristal (SERVEUR)
-- Après les mudras, une forêt de cristaux (models/shoton/solve_crystal01_kg_geams.mdl) sort du sol en éventail devant le
-- lanceur, rangée après rangée. Chaque cristal a sa taille, son inclinaison et une petite variante de couleur (rose / lilas).
-- Chaque ennemi touché subit des dégâts (une seule fois) et un étourdissement. Les cristaux disparaissent après DUREE_VIE.
--
-- Réseau : "shoton_pics_cast" (client -> serveur), "shoton_pics_touche" (serveur -> clients : particules d'une rangée)
--========================================================

util.AddNetworkString("shoton_pics_cast")
util.AddNetworkString("shoton_pics_touche")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local RANGEES      = 6      -- rangées de cristaux
local PAR_RANGEE   = 6      -- cristaux par rangée
local ECART        = 75     -- distance entre deux rangées
local DEPART       = 90     -- distance de la première rangée
local DELAI        = 0.07   -- secondes entre deux rangées
local RAYON        = 90     -- demi-largeur de la zone touchée autour d'un cristal
local DEGATS       = 50
local STUN         = 0      -- pas d'étourdissement : dégâts bruts
local ECHELLE      = 0.8    -- le modèle fait ~137 unités de haut à l'échelle 1 : ajuster si trop gros / petit
local DUREE_VIE    = 1.8
local PETIT        = 0.3    -- taille relative de la première rangée
local GROS         = 1.5    -- taille relative de la dernière rangée

local RECHARGE     = 20
local CHAKRA_COUT  = 55
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local MODELE       = "models/shoton/solve_crystal01_kg_geams.mdl"
-- petites variantes de teinte (multiplient la couleur du matériau) : rose, lilas, violet clair...
local TEINTES = {
    Color(255, 215, 255), Color(225, 205, 255), Color(245, 230, 255),
    Color(255, 190, 240), Color(210, 200, 255), Color(255, 235, 250),
}
--========================================================

local ID = "shoton_pics"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

local pret = {}

local function Teinte()
    local t = TEINTES[math.random(#TEINTES)]
    local function v(c) return math.Clamp(c + math.random(-12, 12), 150, 255) end
    return v(t.r), v(t.g), v(t.b)
end

-- Une rangée : les cristaux sont de simples modèles côté CLIENT (aucune entité serveur) ; le serveur calcule leurs
-- positions, fait UNE recherche d'ennemis pour toute la rangée et envoie tout dans UN seul message.
-- grandeur : 0 (bord de l'éventail) à 1 (milieu) -> les cristaux du centre sont plus hauts
-- progression : 0 (première rangée) à 1 (dernière) -> petits au début, de plus en plus gros à la fin
local function Rangee(ply, centre, dr, av, largeur, par, touches, rayon, degats, stun, echelle, vie, progression)
    local liste = {}
    for _ = 1, par do
        local d = math.Rand(-1, 1)
        local p = centre + dr * (d * largeur) + av * math.Rand(-ECART / 2, ECART / 2)
        local tr = util.TraceLine({ start = p + Vector(0, 0, 100), endpos = p - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then
            liste[#liste + 1] = {
                pos = tr.HitPos - Vector(0, 0, 3),
                ech = echelle * math.Rand(0.8, 1.2) * (0.8 + 0.4 * (1 - math.abs(d))) * Lerp(progression, PETIT, GROS),
            }
        end
    end

    -- dégâts : une seule recherche pour la rangée, puis distance à chaque cristal
    local r2 = rayon * rayon
    for _, ent in ipairs(ents.FindInSphere(centre, largeur + ECART / 2 + rayon + 10)) do
        if not touches[ent] and EstCible(ent, ply) then
            local ep = ent:GetPos()
            for _, c in ipairs(liste) do
                if ep:DistToSqr(c.pos) <= r2 then
                    touches[ent] = true
                    local dmg = DamageInfo()
                    dmg:SetDamage(degats)
                    dmg:SetAttacker(ply)
                    dmg:SetInflictor(ply)
                    dmg:SetDamageType(DMG_GENERIC)
                    dmg:SetDamagePosition(ent:WorldSpaceCenter())
                    ent:TakeDamageInfo(dmg)
                    if stun > 0 and NA_Etourdir then NA_Etourdir(ent, stun) end
                    break
                end
            end
        end
    end

    if #liste == 0 then return end
    sound.Play("physics/glass/glass_impact_bullet" .. math.random(1, 4) .. ".wav", centre, 75, math.random(70, 100))   -- un seul son par rangée

    net.Start("shoton_pics_touche")
        net.WriteVector(centre)
        net.WriteFloat(vie)
        net.WriteUInt(#liste, 6)
        for _, c in ipairs(liste) do
            net.WriteVector(c.pos)
            net.WriteUInt(math.random(0, 359), 9)
            net.WriteInt(math.random(-18, 18), 7)
            net.WriteInt(math.random(-18, 18), 7)
            net.WriteFloat(c.ech)
            local r, g, b = Teinte()
            net.WriteUInt(r, 8) net.WriteUInt(g, 8) net.WriteUInt(b, 8)
        end
    net.Broadcast()
end

net.Receive("shoton_pics_cast", function(_, ply)
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

    NA_AnimJutsu(ply, ANIM_APPEL)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local rangees, par = Niv(ply, "rangees", RANGEES), Niv(ply, "par_rangee", PAR_RANGEE)
        local rayon, degats, stun = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS), Niv(ply, "stun", STUN)
        local echelle, vie = Niv(ply, "echelle", ECHELLE), Niv(ply, "duree_vie", DUREE_VIE)
        local ang = Angle(0, ply:EyeAngles().y, 0)
        local av, dr, base = ang:Forward(), ang:Right(), ply:GetPos()
        local touches = {}
        for i = 0, rangees - 1 do
            timer.Simple(i * DELAI, function()
                if not IsValid(ply) then return end
                local c = base + av * (DEPART + i * ECART)
                Rangee(ply, c, dr, av, 40 + i * 18, par, touches, rayon, degats, stun, echelle, vie,
                    i / math.max(rangees - 1, 1))   -- l'éventail s'élargit
            end)
        end
    end)
end)

hook.Add("PlayerDisconnected", "ShotonPics_Nettoyage", function(ply) pret[ply] = nil end)
