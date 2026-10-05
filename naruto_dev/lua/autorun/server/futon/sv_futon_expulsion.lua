--========================================================
-- Futon : Expulsion de vent (SERVEUR)
-- Après le mudra, une explosion de vent autour du lanceur repousse violemment tous les ennemis proches
-- (dégâts + projection loin du lanceur). Le lanceur n'est pas touché.
-- La particule (solve_futon_repulsion) est jouée par les clients : message "futon_expulsion_fx".
--
-- Réseau : "futon_expulsion_cast" (client -> serveur), "futon_expulsion_fx" (serveur -> clients)
--========================================================

util.AddNetworkString("futon_expulsion_cast")
util.AddNetworkString("futon_expulsion_fx")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DEGATS       = 50
local RAYON        = 350
local POUSSE       = 1100   -- vitesse horizontale donnée aux ennemis
local SOULEVEE     = 300    -- vitesse verticale donnée aux ennemis

local RECHARGE     = 14
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.5
local ANIM_APPEL   = "m_ni_atk_ninjutsu_d22nj1_start"
--========================================================

resource.AddFile("particles/solve_futon.pcf")

local ID = "futon_expulsion"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

local pret = {}

local function Expulser(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local centre = ply:GetPos()
    local rayon, degats = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS)
    local pousse, souleve = Niv(ply, "pousse", POUSSE), Niv(ply, "souleve", SOULEVEE)

    for _, ent in ipairs(ents.FindInSphere(centre + Vector(0, 0, 40), rayon)) do
        if NA_InkutonEstCible and NA_InkutonEstCible(ent, ply) then   -- sv_inkuton_singes.lua
            local dir = ent:GetPos() - centre
            dir.z = 0
            if dir:LengthSqr() < 1 then dir = ply:GetForward() end
            dir:Normalize()

            local dmg = DamageInfo()
            dmg:SetDamage(degats)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(ply)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            if ent:IsPlayer() then ent:SetGroundEntity(NULL) end
            ent:SetVelocity(dir * pousse + Vector(0, 0, souleve))
        end
    end

    net.Start("futon_expulsion_fx")
        net.WriteEntity(ply)
        net.WriteFloat(rayon)   -- le client étale l'effet sur tout le rayon
    net.Broadcast()
    ply:EmitSound("naruto_sound/jutsu/futon/futon1.wav", 85, 120)
end

net.Receive("futon_expulsion_cast", function(_, ply)
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
    timer.Simple(mudra, function() Expulser(ply) end)
end)

hook.Add("PlayerDisconnected", "FutonExpulsion_Nettoyage", function(ply) pret[ply] = nil end)
