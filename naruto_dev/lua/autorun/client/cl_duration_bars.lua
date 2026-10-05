--========================================================
-- Barres de durée (CLIENT)
--
-- Une barre par technique qui dure (zone, buff, vol...), empilées au-dessus
-- de la barre de techniques : le nom de la technique juste au-dessus de sa
-- barre de temps. Plusieurs techniques à la fois = plusieurs barres.
--
-- Démarrage : NA_Lancer (_na_registre.lua) appelle NA_DemarrerDuree(id) quand un
-- jutsu part. Durée = stat "duree" de la technique à ton niveau (_na_niveaux_techniques.lua).
-- Images : materials/ui/hud/fight/duration_bar_back.png / duration_bar_base.png
--========================================================

-- Techniques dont la stat "duree" est SA durée (pas un étourdissement ni une portée)
local DUREES = {}
for _, id in ipairs({
    "katon_dome", "katon_souffle", "katon_tornade","katon_nuee", "futon_grand_ouragan", "katon_dragons", "suiton_prison", "raiton_zone", "suiton_pluie", "suiton_tsunami", "suiton_ocean", "doton_seisme", "doton_dragon", "doton_taupe", "doton_golem",
    "mokuton_protection", "mokuton_golem", "salamandre_dome", "salamandre_corps", "salamandre_tornade",
    "fuma_invisibilite", "fuma_aura", "kami_circle", "kami_bouclier", "jinton_bouclier", "jinton_laser",
    "kaguya_danse", "kaguya_legion", "chinoike_pluie", "chinoike_vortex", "hyuga_tourbillon",
    "kiminari_prison", "jiton_emergence", "jiton_nuage", "jiton_vortex", "senju_renfo", "senju_soin",
    "inkuton_moine", "bakuton_dragon", "futton_vapeur", "futton_cage", "futton_monde",
    "hyoton_dome", "shoton_armure",
}) do DUREES[id] = true end

-- Techniques qu'on peut COUPER avant la fin (re-lancer, E...) : id -> fonction vraie tant que la technique est active (état
-- posé par le serveur). Dès qu'elle devient fausse, la barre disparaît ; si elle n'est jamais devenue vraie (lancement refusé), aussi.
-- Une technique absente de cette liste garde sa barre jusqu'à la fin de sa durée.
local ACTIVES = {
    suiton_tsunami     = function(p) return p:GetNW2Float("NA_TsunamiFin", 0) > CurTime() end,   -- relancer ou E : on descend de la vague
    doton_taupe        = function(p) return p:GetNW2Bool("NA_Souterrain", false) end,            -- E : on ressort
    doton_golem        = function(p) return p:GetNW2Bool("NA_Golem", false) end,
    mokuton_golem      = function(p) return p:GetNW2Bool("NA_Golem", false) end,                  -- relancer : on redevient normal
    mokuton_protection = function(p) return p:GetNW2Bool("NA_Hobi", false) end,
    senju_renfo        = function(p) return p:GetNW2Bool("NA_SenjuRenfo", false) end,
    senju_soin         = function(p) return p:GetNW2Bool("NA_SenjuSoin", false) end,
    fuma_invisibilite  = function(p) return p:GetNWBool("IsInvisible", false) end,               -- un jutsu lancé fait réapparaître
}
local DELAI_VERIF = 1.5   -- secondes de grâce après le début de la barre pour que le serveur pose l'état

local ECART = 58 -- hauteur occupée par une barre + son nom (empilées vers le bas)

-- couleur de la barre par famille (sinon celle de la barre de techniques)
local COULEURS = {
    Salamandre = Color(165, 70, 230),
    Katon      = Color(255, 110, 40),
    Suiton     = Color(60, 150, 255),
   Inkuton = Color(255, 255, 255),
}

local MAT_FOND = Material("ui/hud/fight/duration_bar_back.png", "smooth")
local MAT_BASE = Material("ui/hud/fight/duration_bar_base.png", "smooth")

surface.CreateFont("NA.Duree.Nom", { font = "Roboto", size = 20, weight = 700 })
surface.CreateFont("NA.Duree.Temps", { font = "Roboto", size = 16, weight = 800 })

local actives = {} -- [id] = { debut, fin }

function NA_DemarrerDuree(id)
    if not DUREES[id] then return end
    local ply = LocalPlayer()
    local duree = NA_Stat and NA_Stat(ply, id, "duree", 0) or 0
    if duree <= 0 then return end

    -- pas assez de chakra : le serveur refuse le jutsu, donc pas de barre
    local cout = NA_Stat and NA_Stat(ply, id, "chakra", 0) or 0
    if cout > 0 and ply:GetNW2Float("NA_Chakra", NA_CHAKRA_MAX or 100) < cout then return end

    -- la barre commence quand les mudras sont finis
    local debut = CurTime() + (NA_Stat and NA_Stat(ply, id, "duree_mudra", 0) or 0)
    actives[id] = { debut = debut, fin = debut + duree }
end

hook.Add("HUDPaint", "NA_DureeBars", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then
        table.Empty(actives)
        return
    end

    local now = CurTime()
    local liste = {}
    for id, a in pairs(actives) do
        if now >= a.fin then
            actives[id] = nil
        elseif now >= a.debut then
            local actif = ACTIVES[id]
            if actif then
                if actif(ply) then
                    a.vu = true
                elseif a.vu or now > a.debut + DELAI_VERIF then
                    actives[id] = nil   -- coupée avant la fin (ou jamais partie)
                    continue
                end
            end
            liste[#liste + 1] = { id = id, a = a }
        end
    end
    table.sort(liste, function(p, q) return p.a.debut < q.a.debut end) -- la plus ancienne en bas

    -- à droite du viseur, comme dans la référence : "Temps Restant (Technique)" au-dessus,
    -- barre de 18 % de l'écran, secondes dedans
    local LARGEUR = math.floor(ScrW() * 0.2)
    local HAUTEUR = math.max(12, math.floor(LARGEUR * 16 / 352 * 1.5))
    local cx, haut = ScrW() * 0.68, ScrH() * 0.56
    local x = cx - LARGEUR / 2

    for i, e in ipairs(liste) do
        local y = haut + (i - 1) * ECART
        local reste = e.a.fin - now
        local part = math.Clamp(reste / (e.a.fin - e.a.debut), 0, 1)
        local info = NA_TechniqueParId and NA_TechniqueParId(e.id)
        local col = COULEURS[info and info.cat] or (NA_SkillBar and NA_SkillBar.Couleur(e.id)) or color_white

        draw.SimpleTextOutlined("Temps Restant (" .. (info and info.name or e.id) .. ")", "NA.Duree.Nom",
            cx, y - 4, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 200))

        -- fond, puis remplissage qui se vide de droite à gauche (couleur = famille de la technique)
        surface.SetMaterial(MAT_FOND)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(x - 6, y - 3, LARGEUR + 12, HAUTEUR + 6)

        render.SetScissorRect(x, y, x + LARGEUR * part, y + HAUTEUR, true)
        surface.SetMaterial(MAT_BASE)
        surface.SetDrawColor(col.r, col.g, col.b, 255)
        surface.DrawTexturedRect(x, y, LARGEUR, HAUTEUR)
        render.SetScissorRect(0, 0, 0, 0, false)

        draw.SimpleTextOutlined(string.format("%.1fs", reste), "NA.Duree.Temps", cx, y + HAUTEUR / 2,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
    end
end)
