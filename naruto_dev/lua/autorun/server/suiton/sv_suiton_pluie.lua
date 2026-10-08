--========================================================
-- Suiton : Pluie suiton (SERVEUR)
-- Après les mudras, un nuage d'eau (water_tornado_pat) se forme bien au-dessus de la zone visée et fait pleuvoir des
-- bulles d'eau (atg_bulle_eau, comme la technique Bulles). Chaque bulle qui touche le sol explose (jet_eau_hit_pat)
-- et blesse ceux qui sont dessous. La pluie dure DUREE secondes.
--
-- OPTIMISÉ : le serveur ne crée AUCUNE entité. Il choisit où tombent les bulles (une vague toutes les INTERVALLE
-- secondes), fait les dégâts à l'atterrissage (UNE recherche par vague) et envoie un message par vague ; les bulles
-- et le nuage sont de simples particules côté client (cl_suiton_pluie.lua).
--
-- Réseau : "suiton_pluie_cast" (client -> serveur), "suiton_pluie_nuage" et "suiton_pluie_vague" (serveur -> clients)
--========================================================

if not SERVER then return end

util.AddNetworkString("suiton_pluie_cast")
util.AddNetworkString("suiton_pluie_nuage")
util.AddNetworkString("suiton_pluie_vague")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local DUREE        = 4      -- durée de la pluie (secondes)
local RAYON        = 250    -- rayon de la zone où tombent les bulles
local PAR_VAGUE    = 3      -- bulles par vague
local INTERVALLE   = 0.2    -- secondes entre deux vagues
local DEGATS       = 6      -- dégâts par bulle qui touche quelqu'un
local RAYON_BULLE  = 110    -- demi-largeur de la zone touchée sous une bulle
local HAUTEUR      = 400    -- hauteur de départ des bulles au-dessus du sol
local HAUTEUR_NUAGE = 650   -- hauteur du nuage au-dessus du sol (plus haut que les bulles)
local VITESSE      = 300    -- vitesse de chute (unités/s)
local PORTEE       = 700    -- distance de visée maximale
local CIBLE_VISEE  = 40     -- demi-taille de la boîte de visée : une cible dedans centre la pluie sur elle
local HAUTEUR_MAX  = 100    -- écart de hauteur maximal entre une cible et le sol de la bulle pour être touchée

local RECHARGE     = 14
local CHAKRA_COUT  = 40
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local DUREE_MUDRA  = 0.5
local ANIM_APPEL   = "nrp_ninjutsu_defend_mudwall"
local ANIM_VITESSE = 2
--========================================================

local ID = "suiton_pluie"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

resource.AddFile("particles/patlick_atgsuiton.pcf")
resource.AddFile("particles/atg_particules.pcf")
resource.AddFile("particles/atg_particules2.pcf")

local pret = {}
local developer = GetConVar("developer")   -- lu une fois

-- Une vague : choisit les points d'impact, prévient les clients, fait les dégâts quand les bulles arrivent au sol.
local function Vague(ply, centre, rayon, par, degats, rayonBulle, hauteur, vitesse)
    local chute = hauteur / vitesse
    local pts = {}
    for k = 1, par do
        -- point au hasard dans le disque (racine : répartition uniforme)
        local a, r = math.Rand(0, math.pi * 2), math.sqrt(math.Rand(0, 1)) * rayon
        local p = centre + Vector(math.cos(a) * r, math.sin(a) * r, 0)
        local tr = util.TraceLine({ start = p + Vector(0, 0, hauteur), endpos = p - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then pts[#pts + 1] = tr.HitPos end
    end
    if #pts == 0 then return end

    net.Start("suiton_pluie_vague")
        net.WriteFloat(hauteur)
        net.WriteFloat(chute)
        net.WriteUInt(#pts, 6)
        for k = 1, #pts do net.WriteVector(pts[k]) end
    net.Broadcast()

    -- à l'atterrissage : UNE recherche pour toute la vague, puis distance horizontale à chaque bulle
    timer.Simple(chute, function()
        if not IsValid(ply) then return end
        local r2 = rayonBulle * rayonBulle
        local deja = {}   -- une cible n'est touchée qu'une fois par vague
        for _, ent in ipairs(ents.FindInSphere(centre, rayon + rayonBulle + 40)) do
            if EstCible(ent, ply) then
                local p = ent:GetPos()
                for k = 1, #pts do
                    local dx, dy = p.x - pts[k].x, p.y - pts[k].y
                    if dx * dx + dy * dy <= r2 and math.abs(p.z - pts[k].z) <= HAUTEUR_MAX and not deja[ent] then
                        deja[ent] = true
                        local dmg = DamageInfo()
                        dmg:SetDamage(degats)
                        dmg:SetAttacker(ply)
                        dmg:SetInflictor(ply)
                        dmg:SetDamageType(DMG_DROWN)
                        dmg:SetDamagePosition(ent:WorldSpaceCenter())
                        ent:TakeDamageInfo(dmg)
                        break
                    end
                end
            end
        end
        if developer:GetInt() > 0 then
            for k = 1, #pts do debugoverlay.Sphere(pts[k], rayonBulle, 1, Color(60, 140, 255, 25), true) end
        end
    end)
end

local function Lancer(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- Point visé : le premier mur (ou PORTEE). Si une cible (joueur / PNJ) est sur le chemin du regard, la pluie
    -- se centre SUR ELLE, et non sur le mur derrière elle.
    local oeil = ply:EyePos()
    local mur = util.TraceLine({
        start = oeil, endpos = oeil + ply:GetAimVector() * Niv(ply, "portee", PORTEE),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })

    local cible, dMin = nil, math.huge
    local t = Vector(CIBLE_VISEE, CIBLE_VISEE, CIBLE_VISEE)
    for _, ent in ipairs(NA_FindAlongRay(oeil, mur.HitPos, t)) do   -- _na_visee.lua (comme le Cube Jinton)
        if EstCible(ent, ply) then
            local d = oeil:DistToSqr(ent:WorldSpaceCenter())
            if d < dMin then cible, dMin = ent, d end
        end
    end

    local visee = cible and cible:GetPos() or mur.HitPos
    local sol = util.TraceLine({
        start = visee + Vector(0, 0, 40), endpos = visee - Vector(0, 0, 400),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    local centre = sol.Hit and sol.HitPos or visee

    local duree, rayon = Niv(ply, "duree", DUREE), Niv(ply, "rayon", RAYON)
    local par, degats = math.min(math.floor(Niv(ply, "par_vague", PAR_VAGUE)), 63), Niv(ply, "degats", DEGATS)
    local rayonBulle, hauteur = Niv(ply, "rayon_bulle", RAYON_BULLE), Niv(ply, "hauteur", HAUTEUR)
    local vitesse, intervalle = Niv(ply, "vitesse", VITESSE), Niv(ply, "intervalle", INTERVALLE)

    -- le nuage (pseudo-particule) reste au-dessus de la zone pendant toute la pluie
    net.Start("suiton_pluie_nuage")
        net.WriteVector(centre + Vector(0, 0, Niv(ply, "hauteur_nuage", HAUTEUR_NUAGE)))
        net.WriteFloat(duree)
    net.Broadcast()
    sound.Play("naruto_sound/jutsu/senju/senju2.wav", centre, 80, 100)

    if developer:GetInt() > 0 then debugoverlay.Sphere(centre, rayon, duree, Color(60, 140, 255, 15), true) end

    -- une vague toutes les `intervalle` secondes, pendant `duree` (un seul timer pour toute la pluie)
    local vagues = math.max(1, math.floor(duree / intervalle))
    timer.Create("SuitonPluie_" .. ply:EntIndex(), intervalle, vagues, function()
        if not IsValid(ply) then return end
        Vague(ply, centre, rayon, par, degats, rayonBulle, hauteur, vitesse)
    end)
end

net.Receive("suiton_pluie_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    -- la recharge démarre après la fin de la pluie
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    local total = mudra + Niv(ply, "duree", DUREE) + Niv(ply, "recharge", RECHARGE)
    pret[ply] = CurTime() + total
    if NA_CD then NA_CD.Set(ply, ID, total) end

    NA_AnimJutsu(ply, ANIM_APPEL, 0, ANIM_VITESSE)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Lancer(ply) end)
end)

hook.Add("PlayerDisconnected", "SuitonPluie_Nettoyage", function(ply)
    pret[ply] = nil
    timer.Remove("SuitonPluie_" .. ply:EntIndex())
end)
hook.Add("PlayerDeath", "SuitonPluie_Mort", function(ply) timer.Remove("SuitonPluie_" .. ply:EntIndex()) end)
