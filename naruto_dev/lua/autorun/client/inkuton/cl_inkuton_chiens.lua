--========================================================
-- Inkuton : Chiens d'encre (CLIENT)
-- Pendant l'animation de lancer : le parchemin (scrollkhalid.mdl) est tenu dans la main
-- gauche et joue sa séquence "2saicmb10 (2saimkm1)" ; la particule solve_inkuton_start_hand
-- est collée à la main droite. Les chiens sont gérés par l'entité inkuton_chien.
--========================================================

game.AddParticles("particles/solve_inkuton_geams.pcf")
PrecacheParticleSystem("solve_inkuton_start_hand")
PrecacheParticleSystem("solve_inkuton_dog_impact")

local MODELE_PARCHEMIN = "models/inkuton/scrollkhalid.mdl"
local SEQ_PARCHEMIN    = "2saicmb10 (2saimkm1)"
local FX_MAIN          = "solve_inkuton_start_hand"
local AVANCE_FIN       = 0.76  -- le parchemin disparaît ce nombre de secondes AVANT la fin de l'animation

-- Le parchemin est tenu dans la main gauche : position et rotation RELATIVES À L'OS DE LA MAIN
-- (comme un accessoire). Valeurs en dur : les régler avec l'éditeur (inkuton_scroll_editeur,
-- cl_inkuton_editeur.lua) puis recopier ici.
NA_InkutonParchemin = NA_InkutonParchemin or {}
local P = NA_InkutonParchemin
P.pos = Vector(-0.8, -1.6, 1.6)   -- avant / droite / haut dans le repère de l'os (unités)
P.ang = Angle(4.9, -112.7, -29.4)   -- pitch / yaw / roll (degrés)

-- Cherche l'os d'une main (modèles ValveBiped, Bip01 ou autres noms courants)
local function TrouverOs(ply, droite)
    local noms = droite
        and { "ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "Bip01_R_Hand", "R Hand", "RightHand" }
        or  { "ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "Bip01_L_Hand", "L Hand", "LeftHand" }
    for _, n in ipairs(noms) do
        local id = ply:LookupBone(n)
        if id then return id end
    end
    for i = 0, ply:GetBoneCount() - 1 do
        local n = (ply:GetBoneName(i) or ""):lower()
        if n:find("hand", 1, true) and not n:find("finger", 1, true) then
            local est_droite = n:find("r_hand", 1, true) or n:find("hand_r", 1, true) or n:find("right", 1, true) or n:find(" r ", 1, true)
            if (droite and est_droite) or (not droite and not est_droite) then return i end
        end
    end
end

-- Os de la main gauche et de la main droite, DANS CET ORDRE. Les noms d'os ne disent pas toujours quel côté
-- est lequel : on vérifie une fois par modèle avec les positions réelles des mains (la gauche est du côté
-- opposé à ply:GetRight()), lues au moment du lancer, donc AVANT que l'animation ne bouge les bras (les
-- os viennent de l'image précédente). Aucun modèle n'est créé : on ne touche pas au joueur.
local cacheMains = {}
local function MainsOs(ply)
    local modele = ply:GetModel()
    local c = cacheMains[modele]
    if c then return c[1], c[2] end

    local g, d = TrouverOs(ply, false), TrouverOs(ply, true)
    if g and d and g ~= d then
        local mg, md = ply:GetBoneMatrix(g), ply:GetBoneMatrix(d)
        if mg and md then
            local ecart = (mg:GetTranslation() - md:GetTranslation()):Dot(ply:GetRight())
            if math.abs(ecart) > 1 then
                if ecart > 0 then g, d = d, g end   -- "gauche" est en fait du côté droit : on échange
                cacheMains[modele] = { g, d }
            end
        end
    end
    return g, d
end

local actifs = {}   -- joueur -> { parchemin, fx, osG, osD, debut, fin, duree }

local function Arreter(ply)
    local a = actifs[ply]
    if not a then return end
    if IsValid(a.parchemin) then a.parchemin:Remove() end
    if IsValid(a.fx) then a.fx:StopEmission() end
    actifs[ply] = nil
end

net.Receive("inkuton_chiens_mains", function()
    local ply = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    Arreter(ply)

    local parchemin = ClientsideModel(MODELE_PARCHEMIN, RENDERGROUP_OPAQUE)
    if not IsValid(parchemin) then return end
    parchemin:SetNoDraw(true)
    local seq = parchemin:LookupSequence(SEQ_PARCHEMIN)
    if seq and seq >= 0 then parchemin:ResetSequence(seq) end

    actifs[ply] = {
        parchemin = parchemin,
        fx = CreateParticleSystemNoEntity(FX_MAIN, ply:GetPos()),
        osG = (MainsOs(ply)),
        osD = select(2, MainsOs(ply)),
        debut = CurTime(),
        fin = CurTime() + duree - AVANCE_FIN,
        duree = math.max(duree - AVANCE_FIN, 0.1),
    }

    -- le parchemin disparaît pile à la fin de l'animation du joueur (heure calculée par jutsu_anim_cl.lua)
    local finAnim = ply.NA_AnimFin
    if finAnim and finAnim > CurTime() and finAnim < CurTime() + duree + 1 then
        actifs[ply].fin = finAnim - AVANCE_FIN
        actifs[ply].duree = math.max(finAnim - AVANCE_FIN - CurTime(), 0.1)
    end
end)

-- nettoyage même si le joueur n'est pas dessiné (vue à la première personne, hors champ...)
hook.Add("Think", "InkutonChiens_Fin", function()
    for ply, a in pairs(actifs) do
        if not IsValid(ply) or not ply:Alive() or (not a.infini and CurTime() > a.fin) then
            Arreter(ply)
        end
    end
end)

-- placé après le dessin du joueur : les os sont à jour
hook.Add("PostPlayerDraw", "InkutonChiens_Mains", function(ply)
    local a = actifs[ply]
    if not a then return end
    if not ply:Alive() or (not a.infini and CurTime() > a.fin) then Arreter(ply) return end

    -- main droite : particule
    local matD = a.osD and ply:GetBoneMatrix(a.osD)
    if IsValid(a.fx) then
        a.fx:SetControlPoint(0, matD and matD:GetTranslation() or ply:GetPos() + Vector(0, 0, 40))
    end

    -- main gauche : parchemin, qui se déroule sur la durée de l'animation
    local matG = a.osG and ply:GetBoneMatrix(a.osG)
    if matG and IsValid(a.parchemin) then
        local pos, ang = LocalToWorld(P.pos, P.ang, matG:GetTranslation(), matG:GetAngles())
        a.parchemin:SetPos(pos)
        a.parchemin:SetAngles(ang)
        a.parchemin:SetCycle(a.cycle or math.Clamp((CurTime() - a.debut) / a.duree, 0, 0.99))
        a.parchemin:SetupBones()
        a.parchemin:DrawModel()
    end
end)

-- Pour l'éditeur : démarre / arrête le parchemin sur le joueur sans durée limite
function P.Demarrer(ply)
    Arreter(ply)
    local p = ClientsideModel(MODELE_PARCHEMIN, RENDERGROUP_OPAQUE)
    if not IsValid(p) then return end
    p:SetNoDraw(true)
    local seq = p:LookupSequence(SEQ_PARCHEMIN)
    if seq and seq >= 0 then p:ResetSequence(seq) end
    actifs[ply] = { parchemin = p, osG = (MainsOs(ply)), osD = select(2, MainsOs(ply)),
                    debut = CurTime(), fin = 0, duree = 1, infini = true }
    return actifs[ply]
end
function P.Arreter(ply) Arreter(ply) end
function P.Etat(ply) return actifs[ply] end

hook.Add("PlayerDeath", "InkutonChiens_Mort", function(ply) Arreter(ply) end)

-- Lancement (appelé par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.inkuton_chiens = function()
    net.Start("inkuton_chiens_cast")
    net.SendToServer()
end
