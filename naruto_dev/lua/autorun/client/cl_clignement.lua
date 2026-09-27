--========================================================
-- Clignement des yeux (CLIENT)
--
-- La tête des joueurs (models/head_03.mdl, posée par sv_playerskin.lua) a un
-- flex "basic_blink" qui ferme les paupières. Chaque client fait cligner
-- toutes les têtes proches, image par image : rien ne passe par le réseau.
--
-- Chaque joueur a son propre rythme (aléatoire). Tête connue via le
-- NW2Entity "NA_TeteEnt". Le flex est posé au moment du dessin de la tête
-- (RenderOverride), sinon les mises à jour réseau le remettent à 0.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FLEX          = "basic_blink"   -- flex de la tête qui ferme les yeux
local ECART_MIN     = 2.5             -- secondes minimum entre deux clignements
local ECART_MAX     = 6               -- secondes maximum entre deux clignements
local DUREE_FERMER  = 0.07            -- secondes pour fermer les paupières
local DUREE_FERME   = 0.04            -- secondes yeux fermés
local DUREE_OUVRIR  = 0.10            -- secondes pour rouvrir
local CHANCE_DOUBLE = 0               -- chance d'un double clignement volontaire (0 à 1, ex. 0.15)
local DISTANCE_MAX  = 1500            -- plus loin, on ne s'en occupe pas (invisible de toute façon)
--========================================================

local DUREE_TOTALE = DUREE_FERMER + DUREE_FERME + DUREE_OUVRIR

local etat = {}   -- tête -> { flex = index, prochain = moment du prochain clignement, debut = début du clignement en cours }

-- Fermeture des paupières (0 = ouvertes, 1 = fermées) à t secondes du début du clignement
local function Fermeture(t)
    if t < 0 or t >= DUREE_TOTALE then return 0 end
    if t < DUREE_FERMER then return t / DUREE_FERMER end
    t = t - DUREE_FERMER
    if t < DUREE_FERME then return 1 end
    t = t - DUREE_FERME
    return 1 - t / DUREE_OUVRIR
end

local function Prevoir(e, now)
    e.prochain = now + math.Rand(ECART_MIN, ECART_MAX)
end

-- Fermeture des paupières (0 à 1) de cette tête à cet instant (cl_perso.lua dessine une copie de la tête)
function NA_YeuxFermes(tete)
    local e = etat[tete]
    return e and e.ferme or 0
end

hook.Add("Think", "NA_Clignement", function()
    local now = CurTime()
    local moi = LocalPlayer()
    if not IsValid(moi) then return end
    local oeil = moi:EyePos()

    for _, ply in ipairs(player.GetAll()) do
        local tete = ply:GetNW2Entity("NA_TeteEnt")
        if not IsValid(tete) or tete:IsDormant() then continue end
        if oeil:DistToSqr(tete:GetPos()) > DISTANCE_MAX * DISTANCE_MAX then continue end

        local e = etat[tete]
        if not e then
            local id = tete:GetFlexIDByName(FLEX)
            -- visages personnalisés (models/head/) : pas de "basic_blink", le clignement
            -- passe par la forme d'yeux choisie (NA_PoserFormes, cl_perso.lua)
            local face = string.StartWith(tete:GetModel() or "", "models/head/face_")
            if not id and not face then etat[tete] = { flex = false } continue end   -- modèle sans ce flex
            e = { flex = id, face = face }
            Prevoir(e, now)
            etat[tete] = e
        end
        if not e.flex and not e.face then continue end

        -- début d'un clignement
        if not e.debut and now >= e.prochain then
            e.debut = now
        end

        local ferme = 0
        if e.debut then
            local t = now - e.debut
            ferme = Fermeture(t)
            if t >= DUREE_TOTALE then
                -- parfois, un deuxième clignement juste après
                if not e.double and math.random() < CHANCE_DOUBLE then
                    e.double = true
                    e.debut = now + 0.06
                else
                    e.debut, e.double = nil, nil
                    Prevoir(e, now)
                end
            end
        end

        -- yeux fermés sur un joueur mort (tête encore présente avant de disparaître)
        if not ply:Alive() then ferme = 1 end

        -- La tête vient du serveur : à chaque mise à jour réseau, le jeu remet ses
        -- flex à la valeur du serveur (0 = yeux ouverts). Poser la valeur ici ne
        -- suffit donc pas (les yeux se rouvraient une image en plein clignement,
        -- ce qui donnait un double clignement) : on la pose au moment du dessin.
        e.ferme = ferme
        if not tete.NA_Clignement then
            tete.NA_Clignement = true
            tete.RenderOverride = function(self, flags)
                local et = etat[self]
                if et and et.flex then self:SetFlexWeight(et.flex, et.ferme or 0) end
                if et and et.face then NA_PoserFormes(self, et.ferme or 0) end
                self:DrawModel(flags)
            end
        end
    end

    -- têtes disparues : on oublie leur état
    for tete in pairs(etat) do
        if not IsValid(tete) then etat[tete] = nil end
    end
end)
