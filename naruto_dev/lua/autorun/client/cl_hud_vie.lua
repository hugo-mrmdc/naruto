--========================================================
-- HUD de vie et de chakra (CLIENT), en bas à gauche
--
--   - portrait rond (base_hud_rework.png) avec la tête 3D du personnage,
--     cheveux et tête fusionnés compris ;
--   - pseudo, nuage décoratif ;
--   - barre de vie et barre de chakra (coups de pinceau), avec valeurs ;
--   - faim (optionnelle, si un script renseigne NW2Float "NA_Faim").
-- Images : materials/ui/hud/
--========================================================

--========================================================
-- RÉGLAGES (tailles à 1080p, tout est mis à l'échelle de l'écran)
--========================================================
local MARGE_X         = 10    -- distance au bord gauche
local MARGE_BAS       = 22    -- distance au bord bas
local TAILLE_PORTRAIT = 190   -- taille du cadre rond
local LARGEUR_BARRE   = 300   -- longueur visible des barres (après le portrait)
local HAUTEUR_BARRE   = 24
local ECART_BARRES    = 8
local TAILLE_NUAGE    = 1.15  -- échelle du nuage décoratif (image 248 x 75)

-- Cadrage du portrait (buste)
-- (cadre ~33 unités de haut : la tête en haut, les épaules et le haut du torse en bas)
local PORTRAIT_FOV      = 30
local PORTRAIT_DISTANCE = 62   -- distance de la caméra (plus grand = plus de torse, tête plus petite)
local PORTRAIT_HAUTEUR  = -6   -- centre du cadrage par rapport à la tête (négatif = plus de torse)

local CHAKRA_MAX     = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local AFFICHER_FAIM  = true   -- n'apparaît que si NW2Float "NA_Faim" existe (0 à 100)
local VITESSE_BARRE  = 6      -- vitesse à laquelle les barres suivent la valeur
local TRAINEE        = true   -- trace claire qui descend lentement après une perte de vie

-- Dans le gamemode Naruto RP, son propre HUD est utilisé
local ACTIF_DANS_NARUTORP = false
--========================================================

NA_HUD_VIE_ACTIF = true   -- lu par cl_sprint_chakra.lua (qui masque alors son ancienne jauge)

local function Actif()
    return ACTIF_DANS_NARUTORP or engine.ActiveGamemode() ~= "narutorp"
end

local mats = {}
local function Mat(nom)
    if not mats[nom] then mats[nom] = Material("ui/hud/" .. nom, "smooth mips") end
    return mats[nom]
end

local function CreerPolices()
    local k = ScrH() / 1080
    surface.CreateFont("NA.Hud.Nom",    { font = "Roboto", size = math.Round(19 * k), weight = 800 })
    surface.CreateFont("NA.Hud.Valeur", { font = "Roboto", size = math.Round(17 * k), weight = 700 })
end
CreerPolices()
hook.Add("OnScreenSizeChanged", "NA_HudVie_Polices", CreerPolices)

-- On cache la vie / armure de base de Garry's Mod
local CACHER = { CHudHealth = true, CHudBattery = true, CHudSuitPower = true }
hook.Add("HUDShouldDraw", "NA_HudVie_Cacher", function(nom)
    if CACHER[nom] and Actif() then return false end
end)

----------------------------------------------------------
-- Portrait : tête 3D du joueur dans le cadre rond
----------------------------------------------------------
-- Cercle intérieur du cadre, mesuré dans base_hud_rework.png (1254 x 1254)
local CADRE = 1254
local CERCLE_X, CERCLE_Y, CERCLE_R = 644, 578, 468

-- Le portrait est un DModelPanel posé sur le HUD (même principe que les icônes
-- du menu F4, qui affichent bien la tête), découpé en rond avec le stencil.
-- Tête et cheveux : modèles séparés publiés par sv_playerskin.lua
-- (NW2String "NA_TeteModele" / "NA_CheveuxModele" et leurs couleurs).
local panneau             -- DModelPanel du portrait
local extras = {}         -- tête, cheveux... fusionnés au modèle du panneau
local signature = ""      -- change quand le modèle, la tête ou les cheveux changent
local derniereImage = 0   -- dernière image où le HUD a été dessiné

local function Signature(ply)
    return table.concat({
        ply:GetModel(), ply:GetSkin(),
        ply:GetNW2String("NA_TeteModele", ""), ply:GetNW2String("NA_CheveuxModele", ""),
        ply:GetNW2String("NA_Yeux", ""),   -- yeux changés (Ketsuryugan...) : portrait refait
    }, "|")
end

local function SupprimerExtras()
    for _, cs in ipairs(extras) do if IsValid(cs) then cs:Remove() end end
    extras = {}
end

-- Disque (pour découper le portrait en rond avec le stencil)
-- (sommets dans le sens des aiguilles d'une montre, sinon DrawPoly ne dessine rien)
local function Disque(cx, cy, r)
    local poly = {}
    for i = 0, 47 do
        local a = math.rad(i / 48 * -360)
        poly[#poly + 1] = { x = cx + math.sin(a) * r, y = cy + math.cos(a) * r }
    end
    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawPoly(poly)
end

local cvBrut = CreateClientConVar("na_hud_portrait_brut", "0", false, false,
    "1 = portrait du HUD sans découpe ronde (test)")

local function CreerPanneau()
    panneau = vgui.Create("DModelPanel")
    panneau:ParentToHUD()
    panneau:SetMouseInputEnabled(false)
    panneau:SetKeyboardInputEnabled(false)
    panneau:SetFOV(PORTRAIT_FOV)
    panneau:SetAmbientLight(Color(110, 105, 100))
    panneau:SetDirectionalLight(BOX_FRONT, Color(255, 245, 235))
    panneau:SetDirectionalLight(BOX_TOP, Color(200, 200, 200))
    panneau:SetVisible(false)

    -- caméra face au buste
    function panneau:LayoutEntity(ent)
        ent:SetAngles(angle_zero)
        self:RunAnimation()

        local os = ent:LookupBone("ValveBiped.Bip01_Head1")
        local tete = os and ent:GetBonePosition(os)
        if not tete or tete == ent:GetPos() then tete = ent:GetPos() + Vector(0, 0, 64) end

        local vise = tete + Vector(0, 0, PORTRAIT_HAUTEUR)
        self:SetLookAt(vise)
        self:SetCamPos(vise + Vector(PORTRAIT_DISTANCE, 0, 2))   -- le modèle regarde vers +X
    end

    -- tête, cheveux... fusionnés
    function panneau:PostDrawModel(ent)
        for _, cs in ipairs(extras) do
            if IsValid(cs) then
                local c = cs.Couleur or Vector(255, 255, 255)
                render.SetColorModulation(c.x / 255, c.y / 255, c.z / 255)
                cs:DrawModel()
            end
        end
        render.SetColorModulation(1, 1, 1)
    end

    -- découpe ronde
    local peindre = panneau.Paint
    function panneau:Paint(w, h)
        if cvBrut:GetBool() then return peindre(self, w, h) end

        render.ClearStencil()
        render.SetStencilEnable(true)
        render.SetStencilWriteMask(255)
        render.SetStencilTestMask(255)
        render.SetStencilReferenceValue(1)
        render.SetStencilCompareFunction(STENCIL_ALWAYS)
        render.SetStencilPassOperation(STENCIL_REPLACE)
        render.SetStencilFailOperation(STENCIL_KEEP)
        render.SetStencilZFailOperation(STENCIL_KEEP)

        render.OverrideColorWriteEnable(true, false)
        Disque(w / 2, h / 2, w / 2)
        render.OverrideColorWriteEnable(false, false)

        render.SetStencilCompareFunction(STENCIL_EQUAL)
        render.SetStencilPassOperation(STENCIL_KEEP)

        peindre(self, w, h)

        render.SetStencilEnable(false)
    end
end

local function AjouterPiece(ent, modele, couleur)
    if not modele or modele == "" then return end
    local cs = ClientsideModel(modele, RENDERGROUP_OPAQUE)
    if not IsValid(cs) then return end
    cs:SetNoDraw(true)
    cs:SetParent(ent)
    cs:AddEffects(EF_BONEMERGE)
    cs.Couleur = couleur
    extras[#extras + 1] = cs
    return cs
end

local function ConstruirePortrait(ply)
    if not IsValid(panneau) then CreerPanneau() end

    SupprimerExtras()
    panneau:SetModel(ply:GetModel())
    local ent = panneau:GetEntity()
    if not IsValid(ent) then return end

    ent:SetSkin(ply:GetSkin())
    for b = 0, ply:GetNumBodyGroups() - 1 do ent:SetBodygroup(b, ply:GetBodygroup(b)) end
    local seq = ent:LookupSequence("idle_all_01")
    if seq and seq >= 0 then ent:ResetSequence(seq) end

    local tete = AjouterPiece(ent, ply:GetNW2String("NA_TeteModele", ""), ply:GetNW2Vector("NA_TeteCouleur", Vector(255, 255, 255)))
    if tete and NA_MateriauxTete then NA_MateriauxTete(tete, ply) end   -- visage teinté + yeux (cl_playerskin.lua)
    AjouterPiece(ent, ply:GetNW2String("NA_CheveuxModele", ""), ply:GetNW2Vector("NA_CheveuxCouleur", Vector(255, 255, 255)))

    -- autres éléments fusionnés au joueur (masque, ailes...) s'il y en a
    local deja = {}
    for _, cs in ipairs(extras) do deja[string.lower(cs:GetModel() or "")] = true end
    for _, enfant in ipairs(ply:GetChildren()) do
        local mdl = IsValid(enfant) and enfant:GetModel()
        if mdl and mdl ~= "" and enfant:IsEffectActive(EF_BONEMERGE) and not enfant:GetNoDraw()
            and not deja[string.lower(mdl)] and string.lower(mdl) ~= "models/clan/ame/kami/fauxkami.mdl" then   -- la faux de papier (vol) n'a pas sa place dans le portrait
            local c = enfant:GetColor()
            AjouterPiece(ent, mdl, Vector(c.r, c.g, c.b))
        end
    end
end

local function DessinerPortrait(ply, x, y, taille)
    local sig = Signature(ply)
    if sig ~= signature or not IsValid(panneau) then
        signature = sig
        ConstruirePortrait(ply)
    end

    -- fond et cadre (le panneau du buste s'affiche par-dessus)
    surface.SetMaterial(Mat("base_hud_rework.png"))
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(x, y, taille, taille)

    if not IsValid(panneau) then return end
    local e = taille / CADRE
    local cx, cy, r = x + CERCLE_X * e, y + CERCLE_Y * e, CERCLE_R * e
    panneau:SetPos(math.Round(cx - r), math.Round(cy - r))
    panneau:SetSize(math.Round(r * 2), math.Round(r * 2))
    panneau:SetVisible(true)
    derniereImage = RealTime()
end

-- le panneau est caché dès que le HUD n'est plus dessiné (mort, menu, éditeur...)
hook.Add("Think", "NA_HudVie_Portrait", function()
    if IsValid(panneau) and panneau:IsVisible() and RealTime() - derniereImage > 0.1 then
        panneau:SetVisible(false)
    end
end)

----------------------------------------------------------
-- Barres
----------------------------------------------------------
local affVie, affChakra, traineeVie, affBouclier = nil, nil, nil, 0

-- Barre "coup de pinceau" : fond, trace éventuelle, puis remplissage coupé à la fraction
local function Barre(fond, plein, x, y, w, h, frac, fracTrainee)
    surface.SetDrawColor(255, 255, 255, 230)
    surface.SetMaterial(Mat(fond))
    surface.DrawTexturedRect(x, y, w, h)

    if fracTrainee and fracTrainee > frac then
        surface.SetMaterial(Mat(plein))
        surface.SetDrawColor(255, 255, 255, 110)
        surface.DrawTexturedRectUV(x, y, w * fracTrainee, h, 0, 0, fracTrainee, 1)
    end

    if frac > 0 then
        surface.SetMaterial(Mat(plein))
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRectUV(x, y, w * frac, h, 0, 0, frac, 1)
    end
end

local function Texte(txt, police, x, y, alignX, alignY, couleur)
    draw.SimpleTextOutlined(txt, police, x, y, couleur or color_white, alignX, alignY, 1, Color(0, 0, 0, 200))
end

hook.Add("HUDPaint", "NA_HudVie", function()
    if not Actif() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if NA_EditeurCameraActive then return end   -- éditeur de placement ouvert

    local k = ScrH() / 1080
    local dt = FrameTime()

    local vie, vieMax = math.max(ply:Health(), 0), math.max(ply:GetMaxHealth(), 1)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)

    affVie = affVie and Lerp(math.min(dt * VITESSE_BARRE, 1), affVie, vie) or vie
    affChakra = affChakra and Lerp(math.min(dt * VITESSE_BARRE, 1), affChakra, chakra) or chakra
    traineeVie = math.max(traineeVie and math.Approach(traineeVie, affVie, dt * vieMax * 0.35) or vie, affVie)

    -- repères
    local tp = TAILLE_PORTRAIT * k
    local px, py = MARGE_X * k, ScrH() - MARGE_BAS * k - tp
    local bh = HAUTEUR_BARRE * k
    local bx = px + tp * 0.62                          -- les barres partent sous le portrait
    local bw = (tp * 0.38) + LARGEUR_BARRE * k
    local by1 = py + tp * 0.50
    local by2 = by1 + bh + ECART_BARRES * k
    local finBarres = bx + bw

    -- 1. nuage, derrière tout
    local nw, nh = 248 * TAILLE_NUAGE * k, 75 * TAILLE_NUAGE * k
    surface.SetMaterial(Mat("nuage_deco.png"))
    surface.SetDrawColor(255, 255, 255, 245)
    surface.DrawTexturedRect(px + tp * 0.72, py + tp * 0.06, nw, nh)

    -- 2. barres
    Barre("bar_vie_back.png", "bar_vie.png", bx, by1, bw, bh,
        math.Clamp(affVie / vieMax, 0, 1), TRAINEE and math.Clamp(traineeVie / vieMax, 0, 1) or nil)

    -- bouclier (Jinton...) : voile clair par-dessus la barre de vie, proportionnel au bouclier
    local bouclier = ply:GetNW2Float("NA_Bouclier", 0)
    affBouclier = Lerp(math.min(dt * VITESSE_BARRE, 1), affBouclier or 0, bouclier)
    if affBouclier > 0.5 then
        local frac = math.Clamp(affBouclier / vieMax, 0, 1)
        surface.SetMaterial(Mat("bar_vie.png"))
        surface.SetDrawColor(235, 245, 255, 200)
        surface.DrawTexturedRectUV(bx, by1, bw * frac, bh, 0, 0, frac, 1)
    end
    Barre("bar_chakra_back.png", "bar_chakra.png", bx, by2, bw, bh, math.Clamp(affChakra / CHAKRA_MAX, 0, 1))

    -- 3. portrait par-dessus le début des barres
    DessinerPortrait(ply, px, py, tp)

    -- 4. textes
    local tx = px + tp * 0.95
    Texte(ply:Nick(), "NA.Hud.Nom", tx, by1 - 3 * k, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM, Color(250, 245, 235))

    local texteVie = string.format("%d / %d", vie, vieMax)
    if bouclier > 0 then texteVie = texteVie .. string.format("  (+%d)", math.ceil(bouclier)) end
    Texte(texteVie, "NA.Hud.Valeur", finBarres + 10 * k, by1 + bh / 2,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, bouclier > 0 and Color(225, 240, 255) or color_white)
    Texte(string.format("%d / %d", math.Round(chakra), CHAKRA_MAX), "NA.Hud.Valeur", finBarres + 10 * k, by2 + bh / 2,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, ply:GetNW2Bool("NA_ChakraRun", false) and Color(150, 215, 255) or color_white)

    -- 5. faim, sous les barres à droite du portrait
    if AFFICHER_FAIM then
        local faim = ply:GetNW2Float("NA_Faim", -1)
        if faim >= 0 then
            local ti = 26 * k
            local ix, iy = px + tp * 0.86, by2 + bh + 4 * k
            surface.SetMaterial(Mat("hud_eat.png"))
            surface.SetDrawColor(255, 255, 255, 255)
            surface.DrawTexturedRect(ix, iy, ti, ti)
            Texte(math.Round(faim) .. "%", "NA.Hud.Valeur", ix + ti + 6 * k, iy + ti / 2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
end)

hook.Add("ShutDown", "NA_HudVie_Nettoyage", function()
    SupprimerExtras()
    if IsValid(panneau) then panneau:Remove() end
end)

-- Diagnostic du portrait : na_hud_portrait_info
concommand.Add("na_hud_portrait_info", function()
    local ply = LocalPlayer()
    print("[HUD] modèle joueur : " .. ply:GetModel())
    print("[HUD] tête : " .. ply:GetNW2String("NA_TeteModele", "(aucune)") ..
        " | cheveux : " .. ply:GetNW2String("NA_CheveuxModele", "(aucun)"))
    local ent = IsValid(panneau) and panneau:GetEntity()
    print("[HUD] panneau : " .. (IsValid(panneau) and ("ok, visible=" .. tostring(panneau:IsVisible())
        .. " pos=" .. panneau:GetX() .. "," .. panneau:GetY() .. " taille=" .. panneau:GetWide()) or "NON CRÉÉ"))
    print("[HUD] modèle du portrait : " .. (IsValid(ent) and ent:GetModel() or "aucun"))
    for _, cs in ipairs(extras) do print("[HUD]   + " .. tostring(IsValid(cs) and cs:GetModel())) end
end)
