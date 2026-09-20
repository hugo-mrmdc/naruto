--========================================================
-- Dégâts affichés (CLIENT)
-- Chiffres de dégâts qui apparaissent au-dessus de la cible touchée : petit
-- "pop", montée, puis disparition. Les coups très rapprochés sur la même cible
-- (ticks de laser, de cube...) s'additionnent dans un seul chiffre.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local DUREE        = 1.4     -- secondes d'affichage
local MONTEE       = 45      -- unités de montée pendant l'affichage
local CUMUL        = 0.25    -- secondes : deux coups sur la même cible plus proches que ça s'additionnent
local ECART        = 22      -- décalage horizontal aléatoire (pixels à 1080p)
local SEUIL_FORT   = 40      -- à partir de ces dégâts : chiffre plus gros et coloré

local TAILLE       = 44      -- taille du chiffre (à 1080p)
local TAILLE_FORT  = 58      -- taille des gros coups
local ECHELLE_MIN  = 0.85    -- taille minimale quand la cible est loin (1 = jamais réduit)
local EPAISSEUR    = 3       -- épaisseur du contour

local COULEUR      = Color(255, 245, 225)
local COULEUR_FORT = Color(255, 190, 40)
local CONTOUR      = Color(25, 5, 5, 255)
--========================================================

local function CreerPolices()
    local k = ScrH() / 1080
    surface.CreateFont("NA.Degats",      { font = "Roboto", size = math.Round(TAILLE * k), weight = 1000, italic = true })
    surface.CreateFont("NA.Degats.Fort", { font = "Roboto", size = math.Round(TAILLE_FORT * k), weight = 1000, italic = true })
end
CreerPolices()
hook.Add("OnScreenSizeChanged", "NA_Degats_Polices", CreerPolices)

local chiffres = {}      -- { cible, pos, valeur, debut, dx }
local parCible = {}      -- index de la cible -> dernier chiffre (pour cumuler)

net.Receive("NA_Degats", function()
    local index = net.ReadUInt(16)
    local pos = net.ReadVector()
    local valeur = net.ReadUInt(16)
    local now = CurTime()

    local dernier = parCible[index]
    if dernier and now - dernier.debut < CUMUL then
        -- coup très proche : on ajoute au même chiffre et on relance son "pop"
        dernier.valeur = dernier.valeur + valeur
        dernier.debut = now
        dernier.pos = pos
        return
    end

    local c = { pos = pos, valeur = valeur, debut = now, dx = math.Rand(-ECART, ECART) }
    chiffres[#chiffres + 1] = c
    parCible[index] = c
end)

hook.Add("HUDPaint", "NA_Degats_Dessin", function()
    if #chiffres == 0 then return end
    local now = CurTime()
    local k = ScrH() / 1080
    local oeil = EyePos()

    for i = #chiffres, 1, -1 do
        local c = chiffres[i]
        local t = (now - c.debut) / DUREE

        if t >= 1 then
            table.remove(chiffres, i)
            for idx, d in pairs(parCible) do if d == c then parCible[idx] = nil end end
        else
            local monde = c.pos + Vector(0, 0, MONTEE * t)
            local ecran = monde:ToScreen()
            if ecran.visible then
                -- "pop" à l'apparition (1,6 -> 1), puis léger rétrécissement en disparaissant
                local pop = t < 0.12 and Lerp(t / 0.12, 1.6, 1) or Lerp((t - 0.12) / 0.88, 1, 0.85)
                -- un peu plus petit au loin
                local dist = oeil:Distance(monde)
                local echelle = pop * math.Clamp(700 / math.max(dist, 1), ECHELLE_MIN, 1.15)
                local alpha = t < 0.7 and 255 or 255 * (1 - (t - 0.7) / 0.3)

                local fort = c.valeur >= SEUIL_FORT
                local couleur = fort and COULEUR_FORT or COULEUR
                local police = fort and "NA.Degats.Fort" or "NA.Degats"

                local texte = tostring(c.valeur)
                surface.SetFont(police)
                local tw, th = surface.GetTextSize(texte)
                -- tout est dessiné en coordonnées positives (sinon le haut du chiffre est
                -- coupé), puis la matrice recentre le bloc sur le point d'ancrage
                local marge = EPAISSEUR + 4
                local bw, bh = tw + marge * 2, th + marge * 2

                local m = Matrix()
                m:Translate(Vector(ecran.x + c.dx * k - bw * echelle / 2, ecran.y - bh * echelle / 2, 0))
                m:Scale(Vector(echelle, echelle, 1))

                render.PushFilterMag(TEXFILTER.ANISOTROPIC)
                render.PushFilterMin(TEXFILTER.ANISOTROPIC)
                cam.PushModelMatrix(m, true)
                    -- ombre portée puis chiffre avec contour épais : lisible sur tous les fonds
                    draw.SimpleText(texte, police, marge + 3, marge + 4, Color(0, 0, 0, alpha * 0.6))
                    draw.SimpleTextOutlined(texte, police, marge, marge,
                        Color(couleur.r, couleur.g, couleur.b, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP,
                        EPAISSEUR, Color(CONTOUR.r, CONTOUR.g, CONTOUR.b, CONTOUR.a * alpha / 255))
                cam.PopModelMatrix()
                render.PopFilterMin()
                render.PopFilterMag()
            end
        end
    end
end)
