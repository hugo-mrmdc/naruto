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
    "katon_dome", "katon_souffle", "katon_tornade","katon_nuee", "futon_grand_ouragan", "katon_dragons", "suiton_prison", "raiton_zone", "suiton_pluie", "suiton_tsunami", "doton_seisme", "doton_dragon", "doton_taupe",
    "mokuton_protection", "mokuton_golem", "salamandre_dome", "salamandre_corps", "salamandre_tornade",
    "fuma_invisibilite", "fuma_aura", "kami_circle", "kami_bouclier", "jinton_bouclier", "jinton_laser",
    "kaguya_danse", "kaguya_legion", "chinoike_pluie", "chinoike_vortex", "hyuga_tourbillon",
    "kiminari_prison", "jiton_emergence", "jiton_nuage", "jiton_vortex", "senju_renfo", "senju_soin",
    "inkuton_moine", "bakuton_dragon", "futton_vapeur", "futton_cage", "futton_monde",
    "hyoton_dome", "shoton_armure",
}) do DUREES[id] = true end

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
