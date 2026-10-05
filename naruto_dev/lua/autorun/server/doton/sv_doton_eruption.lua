--========================================================
-- Doton : Éruption de roche (SERVEUR)
-- Après les mudras, une forêt de roches (models/nature/doton/nr_doton_debris1 à 5) sort du sol en éventail devant le
-- lanceur, rangée après rangée. Contrairement aux Pics de cristal Shoton, toutes les roches ont la MÊME taille
-- (et plus grande que celle du modèle). Chaque ennemi touché subit des dégâts (une seule fois) et un étourdissement
-- éventuel.
--
-- OPTIMISÉ : le serveur ne crée AUCUNE entité. Il calcule les positions, fait les dégâts (une recherche par rangée)
-- et envoie un message par rangée ; les roches sont de simples modèles côté client (cl_doton_eruption.lua).
--
-- Réseau : "doton_eruption_cast" (client -> serveur), "doton_eruption_rangee" (serveur -> clients : une rangée de roches)
--========================================================

util.AddNetworkString("doton_eruption_cast")
util.AddNetworkString("doton_eruption_rangee")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local RANGEES      = 6      -- rangées de roches
local PAR_RANGEE   = 5      -- roches par rangée
local ECART        = 80     -- distance entre deux rangées
local DEPART       = 90     -- distance de la première rangée
local DELAI        = 0.07   -- secondes entre deux rangées
local RAYON        = 95     -- demi-largeur de la zone touchée autour d'une roche
local DEGATS       = 30
local STUN         = 0      -- 0 = dégâts bruts, sans étourdissement
local ECHELLE      = 5      -- les modèles font ~14 x 30 unités à l'échelle 1 : à 5, une roche fait ~70 x 150
local DUREE_VIE    = 2
local LARGEUR_MAX  = 45     -- largeur initiale de l'éventail (il s'élargit ensuite)
local PARTICULE_TOUS_LES = 2   -- une particule de poussière toutes les N rangées (1 = chaque rangée, plus = moins)
local HAUTEUR_MAX  = 128    -- écart de hauteur maximal entre une cible et la rangée pour être touchée

local RECHARGE     = 16
local CHAKRA_COUT  = 45
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.4
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2
--========================================================

local ID = "doton_eruption"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

-- modèles et textures (matériau nr_doton_debris + ses textures) envoyés aux clients
for i = 1, 5 do
    local base = "models/nature/doton/nr_doton_debris" .. i
    for _, ext in ipairs({ ".mdl", ".vvd", ".dx90.vtx", ".phy" }) do resource.AddFile(base .. ext) end
end
resource.AddFile("materials/yugen/models/naruto/jutsu/doton/nr_doton_debris.vmt")
resource.AddFile("materials/yugen/models/naruto/jutsu/doton/nr_doton_petrifying_main.vtf")
resource.AddFile("materials/yugen/models/naruto/jutsu/doton/light_fix.vtf")
resource.AddFile("materials/yugen/models/naruto/toon/toon.vtf")
resource.AddFile("particles/solve_doton.pcf")

local pret = {}
local developer = GetConVar("developer")   -- lu une fois

-- Une rangée : positions, dégâts (UNE recherche pour toute la rangée), message aux clients.
local function Rangee(ply, i, c, dr, av, l, par, touches, rayon, degats, stun, echelle, vie)
    -- un seul tir de rayon par rangée : hauteur du sol au milieu (chaque client recale ensuite chaque roche)
    local sol = util.TraceLine({ start = c + Vector(0, 0, 100), endpos = c - Vector(0, 0, 300), mask = MASK_SOLID_BRUSHONLY })
    if not sol.Hit then return end
    local z = sol.HitPos.z

    local pos = {}
    for k = 1, par do
        local p = c + dr * (math.Rand(-1, 1) * l) + av * math.Rand(-ECART / 2, ECART / 2)
        pos[k] = Vector(p.x, p.y, z)
    end

    -- dégâts : une seule recherche autour de la rangée, puis distance horizontale simple à chaque roche
    local rayon2 = rayon * rayon
    for _, ent in ipairs(ents.FindInSphere(c, l + ECART / 2 + rayon)) do
        if not touches[ent] and EstCible(ent, ply) then
            local p = ent:GetPos()
            if math.abs(p.z - z) <= HAUTEUR_MAX then
                for k = 1, par do
                    local dx, dy = p.x - pos[k].x, p.y - pos[k].y
                    if dx * dx + dy * dy <= rayon2 then
                        touches[ent] = true
                        local dmg = DamageInfo()
                        dmg:SetDamage(degats)
                        dmg:SetAttacker(ply)
                        dmg:SetInflictor(ply)
                        dmg:SetDamageType(DMG_CRUSH)
                        dmg:SetDamagePosition(ent:WorldSpaceCenter())
                        ent:TakeDamageInfo(dmg)
                        if stun > 0 and NA_Etourdir then NA_Etourdir(ent, stun) end
                        break
                    end
                end
            end
        end
    end

    -- hitbox visible avec developer 1 (sphère autour de chaque roche)
    if developer:GetInt() > 0 then
        for k = 1, par do debugoverlay.Sphere(pos[k], rayon, 2, Color(200, 140, 60, 25), true) end
    end

    -- un seul son par rangée (pas de prop : le son est joué à la position du milieu)
    sound.Play("naruto_sound/jutsu/doton/earth1.wav", pos[1], 78, math.random(60, 90))

    -- un seul message pour toute la rangée (positions + taille + durée + particule oui/non)
    net.Start("doton_eruption_rangee")
        net.WriteFloat(echelle)
        net.WriteFloat(vie)
        net.WriteBool(i % PARTICULE_TOUS_LES == 0)
        net.WriteUInt(par, 6)
        for k = 1, par do net.WriteVector(pos[k]) end
    net.Broadcast()
end

net.Receive("doton_eruption_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
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

    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then return end
        local rangees, par = Niv(ply, "rangees", RANGEES), math.min(Niv(ply, "par_rangee", PAR_RANGEE), 63)
        local rayon, degats, stun = Niv(ply, "rayon", RAYON), Niv(ply, "degats", DEGATS), Niv(ply, "stun", STUN)
        local echelle, vie = Niv(ply, "echelle", ECHELLE), Niv(ply, "duree_vie", DUREE_VIE)
        local ang = Angle(0, ply:EyeAngles().y, 0)
        local av, dr, base = ang:Forward(), ang:Right(), ply:GetPos()
        local touches = {}
        for i = 0, rangees - 1 do
            timer.Simple(i * DELAI, function()
                if not IsValid(ply) then return end
                local c = base + av * (DEPART + i * ECART)
                Rangee(ply, i, c, dr, av, LARGEUR_MAX + i * 18, par, touches, rayon, degats, stun, echelle, vie)   -- l'éventail s'élargit
            end)
        end
    end)
end)

hook.Add("PlayerDisconnected", "DotonEruption_Nettoyage", function(ply) pret[ply] = nil end)
