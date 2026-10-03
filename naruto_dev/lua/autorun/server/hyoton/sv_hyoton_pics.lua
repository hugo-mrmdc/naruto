--========================================================
-- Hyoton : Pics de glace (SERVEUR)
-- Après les mudras, des pics de glace (models/hyoton/cayzi_props_hyoton_2.mdl) sortent du sol en éventail devant le
-- lanceur, rangée après rangée. Chaque ennemi touché subit des dégâts (une seule fois) et un court étourdissement.
-- Les pics grandissent puis rapetissent avant de disparaître (SetModelScale, pas de collision).
--
-- Réseau : "hyoton_pics_cast" (client -> serveur)
--========================================================

util.AddNetworkString("hyoton_pics_cast")
util.AddNetworkString("hyoton_pics_touche")   -- serveur -> clients : particule à chaque apparition d'un pic

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

local function Pic(ply, pos, touches, rayon, degats, stun, echelle, vie)
    local tr = util.TraceLine({ start = pos + Vector(0, 0, 100), endpos = pos - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
    if not tr.Hit then return end
    pos = tr.HitPos

    local pic = ents.Create("prop_dynamic")
    if not IsValid(pic) then return end
    pic:SetModel("models/hyoton/cayzi_props_hyoton_2.mdl")
    pic:SetPos(pos)
    pic:SetAngles(Angle(-90 + math.Rand(-12, 12), math.random(0, 359), math.Rand(-12, 12)))   -- le modèle est couché sur X : pointe vers le haut
    pic:SetSolid(SOLID_NONE)
    pic:Spawn()
    pic:SetModelScale(0.05, 0)
    pic:SetModelScale(echelle * math.Rand(0.8, 1.2), 0.15)
    pic:EmitSound("physics/glass/glass_impact_bullet1.wav", 70, math.random(80, 100))
    net.Start("hyoton_pics_touche")
    net.WriteVector(pos - Vector(0, 0, DECALAGE_FX))
    net.Broadcast()
    timer.Simple(vie, function()
        if not IsValid(pic) then return end
        pic:SetModelScale(0.05, 0.3)
        timer.Simple(0.3, function() if IsValid(pic) then pic:Remove() end end)
    end)

    for _, ent in ipairs(ents.FindInSphere(pos, rayon)) do
        if not touches[ent] and IsValid(ply) and EstCible(ent, ply) then
            touches[ent] = true
            local dmg = DamageInfo()
            dmg:SetDamage(degats)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(ply)
            dmg:SetDamageType(DMG_GENERIC)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)
            if stun > 0 and NA_Etourdir then NA_Etourdir(ent, stun) end
        end
    end
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
                for _, d in ipairs({ -l, 0, l }) do
                    Pic(ply, c + dr * d, touches, rayon, degats, stun, echelle, vie)
                end
            end)
        end
    end)
end)

hook.Add("PlayerDisconnected", "HyotonPics_Nettoyage", function(ply) pret[ply] = nil end)
