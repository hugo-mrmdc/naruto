--========================================================
-- Hyoton : Pics de glace (SERVEUR)
-- Après les mudras, des pics de glace (models/hyoton/cayzi_props_hyoton_2.mdl) sortent du sol en éventail devant le
-- lanceur, rangée après rangée. Chaque ennemi touché subit des dégâts (une seule fois) et un court étourdissement.
-- Les pics grandissent puis rapetissent avant de disparaître (SetModelScale, pas de collision).
--
-- Réseau : "hyoton_pics_cast" (client -> serveur)
--========================================================

util.AddNetworkString("hyoton_pics_cast")
util.AddNetworkString("hyoton_pics_touche")   -- serveur -> clients : une particule à un endroit (la vague de glace s'en sert aussi)
util.AddNetworkString("hyoton_pics_rangee")   -- serveur -> clients : une rangée de pics (modèles + particules)

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local RANGEES      = 8      -- rangées de pics
local ECART        = 70     -- distance entre deux rangées
local DEPART       = 90     -- distance de la première rangée
local DELAI        = 0.08   -- secondes entre deux rangées
local RAYON        = 70     -- demi-largeur de la zone touchée autour d'un pic
local DEGATS       = 40
local STUN         = 1
local ECHELLE      = 0.6    -- le modèle fait ~58 unités de long à l'échelle 1 : ajuster si trop gros / petit
local DUREE_VIE    = 0.8
local DECALAGE_FX  = 60     -- unités dont la particule est descendue sous le sol pour qu'elle cache moins les pics

local RECHARGE     = 14
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_dragonflamebombs_start"
--========================================================

local ID = "hyoton_pics"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

local pret = {}

-- Une rangée de pics : les pics sont de simples modèles côté CLIENT (aucune entité serveur) ; le serveur calcule leurs
-- positions, fait UNE recherche d'ennemis pour toute la rangée et envoie tout dans UN seul message.
local function Rangee(ply, centre, dr, largeur, touches, rayon, degats, stun, echelle, vie)
    local liste = {}
    for _, d in ipairs({ -largeur, 0, largeur }) do
        local p = centre + dr * d
        local tr = util.TraceLine({ start = p + Vector(0, 0, 100), endpos = p - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then liste[#liste + 1] = tr.HitPos end
    end
    if #liste == 0 then return end

    -- dégâts : une seule recherche pour la rangée, puis distance à chaque pic
    local r2 = rayon * rayon
    for _, ent in ipairs(ents.FindInSphere(centre, largeur + rayon + 10)) do
        if not touches[ent] and IsValid(ply) and EstCible(ent, ply) then
            local ep = ent:GetPos()
            for _, p in ipairs(liste) do
                if ep:DistToSqr(p) <= r2 then
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

    sound.Play("physics/glass/glass_impact_bullet1.wav", centre, 70, math.random(80, 100))   -- un seul son par rangée

    net.Start("hyoton_pics_rangee")
        net.WriteFloat(vie)
        net.WriteFloat(DECALAGE_FX)
        net.WriteUInt(#liste, 3)
        for _, p in ipairs(liste) do
            net.WriteVector(p)
            net.WriteInt(math.random(-12, 12), 6)    -- inclinaison
            net.WriteUInt(math.random(0, 359), 9)    -- cap
            net.WriteInt(math.random(-12, 12), 6)
            net.WriteFloat(echelle * math.Rand(0.8, 1.2))
        end
    net.Broadcast()
end

net.Receive("hyoton_pics_cast", function(_, ply)
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
        local rangees = Niv(ply, "rangees", RANGEES)
        local rayon, degats, stun = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS), Niv(ply, "stun", STUN)
        local echelle, vie = Niv(ply, "echelle", ECHELLE), Niv(ply, "duree_vie", DUREE_VIE)
        local ang = Angle(0, ply:EyeAngles().y, 0)
        local av, dr, base = ang:Forward(), ang:Right(), ply:GetPos()
        local touches = {}
        for i = 0, rangees - 1 do
            timer.Simple(i * DELAI, function()
                if not IsValid(ply) then return end
                local c = base + av * (DEPART + i * ECART)
                local l = 30 + i * 12   -- l'éventail s'élargit
                Rangee(ply, c, dr, l, touches, rayon, degats, stun, echelle, vie)
            end)
        end
    end)
end)

hook.Add("PlayerDisconnected", "HyotonPics_Nettoyage", function(ply) pret[ply] = nil end)
