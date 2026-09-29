--========================================================
-- Senju : Frappe terrestre (SERVEUR)
--
-- Coup de poing au sol : après un court temps d'animation, une onde de choc part devant
-- le lanceur, blesse et projette tout le monde dans la zone (sauf lui).
-- Le serveur décide de tout : incantation, recharge, chakra.
--========================================================

if not SERVER then return end

util.AddNetworkString("senju_frappe_cast")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs de départ
-- (les valeurs par niveau sont dans _na_niveaux_techniques.lua, NA_NIV_TECH.senju_frappe)
--========================================================
local DEGATS        = 35     -- dégâts de l'onde de choc
local RAYON         = 200    -- rayon de la zone
local DISTANCE      = 110    -- distance devant le lanceur où le poing frappe le sol
local PROJECTION    = 350    -- force de projection horizontale
local PROJ_HAUT     = 200    -- force de projection vers le haut
local DELAI_IMPACT  = 0.1    -- secondes entre le début de l'animation et le coup au sol (à régler sur l'animation)

local CHAKRA_COUT   = 30
local CHAKRA_MAX    = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local RECHARGE      = 12
local ANIM_APPEL    = "m_attack_cmb09"
local ANIM_VITESSE  = 1

local PARTICULE     = "solve_doton_pics_floor"   -- particles/solve_doton.pcf
local SON           = "physics/concrete/concrete_break3.wav"

local ROCHER        = "models/clan/konoha/nr_doton_petrifying_sub.mdl"   -- dalle de roche qui sort du sol à l'impact
local ROCHER_ECHELLE = 2.2
local ROCHER_DUREE  = 2.5    -- secondes visible avant de s'enfoncer
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "senju_frappe", stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "dx90.vtx" }) do
    resource.AddFile("models/clan/konoha/nr_doton_petrifying_sub." .. ext)
end
resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem(PARTICULE)

local pret = {}   -- joueur -> moment où la technique est de nouveau disponible

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- roches qui sortent du sol puis s'enfoncent : { ent, pos, debut, duree, bas, haut }
local rochers = {}

hook.Add("Think", "SenjuFrappe_Roches", function()
    for i = #rochers, 1, -1 do
        local r = rochers[i]
        local t = CurTime() - r.debut
        if not IsValid(r.ent) then
            table.remove(rochers, i)
        elseif t > r.duree + 0.6 then
            r.ent:Remove()
            table.remove(rochers, i)
        else
            -- monte en 0.2 s, reste posée, redescend en 0.4 s
            local haut = t < 0.2 and t / 0.2 or (t < r.duree and 1 or 1 - (t - r.duree) / 0.4)
            haut = math.Clamp(haut, 0, 1)
            -- pendant qu'elle reste posée, on ne redéplace pas (grosse entité : chaque SetPos est renvoyé aux clients)
            if haut ~= r.dernier then
                r.dernier = haut
                r.ent:SetPos(r.pos + Vector(0, 0, r.bas + (r.haut - r.bas) * haut))
            end
        end
    end
end)

-- Projette une cible. Un nextbot (faux joueur) freine et recolle au sol tout seul : on lui retire le sol
-- sous les pieds et le freinage pendant qu'il vole. (aussi utilisée par sv_senju_pied.lua)
function NA_Propulser(ent, v)
    if not (ent:IsNextBot() and ent.loco) then return ent:SetVelocity(v) end

    local freinage = ent.loco:GetDeceleration()
    ent.loco:SetDeceleration(0)
    ent:SetGroundEntity(NULL)
    ent:SetPos(ent:GetPos() + Vector(0, 0, 8))
    ent.loco:SetVelocity(v)
    timer.Simple(1.5, function()
        if IsValid(ent) and ent.loco then ent.loco:SetDeceleration(freinage) end
    end)
end

-- Dalle de roche qui sort du sol en "pos" (aussi utilisée par sv_senju_pied.lua)
function NA_SenjuRocher(pos, yaw, echelle, duree)
    local rocher = ents.Create("prop_dynamic")
    if not IsValid(rocher) then return end

    local demi = 27.75 * echelle   -- demi-hauteur du modèle : sert à la cacher entièrement sous le sol au départ
    rocher:SetModel(ROCHER)
    rocher:SetPos(pos - Vector(0, 0, demi * 1.1))
    rocher:SetAngles(Angle(0, yaw, 0))
    rocher:SetModelScale(echelle, 0)
    rocher:Spawn()
    rocher:SetSolid(SOLID_NONE)   -- décor : ne bloque personne
    rochers[#rochers + 1] = { ent = rocher, pos = pos, debut = CurTime(), duree = duree or ROCHER_DUREE, bas = -demi * 1.1, haut = demi * 0.13 }
end

local function Frapper(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- point d'impact : au sol, devant le lanceur
    local avant = Angle(0, ply:EyeAngles().y, 0):Forward()
    local depart = ply:GetPos() + avant * Niv(ply, "distance", DISTANCE)
    local tr = util.TraceLine({
        start = depart + Vector(0, 0, 40), endpos = depart - Vector(0, 0, 200),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local pos = tr.Hit and tr.HitPos or depart

    ParticleEffect(PARTICULE, pos, angle_zero)
    NA_SenjuRocher(pos, ply:EyeAngles().y, ROCHER_ECHELLE)
    sound.Play(SON, pos, 90, 80, 1)
    util.ScreenShake(pos, 8, 8, 0.6, 600)

    for _, ent in ipairs(ents.FindInSphere(pos, Niv(ply, "rayon", RAYON))) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(Niv(ply, "degats", DEGATS))
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CRUSH)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        -- projeté en s'éloignant du point d'impact
        local dir = ent:WorldSpaceCenter() - pos
        dir.z = 0
        local v = dir:GetNormalized() * Niv(ply, "projection", PROJECTION) + Vector(0, 0, Niv(ply, "proj_haut", PROJ_HAUT))
        NA_Propulser(ent, v)
    end
end

net.Receive("senju_frappe_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, "senju_frappe") then return end   -- technique pas encore débloquée (F6)
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
    if NA_CD then NA_CD.Set(ply, "senju_frappe", recharge) end   -- recharge visible dans la barre

    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)   -- animation + pas de coups pendant (_na_mudra.lua)
    timer.Simple(Niv(ply, "delai_impact", DELAI_IMPACT), function() Frapper(ply) end)
end)

hook.Add("PlayerDisconnected", "SenjuFrappe_Nettoyage", function(ply) pret[ply] = nil end)
