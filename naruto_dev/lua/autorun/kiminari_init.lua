-- Chargeur des techniques Kiminari.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Particules : chargées des deux côtés
game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem("[19]_kiminari_charge")
game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem("[3]_electric_tornado")
PrecacheParticleSystem("[3]_electric_aura")
game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem("laser_circus_kiminari_pat")
PrecacheParticleSystem("frappe_noir_pat")
PrecacheParticleSystem("impact_frappe_noir_pat")

-- Boulets noirs : position de la boule n° i (sur n) en éventail dans le dos du
-- lanceur, de son épaule gauche à son épaule droite en passant au-dessus de sa
-- tête. Partagé : le serveur tire depuis là, le client y affiche les boules.
local BOULES_RAYON   = 60   -- rayon de l'éventail
local BOULES_RECUL   = 35   -- distance derrière le dos
local BOULES_HAUTEUR = 50   -- hauteur du centre de l'éventail (depuis les pieds)
function NA_KiminariBoulePos(ply, i, n)
    local ang = Angle(0, ply:EyeAngles().y, 0)
    local centre = ply:GetPos() + Vector(0, 0, BOULES_HAUTEUR) - ang:Forward() * BOULES_RECUL
    local a = n > 1 and math.rad(-80 + 160 * (i - 1) / (n - 1)) or 0
    return centre + ang:Right() * (math.sin(a) * BOULES_RAYON) + Vector(0, 0, math.cos(a) * BOULES_RAYON)
end

-- Boulets noirs : bond puis flottement SUR PLACE (NW2Bool "NA_Flotte", mis par
-- sv_kiminari_boulets.lua). Pas de déplacement au clavier, pas de gravité :
-- l'élan du décollage ralentit jusqu'à l'arrêt, puis le joueur reste en l'air.
-- Dans le hook "Move" (serveur + prédiction client) pour rester fluide.
local FLOTTE_FREIN = 6   -- plus grand = le bond s'arrête plus vite (donc moins haut)
hook.Add("Move", "KiminariBoulets_Flotte", function(ply, mv)
    if not ply:Alive() or not ply:GetNW2Bool("NA_Flotte", false) then return end

    local dt = FrameTime()
    if dt <= 0 then return true end

    local vel = LerpVector(math.Clamp(FLOTTE_FREIN * dt, 0, 1), mv:GetVelocity(), vector_origin)
    local from = mv:GetOrigin()
    local tr = util.TraceHull({
        start = from,
        endpos = from + vel * dt,
        mins = ply:OBBMins(),
        maxs = ply:OBBMaxs(),
        filter = ply,
        mask = MASK_PLAYERSOLID,
    })

    if tr.StartSolid then
        mv:SetVelocity(vector_origin)
        return true
    end
    if tr.Hit then vel = vel - tr.HitNormal * vel:Dot(tr.HitNormal) end   -- plafond : on s'arrête dessous

    mv:SetVelocity(vel)
    mv:SetOrigin(tr.HitPos)
    return true   -- le moteur n'ajoute ni gravité ni déplacement
end)

if SERVER then
    resource.AddFile("particles/atg_farisv2.pcf")
    resource.AddFile("particles/atg_faris.pcf")
    resource.AddFile("particles/patlick_atgparticules.pcf")
    resource.AddFile("materials/ui/icon/kiminari_frappe_noir.png")
    resource.AddFile("materials/ui/icon/kiminari_prison_noir.png")
    resource.AddFile("materials/ui/icon/kiminari_cercle_noir.png")
    resource.AddFile("materials/ui/icon/kiminari_boulet_noir.png")

    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_frappe.lua")
    include("autorun/server/kiminari/sv_kiminari_frappe.lua")
    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_prison.lua")
    include("autorun/server/kiminari/sv_kiminari_prison.lua")
    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_laser.lua")
    include("autorun/server/kiminari/sv_kiminari_laser.lua")
    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_boulets.lua")
    include("autorun/server/kiminari/sv_kiminari_boulets.lua")
end

if CLIENT then
    include("autorun/client/kiminari/cl_kiminari_frappe.lua")
    include("autorun/client/kiminari/cl_kiminari_prison.lua")
    include("autorun/client/kiminari/cl_kiminari_laser.lua")
    include("autorun/client/kiminari/cl_kiminari_boulets.lua")
end
