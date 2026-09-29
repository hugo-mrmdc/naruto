--========================================================
-- Senju : Ermite naturel (CLIENT)
--
-- Lancement depuis la barre de techniques, et AFFICHAGE de l'aura + du tatouage sur chaque
-- joueur qui l'a (NW2Bool "NA_SenjuErmite", sv_senju_ermite.lua) : tout le monde les voit.
--========================================================


local MARQUE_PATCH_VERSION = "V7.8-progressive-load"
if NA_SenjuFlexLoader then NA_SenjuFlexLoader.ClosePending() end
local FaceShellFlex = include("autorun/client/senju/face_shell_flex.lua")
NA_SenjuFlexLoader = FaceShellFlex
print("[MarquePatch] chargé", MARQUE_PATCH_VERSION)

--========================================================
-- RÉGLAGES
--========================================================
local FX = "ermite_naturel_pat"   -- particles/patlick_atgparticules.pcf (avec ses variantes _add, _add2)

-- true = marque affichée sur le visage. false = aucune marque (aura seule) : ni la vraie texture de
-- peau ni les marques flottantes n'ont donné un résultat satisfaisant, désactivées en attendant une
-- meilleure piste (voir le commentaire plus bas, "PISTE ABANDONNÉE").
local AFFICHER_MARQUE = false
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.senju_ermite = function()
    net.Start("senju_ermite_cast")
    net.SendToServer()
end

game.AddParticles("particles/patlick_atgparticules.pcf")
PrecacheParticleSystem(FX)

local actives = {}   -- joueur -> système de particules

local function Porte(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_SenjuErmite", false)
        and not ply:IsDormant() and not ply:GetNWBool("IsInvisible", false)
end

local function Arreter(ply)
    local ps = actives[ply]
    if ps and ps:IsValid() then ps:StopEmission() end   -- les dernières particules finissent leur vie
    actives[ply] = nil
end

hook.Add("Think", "NA_SenjuErmite_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local ps = actives[ply]
        if Porte(ply) then
            if not (ps and ps:IsValid()) then
                -- centrée sur le corps (et non sur les pieds)
                actives[ply] = CreateParticleSystem(ply, FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, ply:OBBMaxs().z * 0.45))
            end
        elseif ps then
            Arreter(ply)
        end
    end

    for ply in pairs(actives) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)

----------------------------------------------------------
-- Marques d'ermite sur le visage (yeux + front), texture atg/tatoo/ermite_naturel du workshop
-- 3676634351. 3 petits quads PLATS (front, œil gauche, œil droit), posés et orientés séparément sur
-- le visage à chaque image, collés à l'attache "eyes" de la tête. Actuellement désactivés
-- (AFFICHER_MARQUE = false, tout en haut).
----------------------------------------------------------
local MARQUE = Material("naruto_dev/marques/ermite_naturel_visible")
local COULEUR = Color(0, 0, 0)   -- marque noire (la texture d'origine est blanche, la couleur la teinte)
local FONDU = 1   -- secondes pour que la marque apparaisse

-- Réglages de PLACEMENT : modifiables en jeu avec le menu "na_marque_menu" (ci-dessous), qui affiche
-- un aperçu en direct sur toi. Une fois satisfait, le bouton "Copier les valeurs" du menu met le
-- nouveau bloc REGL dans le presse-papiers : colle-le ici pour que ce soit le réglage par défaut.
local REGL = {
    ECHELLE = 0.0048877118644068,
    HAUT = -1.65,
    PAD = 0,

    -- FRONT
    FRONT_AVANT = -3.98,
    FRONT_ANGLE = 0,
    FRONT_INCLINAISON = 24.92,
    FRONT_ROULIS = 0,
    FRONT_DECALAGE_X = 0,
    FRONT_DECALAGE_Y = 2.12,
    FRONT_COURBURE = 0,   -- 0 = plat (comme avant), plus grand = le morceau se bombe vers l'avant

    OEIL_GAUCHE = {
        AVANT = -2.8,
        ANGLE = -23.9,
        INCLINAISON = 20.85,
        ROULIS = -144.92,
        DECALAGE_X = 0.38,
        DECALAGE_Y = 2.97,
        DECALAGE_AVANT = 0,
        COURBURE = 0,
    },

    OEIL_DROIT = {
        AVANT = -2.8,
        ANGLE = 23,
        INCLINAISON = 20,
        ROULIS = 144,
        DECALAGE_X = -0.4,
        DECALAGE_Y = 2.97,
        DECALAGE_AVANT = 0,
        COURBURE = 0,
    },
}

-- Zone de chaque morceau dans la texture 2048x2048 (mesurée sur ermite_naturel.png) :
--   px = { xmin, xmax, ymin, ymax }, cle = quel sous-réglage de REGL utiliser (nil = front, pas de rotation)
local MORCEAUX = {
    { px = { 335,  833,  836, 1605 }, cle = "OEIL_GAUCHE" },
    { px = { 1189, 1720, 813,  1600 }, cle = "OEIL_DROIT" },
    { px = { 865,  1154, 90,   609 } },   -- front
}

-- Repère (pixel) sur lequel toutes les positions sont calées : le milieu des deux marques d'yeux
local REF_X, REF_Y = 1019, 1213

local debuts = {}   -- joueur -> moment où l'ermite est devenu actif (pour le fondu)
local apercu = false   -- true tant que le menu de réglage est ouvert : la marque s'affiche sur toi sans avoir à lancer la technique
local testRougeDirect = false -- diagnostic V6 : force toute la texture FACE en rouge via le même chemin de mutation

--========================================================
-- TATOUAGE DIRECTEMENT DANS LA TEXTURE DE PEAU
--
-- Le visage "atg/face/face" est une texture blanche 512x512. On fabrique donc une
-- nouvelle texture 512x512 : fond blanc + les 3 morceaux noirs de la marque, placés
-- dans l'UV REEL de models/head/face_N.mdl. Cette texture devient le $basetexture
-- d'un VertexLitGeneric teinté avec la couleur de peau du personnage.
--
-- Résultat : aucune plaque 3D. Le tattoo est réellement échantillonné par les UV du
-- mesh du visage : nez/joues/front, animation, profil et éclairage suivent naturellement.
--========================================================
local AFFICHER_MARQUE_PEAU = true
local RT_TAILLE = 512
local RT_MARQUE = GetRenderTarget("na_senju_ermite_face_512", RT_TAILLE, RT_TAILLE)
local RT_PRET = false
local RT_SALE = true

-- Placement dans l'UV 512x512 du mesh face_N.
-- Ces valeurs ont été obtenues à partir de l'UV réel de face_1.mdl : les deux grandes
-- formes entourent les îlots des yeux et le symbole central tombe sur le front.
-- { x, y, largeur, hauteur, source={xmin,xmax,ymin,ymax dans la texture 2048} }
local UV_MORCEAUX = {
    { x = 120, y = 210, w = 100, h = 185, source = { 335, 833, 836, 1605 } },   -- côté gauche de la texture
    { x = 292, y = 210, w = 100, h = 185, source = { 1189, 1720, 813, 1600 } }, -- côté droit
    { x = 220, y = 105, w = 72,  h = 130, source = { 865, 1154, 90, 609 } },    -- front
}

local function GenererTexturePeauErmite()
    if not RT_SALE then return end

    render.PushRenderTarget(RT_MARQUE)
    render.Clear(255, 255, 255, 255)
    cam.Start2D()
        surface.SetMaterial(MARQUE)
        surface.SetDrawColor(0, 0, 0, 255)

        for _, m in ipairs(UV_MORCEAUX) do
            local src = m.source
            surface.DrawTexturedRectUV(
                m.x, m.y, m.w, m.h,
                src[1] / 2048, src[3] / 2048,
                src[2] / 2048, src[4] / 2048
            )
        end
    cam.End2D()
    render.PopRenderTarget()

    RT_PRET = true
    RT_SALE = false
end

-- Les appels de rendu vers un RT doivent être faits pendant une vraie phase de rendu.
hook.Add("PostRender", "NA_SenjuErmite_GenererPeau", function()
    if RT_SALE then GenererTexturePeauErmite() end
end)

local MATS_PEAU_ERMITE = {}
local function CleCouleur(c)
    return string.format("%d_%d_%d", c[1] or 255, c[2] or 255, c[3] or 255)
end
local function TeintePeau(c)
    return string.format("[%.3f %.3f %.3f]", (c[1] or 255) / 255, (c[2] or 255) / 255, (c[3] or 255) / 255)
end

local function MateriauPeauErmite(p)
    local cle = CleCouleur(p.peau)
    if not MATS_PEAU_ERMITE[cle] then
        local nom = "na_senju_ermite_peau_" .. cle

        -- Ne passe pas le nom du RenderTarget directement dans les KeyValues.
        -- Sur certains builds/addons Source, le parseur peut traiter la valeur comme
        -- une chaîne de matériau au lieu d'une ITexture. On crée donc le matériau
        -- avec une texture valide puis on injecte explicitement l'ITexture du RT.
        local mat = CreateMaterial(nom, "VertexLitGeneric", {
            ["$basetexture"] = "atg/face/face",
            ["$lightwarptexture"] = "atg/shared/toon",
            ["$color2"] = TeintePeau(p.peau),
            ["$model"] = "1",
        })
        mat:SetTexture("$basetexture", RT_MARQUE)
        MATS_PEAU_ERMITE[cle] = mat
    else
        -- Sécurité après un hot-reload : le matériau peut survivre alors que le RT
        -- a été recréé. On réinjecte donc toujours l'ITexture courante.
        MATS_PEAU_ERMITE[cle]:SetTexture("$basetexture", RT_MARQUE)
    end
    return MATS_PEAU_ERMITE[cle]
end

local function TrouverSlotFace(tete)
    if tete.NA_FaceSubIndex ~= nil then return tete.NA_FaceSubIndex end
    for i, chemin in ipairs(tete:GetMaterials()) do
        local nom = string.lower(string.match(chemin, "[^/\\]+$") or "")
        if nom == "face" then
            tete.NA_FaceSubIndex = i - 1
            return i - 1
        end
    end
end

-- V7 : le shell skinné remplace la mutation du matériau.
-- Retire aussi l'ancien hook lorsqu'on recharge le fichier après une V6.
hook.Remove("NA_GetFaceDrawMutation", "NA_SenjuErmite_TatouagePeau")

-- Quand la marque n'est plus active, le matériau source est déjà restauré immédiatement après
-- chaque DrawModel par NA_DrawModelAvecFaceMutation ; aucun SetSubMaterial n'est nécessaire.
hook.Add("NA_PostDrawTetePerso", "NA_SenjuErmite_EtatMutation", function(ply, tete)
    if not IsValid(tete) then return end
    if not (AFFICHER_MARQUE_PEAU and IsValid(ply) and (Porte(ply) or (apercu and ply == LocalPlayer()))) then
        tete.NA_SenjuTattooActif = nil
    end
end)



--========================================================
-- V7 : SECONDE PEAU SKINNEE SUR LE VRAI MESH "face"
--
-- Les overrides de matériau du modèle sont neutralisés dans ce projet. On récupère donc
-- les vrais triangles du mesh atg/face/face via util.GetModelMeshes, on conserve leurs UV,
-- et on les reskinne chaque frame avec les matrices d'os de la tête visible.
-- Seuls les triangles dont les UV croisent les zones de marque sont gardés.
-- Le shell est décalé de 0.018 unité le long de la normale de chaque triangle pour éviter
-- le z-fighting. Le fond de la texture est transparent : seule la marque noire est rendue.
--========================================================
local RT_OVERLAY = GetRenderTargetEx("na_senju_ermite_overlay_v73", RT_TAILLE, RT_TAILLE,
    RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, 0, 0, IMAGE_FORMAT_RGBA8888)
local RT_OVERLAY_PRET = false
local RT_OVERLAY_SALE = true
-- La marque noire est un découpage : les pixels transparents ne doivent pas
-- participer au test de profondeur ni montrer les faces internes du visage.
local MAT_OVERLAY = CreateMaterial("na_senju_ermite_overlay_mat_v74", "UnlitGeneric", {
    ["$basetexture"] = "vgui/white",
    ["$alphatest"] = "1",
    ["$alphatestreference"] = "0.5",
    ["$vertexcolor"] = "1",
    ["$nocull"] = "0",
})
MAT_OVERLAY:SetTexture("$basetexture", RT_OVERLAY)
-- L'affichage 2D du diagnostic conserve la transparence progressive du RT.
local MAT_OVERLAY_PREVIEW = CreateMaterial("na_senju_overlay_preview_v74", "UnlitGeneric", {
    ["$basetexture"] = "vgui/white",
    ["$translucent"] = "1",
    ["$vertexcolor"] = "1",
    ["$vertexalpha"] = "1",
})
MAT_OVERLAY_PREVIEW:SetTexture("$basetexture", RT_OVERLAY)

local function GenererOverlayTattoo()
    if not RT_OVERLAY_SALE then return end
    render.PushRenderTarget(RT_OVERLAY)
    local clipping = DisableClipping(true)
    render.OverrideAlphaWriteEnable(true, true)
    render.SetWriteDepthToDestAlpha(false)
    render.OverrideBlend(true, BLEND_SRC_ALPHA, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD,
        BLEND_ONE, BLEND_ONE_MINUS_SRC_ALPHA, BLENDFUNC_ADD)
    render.Clear(0, 0, 0, 0)
    cam.Start2D()
        surface.SetMaterial(MARQUE)
        surface.SetDrawColor(0, 0, 0, 255)
        for _, m in ipairs(UV_MORCEAUX) do
            local src = m.source
            surface.DrawTexturedRectUV(
                m.x, m.y, m.w, m.h,
                src[1] / 2048, src[3] / 2048,
                src[2] / 2048, src[4] / 2048
            )
        end
    cam.End2D()
    render.OverrideBlend(false)
    render.SetWriteDepthToDestAlpha(true)
    render.OverrideAlphaWriteEnable(false)
    DisableClipping(clipping)
    render.PopRenderTarget()
    MAT_OVERLAY:SetTexture("$basetexture", RT_OVERLAY)
    RT_OVERLAY_PRET = true
    RT_OVERLAY_SALE = false
end

hook.Add("PostRender", "NA_SenjuErmite_GenererOverlayV7", function()
    if RT_OVERLAY_SALE then GenererOverlayTattoo() end
end)

local FACE_SHELL_CACHE = {}
-- Libère les ressources GPU aussi au rechargement du fichier.
for _, cached in pairs(NA_SenjuShellMeshes or {}) do
    if cached.mesh then cached.mesh:Destroy() end
end
NA_SenjuShellMeshes = {}
local shellMeshes = NA_SenjuShellMeshes
hook.Add("EntityRemoved", "NA_SenjuShellMeshCleanup", function(ent)
    local cached = shellMeshes[ent]
    if cached and cached.mesh then cached.mesh:Destroy() end
    shellMeshes[ent] = nil
end)
local SHELL_EPSILON = 0.018
local shellDebug = false
local MAT_SHELL_DEBUG = CreateMaterial("na_senju_shell_debug", "UnlitGeneric", {
    ["$basetexture"] = "vgui/white",
    ["$vertexcolor"] = "1",
    ["$nocull"] = "1",
})

local function UVIntersectsTattoo(a, b, c)
    local minU = math.min(a.u or 0, b.u or 0, c.u or 0)
    local maxU = math.max(a.u or 0, b.u or 0, c.u or 0)
    local minV = math.min(a.v or 0, b.v or 0, c.v or 0)
    local maxV = math.max(a.v or 0, b.v or 0, c.v or 0)
    for _, r in ipairs(UV_MORCEAUX) do
        local u0, v0 = r.x / RT_TAILLE, r.y / RT_TAILLE
        local u1, v1 = (r.x + r.w) / RT_TAILLE, (r.y + r.h) / RT_TAILLE
        if maxU >= u0 and minU <= u1 and maxV >= v0 and minV <= v1 then
            return true
        end
    end
    return false
end

local function BuildFaceShellData(model)
    model = string.lower(model or "")
    if model == "" then return end
    if FACE_SHELL_CACHE[model] ~= nil then return FACE_SHELL_CACHE[model] or nil end

    local meshes, bind = util.GetModelMeshes(model, 0, 0, 0)
    if not meshes or not bind then
        FACE_SHELL_CACHE[model] = false
        return
    end

    local tris = {}
    for _, md in ipairs(meshes) do
        local mat = string.lower(md.material or "")
        local leaf = string.match(mat, "[^/\\]+$") or mat
        if leaf == "face" then
            local t = md.triangles or {}
            for i = 1, #t - 2, 3 do
                if i % 192 == 1 then coroutine.yield() end
                local a, b, c = t[i], t[i + 1], t[i + 2]
                if a and b and c and UVIntersectsTattoo(a, b, c) then
                    tris[#tris + 1] = { a, b, c }
                end
            end
        end
    end

    local invBind = {}
    for bone, bp in pairs(bind) do
        if bp and bp.matrix then invBind[bone] = bp.matrix:GetInverse() end
    end

    -- studiohdr_t / mstudiobone_t : poseToBone est déjà la transformation
    -- modèle -> os. La lire directement évite d'inverser un repère ambigu.
    local bindSource = "util inverse"
    local mdl = file.Open(model, "rb", "GAME")
    if mdl then
        local signature = mdl:Read(4)
        local version = mdl:ReadLong()
        if signature == "IDST" and version >= 44 and version <= 49 and mdl:Size() >= 164 then
            mdl:Seek(156)
            local count, offset = mdl:ReadLong(), mdl:ReadLong()
            if count > 0 and count <= 256 and offset >= 0 and offset + count * 216 <= mdl:Size() then
                for bone = 0, count - 1 do
                    mdl:Seek(offset + bone * 216 + 96)
                    local rows = {}
                    for row = 1, 3 do
                        rows[row] = { mdl:ReadFloat(), mdl:ReadFloat(), mdl:ReadFloat(), mdl:ReadFloat() }
                    end
                    rows[4] = { 0, 0, 0, 1 }
                    invBind[bone] = Matrix(rows)
                end
                bindSource = "MDL poseToBone"
            end
        end
        mdl:Close()
    end

    local flexData, flexError = FaceShellFlex.Load(model, coroutine.yield)
    local flexMatched = 0
    if flexData then
        for ti, tri in ipairs(tris) do
            if ti % 64 == 0 then coroutine.yield() end
            for _, v in ipairs(tri) do
                v.naFlex = flexData.vertices[FaceShellFlex.Key(v)]
                if v.naFlex then flexMatched = flexMatched + 1 end
            end
        end
    else
        ErrorNoHalt("[MarqueV7] flex load: " .. tostring(flexError) .. "\n")
    end
    local rigidBone, rigid = nil, true
    for _, tri in ipairs(tris) do
        for _, v in ipairs(tri) do
            local w = v.weights
            if not w or #w ~= 1 or math.abs(w[1].weight - 1) > 0.00001 then
                rigid = false
            elseif rigidBone == nil then rigidBone = w[1].bone
            elseif rigidBone ~= w[1].bone then rigid = false end
        end
    end
    local data = { triangles = tris, invBind = invBind, bind = bind, bindSource = bindSource,
        rigidBone = rigid and rigidBone or nil,
        flexData = flexData, flexError = flexError, flexMatched = flexMatched }
    FACE_SHELL_CACHE[model] = data
    print("[MarqueV7] shell", model, "triangles:", #tris, "bones:", table.Count(invBind))
    return data
end

-- Le rendu ne lit plus les fichiers MDL/VVD : il demande une préparation.
local pendingShells = {}
local preparePeakMS = 0
local function GetFaceShellData(model)
    model = string.lower(model or "")
    if model == "" then return end
    if FACE_SHELL_CACHE[model] ~= nil then return FACE_SHELL_CACHE[model] or nil end
    if not pendingShells[model] then
        pendingShells[model] = coroutine.create(function() BuildFaceShellData(model) end)
    end
end

hook.Add("Think", "NA_SenjuShellPrepare", function()
    -- Budget coopératif : les boucles Lua rendent la main par petits lots.
    -- GetModelMeshes reste un appel moteur indivisible.
    local deadline = SysTime() + 0.001
    for model, task in pairs(pendingShells) do
        repeat
            local started = SysTime()
            local ok, err = coroutine.resume(task)
            preparePeakMS = math.max(preparePeakMS, (SysTime() - started) * 1000)
            if not ok then
                FACE_SHELL_CACHE[model] = false
                ErrorNoHalt("[MarqueV7] preparation: " .. tostring(err) .. "\n")
            end
            if not ok or coroutine.status(task) == "dead" then
                pendingShells[model] = nil
                break
            end
        until SysTime() >= deadline
        if SysTime() >= deadline then break end
    end
end)

timer.Create("NA_SenjuShellPrewarm", 1, 0, function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local head = NA_GetTeteRendue and NA_GetTeteRendue(ply)
    if IsValid(head) then GetFaceShellData(head:GetModel()) end
end)

local function SkinVertex(ent, v, transforms, normalProbe)
    local pos = normalProbe and (v.pos + v.normal) or v.pos
    local weights = v.weights
    if not weights or #weights == 0 then
        -- Les positions extraites sont dans le repère du modèle, pas de Head1.
        return ent:LocalToWorld(pos)
    end

    local out = Vector(0, 0, 0)
    local total = 0
    for _, bw in ipairs(weights) do
        local w = bw.weight or 0
        local bone = bw.bone
        if w > 0 and bone ~= nil then
            local transform = transforms[bone]
            if transform then
                local p = transform * pos
                out.x = out.x + p.x * w
                out.y = out.y + p.y * w
                out.z = out.z + p.z * w
                total = total + w
            end
        end
    end
    if total <= 0 then return ent:LocalToWorld(pos) end
    if math.abs(total - 1) > 0.001 then out:Mul(1 / total) end
    return out
end

local function DeformVertex(v, flexWeights)
    if v.naFlex and flexWeights then
        local pos = Vector(v.pos.x, v.pos.y, v.pos.z)
        local normal = v.normal and Vector(v.normal.x, v.normal.y, v.normal.z)
        for _, delta in ipairs(v.naFlex) do
            local w = flexWeights[delta.flex] or 0
            if w ~= 0 then
                pos:Add(delta.pos * w)
                if normal then normal:Add(delta.normal * w) end
            end
        end
        if normal then normal:Normalize() end
        v = { pos = pos, normal = normal, weights = v.weights }
    end
    return v
end

local function ShellPosition(ent, v, transforms)
    local p = SkinVertex(ent, v, transforms)
    if v.normal then
        local n = SkinVertex(ent, v, transforms, true) - p
        n:Normalize()
        return p + n * SHELL_EPSILON
    end
    return p
end

local function DrawSkinnedFaceTattoo(ply, tete)
    if not AFFICHER_MARQUE_PEAU or not RT_OVERLAY_PRET then return end
    if not IsValid(ply) or not IsValid(tete) then return end
    if not (Porte(ply) or (apercu and ply == LocalPlayer())) then return end

    local data = GetFaceShellData(tete:GetModel())
    if not data or #data.triangles == 0 then return end

    local started = SysTime()
    -- Un produit de matrices par os, pas deux par sommet et par influence.
    local transforms = {}
    for bone, inverse in pairs(data.invBind) do
        if data.rigidBone == nil or bone == data.rigidBone then
            local current = tete:GetBoneMatrix(bone)
            if current then transforms[bone] = current * inverse end
        end
    end
    local cache = shellMeshes[tete]
    if not cache or cache.data ~= data then
        if cache and cache.mesh then cache.mesh:Destroy() end
        cache = { data = data, vertices = {}, weights = {} }
        shellMeshes[tete] = cache
    end
    local flexWeights = data.flexData and FaceShellFlex.Weights(tete, data.flexData) or {}
    local changed = false
    for i, weight in ipairs(flexWeights) do
        if cache.weights[i] ~= weight then changed = true break end
    end
    if changed then cache.vertices = {}; cache.meshDirty = true end
    cache.weights = flexWeights
    local rigidTransform = data.rigidBone and transforms[data.rigidBone]
    local scale = rigidTransform and rigidTransform:GetScale()
    if scale and math.abs(scale.x - 1) < 0.00001 and math.abs(scale.y - 1) < 0.00001
        and math.abs(scale.z - 1) < 0.00001 then
        if cache.meshDirty or not cache.mesh or cache.debug ~= shellDebug then
            if cache.mesh then cache.mesh:Destroy() end
            local verts = {}
            for _, tri in ipairs(data.triangles) do
                for _, v in ipairs(tri) do
                    local d = cache.vertices[v]
                    if not d then d = DeformVertex(v, flexWeights); cache.vertices[v] = d end
                    local pos = d.pos + (d.normal or vector_origin) * SHELL_EPSILON
                    verts[#verts + 1] = { pos = pos, normal = d.normal, u = v.u, v = v.v,
                        color = shellDebug and Color(0, 255, 255) or color_white }
                end
            end
            cache.mesh = Mesh()
            cache.mesh:BuildFromTriangles(verts)
            cache.sample = verts[1].pos
            cache.debug = shellDebug
            cache.meshDirty = false
        end
        render.SetMaterial(shellDebug and MAT_SHELL_DEBUG or MAT_OVERLAY)
        cam.PushModelMatrix(rigidTransform)
        cache.mesh:Draw()
        cam.PopModelMatrix()
        tete.NA_SenjuShellSample = rigidTransform * cache.sample
        tete.NA_SenjuShellFrame = FrameNumber()
        tete.NA_SenjuShellTriangles = #data.triangles
        tete.NA_SenjuShellPath = "cached rigid mesh"
        local elapsed = (SysTime() - started) * 1000
        tete.NA_SenjuShellMS = tete.NA_SenjuShellMS and (tete.NA_SenjuShellMS * 0.9 + elapsed * 0.1) or elapsed
        return
    end
    tete.NA_SenjuShellPath = "dynamic skinning"
    local positions = {}
    local function Position(v)
        if not positions[v] then
            if not cache.vertices[v] then cache.vertices[v] = DeformVertex(v, flexWeights) end
            positions[v] = ShellPosition(tete, cache.vertices[v], transforms)
        end
        return positions[v]
    end
    tete.NA_SenjuShellSample = Position(data.triangles[1][1])

    render.SetMaterial(shellDebug and MAT_SHELL_DEBUG or MAT_OVERLAY)
    -- Le mesh est dynamique car les vertices suivent les os du visage.
    mesh.Begin(MATERIAL_TRIANGLES, #data.triangles)
    for _, tri in ipairs(data.triangles) do
        local a, b, c = tri[1], tri[2], tri[3]
        local pa = Position(a)
        local pb = Position(b)
        local pc = Position(c)
        local red = shellDebug and 0 or 255
        mesh.Position(pa); mesh.TexCoord(0, a.u or 0, a.v or 0); mesh.Color(red,255,255,255); mesh.AdvanceVertex()
        mesh.Position(pb); mesh.TexCoord(0, b.u or 0, b.v or 0); mesh.Color(red,255,255,255); mesh.AdvanceVertex()
        mesh.Position(pc); mesh.TexCoord(0, c.u or 0, c.v or 0); mesh.Color(red,255,255,255); mesh.AdvanceVertex()
    end
    mesh.End()

    tete.NA_SenjuShellFrame = FrameNumber()
    tete.NA_SenjuShellTriangles = #data.triangles
    local elapsed = (SysTime() - started) * 1000
    tete.NA_SenjuShellMS = tete.NA_SenjuShellMS and (tete.NA_SenjuShellMS * 0.9 + elapsed * 0.1) or elapsed
end

hook.Add("NA_PostDrawTetePerso", "NA_SenjuErmite_FaceShellV7", function(ply, tete)
    DrawSkinnedFaceTattoo(ply, tete)
end)

concommand.Add("na_marque_v7_diag", function()
    local ply = LocalPlayer()
    local tete = NA_GetTeteRendue and NA_GetTeteRendue(ply) or NULL
    print("[MarqueV7] version:", MARQUE_PATCH_VERSION)
    print("[MarqueV7] preparation pending:", table.Count(pendingShells), "largest step ms:", preparePeakMS)
    print("[MarqueV7] preview:", apercu, "solid debug:", shellDebug, "source error:", MARQUE:IsError())
    print("[MarqueV7] overlay ready:", RT_OVERLAY_PRET, "texture:", RT_OVERLAY:GetName())
    print("[MarqueV7] head:", tete, IsValid(tete) and tete:GetModel() or "invalid")
    if IsValid(tete) then
        local d = GetFaceShellData(tete:GetModel())
        print("[MarqueV7] face triangles selected:", d and #d.triangles or 0)
        print("[MarqueV7] bind source:", d and d.bindSource)
        print("[MarqueV7] flexes:", d and d.flexData and #d.flexData.flexes or 0,
            "matched corners:", d and d.flexMatched or 0, "error:", d and d.flexError or "none")
        print("[MarqueV7] last shell frame:", tostring(tete.NA_SenjuShellFrame), "current:", FrameNumber())
        print("[MarqueV7] last shell triangles:", tostring(tete.NA_SenjuShellTriangles))
        print("[MarqueV7] shell CPU ms (average):", tete.NA_SenjuShellMS or 0)
        print("[MarqueV7] render path:", tete.NA_SenjuShellPath or "not drawn")
        print("[MarqueV7] sample world:", tostring(tete.NA_SenjuShellSample), "head origin:", tete:GetPos())
    end
end)

concommand.Add("na_marque_v7_shelltest", function(_, _, args)
    shellDebug = args[1] ~= "0"
    apercu = true
    print("[MarqueV7] aperçu ON, couche cyan:", shellDebug)
end)

-- Le panneau 2D ne dépend pas du hook de dessin de la tête : il permet de
-- distinguer un hook absent, une texture vide et un mesh mal placé.
hook.Add("HUDPaint", "NA_SenjuErmite_VisibilityDiagnostic", function()
    if not shellDebug then return end
    local ply = LocalPlayer()
    local tete = NA_GetTeteRendue and NA_GetTeteRendue(ply)
    surface.SetDrawColor(25, 25, 25, 240)
    surface.DrawRect(16, 16, 560, 340)
    draw.SimpleText(MARQUE_PATCH_VERSION, "DermaDefault", 26, 24, color_white)
    local age = IsValid(tete) and tete.NA_SenjuShellFrame
    draw.SimpleText("Dernier dessin : " .. (age and (FrameNumber() - age .. " frames") or "JAMAIS"),
        "DermaDefault", 26, 44, color_white)
    draw.SimpleText("Source (gauche) / texture tatouage (droite)", "DermaDefault", 26, 64, color_white)
    surface.SetDrawColor(240, 240, 240, 255)
    surface.DrawRect(26, 90, 256, 256)
    surface.DrawRect(300, 90, 256, 256)
    surface.SetMaterial(MARQUE)
    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawTexturedRect(26, 90, 256, 256)
    surface.SetMaterial(MAT_OVERLAY_PREVIEW)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawTexturedRect(300, 90, 256, 256)
    if IsValid(tete) and tete.NA_SenjuShellSample then
        local screen = tete.NA_SenjuShellSample:ToScreen()
        if screen.visible then
            draw.SimpleText("+ sommet tattoo", "DermaDefault", screen.x, screen.y, Color(0, 255, 255))
        end
    end
end)

concommand.Add("na_marque_v7_loaded", function()
    print("[MarquePatch] V7 autorun chargé OK")
    print("[MarquePatch] util.GetModelMeshes:", tostring(isfunction(util.GetModelMeshes)))
    print("[MarquePatch] overlay RT:", RT_OVERLAY:GetName())
end)

-- Petit test sans lancer la technique : ouvre/ferme l'aperçu de la texture tatouée.
-- Le menu na_marque_menu active aussi "apercu", donc la vraie peau tatouée y apparaît.
local function DiagnosticMarque(prefix)
    prefix = prefix or "[MarqueDiag]"
    local ply = LocalPlayer()
    print(prefix, "version:", MARQUE_PATCH_VERSION)
    print(prefix, "RT name:", RT_MARQUE and RT_MARQUE:GetName() or "nil")
    print(prefix, "RT ready:", RT_PRET, "dirty:", RT_SALE)
    print(prefix, "preview:", apercu, "AFFICHER_MARQUE_PEAU:", AFFICHER_MARQUE_PEAU)
    if not IsValid(ply) then
        print(prefix, "LocalPlayer invalide")
        return
    end

    local teteServeur = ply:GetNW2Entity("NA_TeteEnt")
    local tete = NA_GetTeteRendue and NA_GetTeteRendue(ply) or teteServeur
    print(prefix, "server head:", teteServeur, IsValid(teteServeur) and teteServeur:GetModel() or "invalid", IsValid(teteServeur) and teteServeur:GetNoDraw() or "-")
    print(prefix, "render head:", tete, IsValid(tete) and tete:GetModel() or "invalid")
    print(prefix, "NA_Perso:", ply:GetNW2String("NA_Perso", ""))

    if not IsValid(tete) then return end
    local mats = tete:GetMaterials()
    print(prefix, "materials count:", #mats)
    for i, chemin in ipairs(mats) do
        print(prefix, "slot", i - 1, chemin)
    end

    local idx = TrouverSlotFace(tete)
    print(prefix, "face slot:", idx)
    if idx ~= nil then
        print(prefix, "current submaterial:", tete:GetSubMaterial(idx))
    end

    local p = NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", ""))
    print(prefix, "visage:", p.visage, "peau:", p.peau and table.concat(p.peau, ",") or "nil")
    local ref = MateriauPeauErmite(p)
    local mat = MATS_PEAU_ERMITE[CleCouleur(p.peau)]
    local tex = mat and mat:GetTexture("$basetexture")
    print(prefix, "dynamic material:", ref)
    print(prefix, "basetexture:", tex and tex:GetName() or "nil")
    local mutation = hook.Run("NA_GetFaceDrawMutation", ply, tete)
    print(prefix, "draw mutation:", mutation and "YES" or "NO")
    print(prefix, "mutation texture:", mutation and mutation.texture and mutation.texture:GetName() or "nil")
    print(prefix, "tattoo flag on head:", tostring(tete.NA_SenjuTattooActif))
    print(prefix, "mutation frame:", tostring(tete.NA_SenjuMutationFrame), "current frame:", FrameNumber())
    local direct = Material("atg/face/face")
    local directTex = direct and not direct:IsError() and direct:GetTexture("$basetexture") or nil
    print(prefix, "direct face material:", direct and direct:GetName() or "nil")
    print(prefix, "direct face base now:", directTex and directTex:GetName() or "nil")
end

concommand.Add("na_marque_peau_preview", function()
    apercu = not apercu
    chat.AddText(Color(220, 180, 80), "[Marque] ", color_white,
        "aperçu peau tatouée : " .. (apercu and "ON" or "OFF") .. " [" .. MARQUE_PATCH_VERSION .. "]")
    timer.Simple(0, function() DiagnosticMarque("[MarquePreview]") end)
end)

concommand.Add("na_marque_diag", function() DiagnosticMarque("[MarqueDiag]") end)
concommand.Add("na_marque_v3_diag", function() DiagnosticMarque("[MarqueV3]") end)
concommand.Add("na_marque_v6_diag", function() DiagnosticMarque("[MarqueV6]") end)
concommand.Add("na_marque_v6_redtest", function()
    testRougeDirect = not testRougeDirect
    chat.AddText(Color(255, 80, 80), "[MarqueV6] ", color_white,
        "test FACE rouge : " .. (testRougeDirect and "ON" or "OFF"))
end)

-- Axe (avant, droite, haut, ou leur opposé) du repère "ang" le plus proche de la direction "cible"
-- Quel axe (avant, droite, haut, ou leur opposé) de "ang" pointe le plus vers "cible" : renvoie
-- l'INDICE (1/2/3 = Forward/Right/Up) et le SIGNE, pas le vecteur, pour pouvoir le réutiliser sur un
-- autre angle plus tard (voir Visage() : c'est CE couple indice+signe qui reste vrai à toute pose ;
-- le vecteur, lui, change à chaque image).
local NOMS_AXES = { "Forward", "Right", "Up" }
local function MeilleurAxe(ang, cible)
    local meilleurI, meilleurS, score = 1, 1, -2
    for i, nom in ipairs(NOMS_AXES) do
        local axe = ang[nom](ang)
        for _, signe in ipairs({ 1, -1 }) do
            local d = (axe * signe):Dot(cible)
            if d > score then meilleurI, meilleurS, score = i, signe, d end
        end
    end
    return meilleurI, meilleurS
end
local function AppliqueAxe(ang, i, s) return ang[NOMS_AXES[i]](ang) * s end

-- Centre des yeux, direction du visage et haut de la tête, d'après l'attache "eyes" de la tête.
-- Quel axe de l'attache correspond à "avant" / "haut" du visage ne dépend QUE du modèle (fixe), pas
-- de la pose du moment : on le détermine une seule fois (MeilleurAxe, avec le regard du joueur comme
-- repère de départ) puis on le RÉUTILISE sur l'angle actuel de l'attache à chaque image
-- (AppliqueAxe). Avant, on recalculait "le plus proche" à chaque image à partir du regard : ça
-- marchait à l'arrêt mais décrochait dès qu'une animation (attaque, geste...) bougeait la tête
-- autrement, puisque le regard du joueur ne reflète pas cette rotation-là.
local function Visage(ply)
    local tete = ply:GetNW2Entity("NA_TeteEnt")
    if not IsValid(tete) then return end
    local att = tete:LookupAttachment("eyes")
    if not att or att <= 0 then return end
    local a = tete:GetAttachment(att)
    if not a then return end

    if not tete.NA_AxeFace then
        tete.NA_AxeFace = { MeilleurAxe(a.Ang, Angle(0, ply:EyeAngles().y, 0):Forward()) }
        tete.NA_AxeHaut = { MeilleurAxe(a.Ang, Vector(0, 0, 1)) }
    end

    local face = AppliqueAxe(a.Ang, tete.NA_AxeFace[1], tete.NA_AxeFace[2])
    local haut = AppliqueAxe(a.Ang, tete.NA_AxeHaut[1], tete.NA_AxeHaut[2])
    return a.Pos, face, haut
end

-- Rotation de "v" autour de l'axe unitaire "axe", de "deg" degrés (formule de Rodrigues)
local function TourneAutourDe(v, axe, deg)
    if deg == 0 then return v end
    local rad = math.rad(deg)
    local c, sn = math.cos(rad), math.sin(rad)
    return v * c + axe:Cross(v) * sn + axe * axe:Dot(v) * (1 - c)
end

-- Grille courbée (au lieu d'un plan plat) : le morceau se bombe vers l'avant (axe "n") au centre,
-- et revient à 0 sur les bords, comme une vraie surface qui suit la courbure du visage plutôt
-- qu'une plaque plate. "courbure" = 0 -> parfaitement plat (comme avant), plus grand = plus bombé.
local SUBDIV = 6   -- N x N : plus grand = plus lisse, plus lourd
local function DessinerCourbe(centre, dr, up, n, moitieL, moitieH, u0, u1, v0, v1, courbure, r, g, b, alpha)
    local function Point(fi, fj)
        local lx, ly = (fi - 0.5) * 2 * moitieL, (fj - 0.5) * 2 * moitieH
        local nx, ny = math.abs(fi - 0.5) * 2, math.abs(fj - 0.5) * 2
        local profondeur = (1 - nx * nx) * courbure * 0.6 + (1 - ny * ny) * courbure * 0.4
        local pos = centre + dr * lx + up * ly + n * profondeur
        return pos, u0 + (u1 - u0) * fi, v0 + (v1 - v0) * fj
    end

    mesh.Begin(MATERIAL_TRIANGLES, (SUBDIV - 1) * (SUBDIV - 1) * 2)
    for j = 0, SUBDIV - 2 do
        for i = 0, SUBDIV - 2 do
            local fi0, fi1 = i / (SUBDIV - 1), (i + 1) / (SUBDIV - 1)
            local fj0, fj1 = j / (SUBDIV - 1), (j + 1) / (SUBDIV - 1)
            local p00, tu00, tv00 = Point(fi0, fj0)
            local p10, tu10, tv10 = Point(fi1, fj0)
            local p11, tu11, tv11 = Point(fi1, fj1)
            local p01, tu01, tv01 = Point(fi0, fj1)

            for _, pt in ipairs({ { p00, tu00, tv00 }, { p10, tu10, tv10 }, { p11, tu11, tv11 },
                                   { p00, tu00, tv00 }, { p11, tu11, tv11 }, { p01, tu01, tv01 } }) do
                mesh.Position(pt[1]) mesh.TexCoord(0, pt[2], pt[3]) mesh.Color(r, g, b, alpha) mesh.AdvanceVertex()
            end
        end
    end
    mesh.End()
end

local function DessinerMarque(ply, alphaForce)
    if not alphaForce and not Porte(ply) then debuts[ply] = nil return end
    debuts[ply] = debuts[ply] or CurTime()

    local pos, face, haut = Visage(ply)
    if not pos then return end
    local droite = face:Cross(haut)
    local origine = pos + haut * REGL.HAUT

    local alpha = alphaForce or 255 * math.Clamp((CurTime() - debuts[ply]) / FONDU, 0, 1)

    -- effacée seulement vue de bien derrière (0 = pile de profil, -1 = de dos) : reste visible
    -- jusque assez loin sur le côté, disparaît seulement près du plein profil / dos
    local vue = (EyePos() - origine):GetNormalized()
    alpha = math.floor(alpha * math.Clamp((face:Dot(vue) + 0.1) / 0.25, 0, 1))
    if alpha <= 0 then return end
    local r, g, b = COULEUR.r, COULEUR.g, COULEUR.b

    render.SetMaterial(MARQUE)
    for _, m in ipairs(MORCEAUX) do
        local xmin, xmax, ymin, ymax = m.px[1] - REGL.PAD, m.px[2] + REGL.PAD, m.px[3] - REGL.PAD, m.px[4] + REGL.PAD
        local cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2

        local avant, roulis, x, y, courbure
        local n = face
        if not m.cle then   -- front : ses propres réglages, tourné puis incliné comme les yeux
            avant = REGL.FRONT_AVANT
            roulis = REGL.FRONT_ROULIS
            courbure = REGL.FRONT_COURBURE
            x = (REF_X - cx) * REGL.ECHELLE + REGL.FRONT_DECALAGE_X
            y = (REF_Y - cy) * REGL.ECHELLE + REGL.FRONT_DECALAGE_Y

            n = TourneAutourDe(face, haut, REGL.FRONT_ANGLE)
            local dr0 = n:Cross(haut)
            n = TourneAutourDe(n, dr0, REGL.FRONT_INCLINAISON)
        else   -- œil : ses propres réglages (indépendants de l'autre œil), tourné puis incliné
            local o = REGL[m.cle]
            avant = o.AVANT + o.DECALAGE_AVANT
            roulis = o.ROULIS
            courbure = o.COURBURE
            x = (REF_X - cx) * REGL.ECHELLE + o.DECALAGE_X
            y = (REF_Y - cy) * REGL.ECHELLE + o.DECALAGE_Y

            n = TourneAutourDe(face, haut, o.ANGLE)
            local dr0 = n:Cross(haut)
            n = TourneAutourDe(n, dr0, o.INCLINAISON)
        end

        local centre = origine + droite * x + haut * y + n * avant

        local dr = n:Cross(haut)
        local up = dr:Cross(n)
        if roulis ~= 0 then
            dr = TourneAutourDe(dr, n, roulis)
            up = TourneAutourDe(up, n, roulis)
        end

        local moitieL, moitieH = (xmax - xmin) / 2 * REGL.ECHELLE, (ymax - ymin) / 2 * REGL.ECHELLE
        local u0, u1, v0, v1 = xmin / 2048, xmax / 2048, ymin / 2048, ymax / 2048

        DessinerCourbe(centre, dr, up, n, moitieL, moitieH, u0, u1, v0, v1, courbure, r, g, b, alpha)
    end
end

-- Dessinée APRÈS tous les objets opaques : le test de profondeur cache la marque derrière le
-- visage (pas ailleurs, grâce à $ignorez du matériau qui l'empêche d'être coupée par le relief).
hook.Add("PostDrawTranslucentRenderables", "NA_SenjuErmite_Marque", function(profondeur, ciel)
    if not AFFICHER_MARQUE or profondeur or ciel then return end
    for _, ply in ipairs(player.GetAll()) do
        if Porte(ply) or debuts[ply] then DessinerMarque(ply) end
    end
    -- aperçu forcé sur toi (menu de réglage ouvert) même sans la technique active
    if apercu and IsValid(LocalPlayer()) and not Porte(LocalPlayer()) then DessinerMarque(LocalPlayer(), 255) end
end)

----------------------------------------------------------
-- Caméra tournante autour du joueur, pendant que le menu de réglage est ouvert : le clic gauche
-- maintenu fait tourner la caméra autour du corps, la molette rapproche / éloigne. Ça permet de
-- voir la marque sous tous les angles sans avoir à bouger le personnage.
----------------------------------------------------------
local orbite = false
local orbYaw, orbPitch, orbDist = 0, 10, 90

hook.Add("CalcView", "NA_SenjuErmite_Orbite", function(ply, pos, ang, fov)
    if not orbite or not IsValid(ply) or ply ~= LocalPlayer() or not ply:Alive() then return end

    local tete = ply:EyePos()
    local dir = Angle(orbPitch, orbYaw, 0):Forward()
    local camPos = tete + dir * orbDist

    local tr = util.TraceHull({
        start = tete, endpos = camPos, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4),
        filter = ply, mask = MASK_SOLID_BRUSHONLY,
    })
    if tr.Hit then camPos = tr.HitPos end

    local view = {}
    view.origin = camPos
    view.angles = (tete - camPos):Angle()
    view.fov = fov
    view.drawviewer = true
    return view
end)

----------------------------------------------------------
-- Menu de réglage (na_marque_menu) : panneau à droite de l'écran, même style que le menu de
-- personnalisation (cl_perso_menu.lua). Sections Front / Yeux / Commun, curseurs en direct,
-- copie du résultat.
----------------------------------------------------------
local LARGEUR_PANNEAU = 360

local C_FOND    = Color(28, 24, 22, 250)
local C_PANNEAU = Color(44, 38, 34)
local C_BOUTON  = Color(66, 56, 50)
local C_SURVOL  = Color(96, 80, 70)
local C_TEXTE   = Color(240, 230, 215)
local C_DOUX    = Color(170, 155, 140)
local C_SECTION = Color(200, 160, 90)

surface.CreateFont("NA.Marque.Titre", { font = "Roboto", size = 20, weight = 800 })
surface.CreateFont("NA.Marque.Texte", { font = "Roboto", size = 15, weight = 600 })
surface.CreateFont("NA.Marque.Section", { font = "Roboto", size = 15, weight = 800 })

-- { section, chemin, nom, min, max, deci } : chemin = "CLE" (REGL.CLE) ou { "GROUPE", "SOUS_CLE" } (REGL.GROUPE.SOUS_CLE)
local CHAMPS = {
    { "Commun", "ECHELLE",    "Taille",              0.0005, 0.01, 4 },
    { "Commun", "HAUT",       "Hauteur (repère commun)", -15, 15, 2 },
    { "Commun", "PAD",        "Marge de la texture", 0, 80, 0 },

    { "Front", "FRONT_AVANT",       "Avant / arrière",     -10, 10, 2 },
    { "Front", "FRONT_ANGLE",       "Angle (côté)",        -60, 60, 0 },
    { "Front", "FRONT_INCLINAISON", "Angle (haut/bas)",    -60, 60, 0 },
    { "Front", "FRONT_ROULIS",      "Roulis",              -180, 180, 0 },
    { "Front", "FRONT_DECALAGE_X",  "Déplacer (côté)",     -3, 3, 2 },
    { "Front", "FRONT_DECALAGE_Y",  "Déplacer (haut/bas)", -10, 10, 2 },
    { "Front", "FRONT_COURBURE",    "Courbure",            0, 3, 2 },
}

-- les 2 yeux ont les mêmes 7 réglages, chacun dans son propre groupe (OEIL_GAUCHE / OEIL_DROIT)
for _, oeil in ipairs({ { "Œil gauche", "OEIL_GAUCHE" }, { "Œil droit", "OEIL_DROIT" } }) do
    local section, groupe = oeil[1], oeil[2]
    local champs = {
        { "AVANT",          "Avant / arrière",     -10, 10, 2 },
        { "ANGLE",          "Angle (côté)",         -60, 60, 0 },
        { "INCLINAISON",    "Angle (haut/bas)", -60, 60, 0 },
        { "ROULIS",         "Roulis",               -180, 180, 0 },
        { "DECALAGE_X",     "Déplacer (côté)",      -3, 3, 2 },
        { "DECALAGE_Y",     "Déplacer (haut/bas)",  -10, 10, 2 },
        { "DECALAGE_AVANT", "Déplacer (avant/arrière)", -10, 10, 2 },
        { "COURBURE",       "Courbure",                  0, 3, 2 },
    }
    for _, c in ipairs(champs) do
        CHAMPS[#CHAMPS + 1] = { section, { groupe, c[1] }, c[2], c[3], c[4], c[5] }
    end
end

local function LireValeur(chemin)
    if istable(chemin) then return REGL[chemin[1]][chemin[2]] end
    return REGL[chemin]
end
local function EcrireValeur(chemin, v)
    if istable(chemin) then REGL[chemin[1]][chemin[2]] = v else REGL[chemin] = v end
end

local function CopierValeurs()
    local lignes = { "local REGL = {", "    ECHELLE = " .. tostring(REGL.ECHELLE) .. ",",
        "    HAUT = " .. tostring(math.Round(REGL.HAUT, 2)) .. ",", "    PAD = " .. tostring(math.Round(REGL.PAD, 0)) .. "," }
    lignes[#lignes + 1] = ""
    lignes[#lignes + 1] = "    -- FRONT"
    for _, cle in ipairs({ "FRONT_AVANT", "FRONT_ANGLE", "FRONT_INCLINAISON", "FRONT_ROULIS", "FRONT_DECALAGE_X", "FRONT_DECALAGE_Y", "FRONT_COURBURE" }) do
        lignes[#lignes + 1] = string.format("    %s = %s,", cle, tostring(math.Round(REGL[cle], 2)))
    end
    for _, groupe in ipairs({ "OEIL_GAUCHE", "OEIL_DROIT" }) do
        lignes[#lignes + 1] = ""
        lignes[#lignes + 1] = "    " .. groupe .. " = {"
        for _, sous in ipairs({ "AVANT", "ANGLE", "INCLINAISON", "ROULIS", "DECALAGE_X", "DECALAGE_Y", "DECALAGE_AVANT", "COURBURE" }) do
            lignes[#lignes + 1] = string.format("        %s = %s,", sous, tostring(math.Round(REGL[groupe][sous], 2)))
        end
        lignes[#lignes + 1] = "    },"
    end
    lignes[#lignes + 1] = "}"
    local texte = table.concat(lignes, "\n")
    SetClipboardText(texte)
    MsgC(Color(255, 200, 0), "[Marque] ", color_white, "valeurs copiées dans le presse-papiers (à coller dans cl_senju_ermite.lua) :\n")
    print(texte)
end

local function Bouton(parent, texte, clic)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    function b:Paint(w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and C_SURVOL or C_BOUTON)
        draw.SimpleText(texte, "NA.Marque.Texte", w / 2, h / 2, C_TEXTE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = clic
    return b
end

local function Fermer()
    if IsValid(NA_MarqueMenu) then NA_MarqueMenu:Remove() end
    if IsValid(NA_MarqueCapture) then NA_MarqueCapture:Remove() end
    apercu, orbite = false, false
end

local function Ouvrir()
    if IsValid(NA_MarqueMenu) then Fermer() return end
    apercu, orbite = true, true
    orbYaw, orbPitch, orbDist = IsValid(LocalPlayer()) and LocalPlayer():EyeAngles().y or 0, 10, 90

    -- capture plein écran (SOUS le panneau) : glisser tourne la caméra, la molette zoome
    local capture = vgui.Create("DPanel")
    capture:SetPos(0, 0)
    capture:SetSize(ScrW(), ScrH())
    capture:SetMouseInputEnabled(true)
    capture.Paint = function() end
    function capture:OnMousePressed(k)
        if k ~= MOUSE_LEFT then return end
        self.Glisse = true
        self.DepartX, self.DepartY = gui.MouseX(), gui.MouseY()
        self:MouseCapture(true)
    end
    function capture:OnMouseReleased()
        self.Glisse = false
        self:MouseCapture(false)
    end
    function capture:OnCursorMoved()
        if not self.Glisse then return end
        local x, y = gui.MouseX(), gui.MouseY()
        orbYaw = orbYaw - (x - self.DepartX) * 0.5
        orbPitch = math.Clamp(orbPitch - (y - self.DepartY) * 0.5, -80, 80)
        self.DepartX, self.DepartY = x, y
    end
    function capture:OnMouseWheeled(d) orbDist = math.Clamp(orbDist - d * 6, 20, 250) end
    NA_MarqueCapture = capture

    local hauteur = math.min(math.floor(ScrH() * 0.85), 720)
    local f = vgui.Create("DFrame")
    f:SetSize(LARGEUR_PANNEAU, hauteur)
    f:SetPos(ScrW() - LARGEUR_PANNEAU - 20, (ScrH() - hauteur) / 2)
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetDraggable(false)
    f:MakePopup()
    f.OnClose = function() if IsValid(NA_MarqueCapture) then NA_MarqueCapture:Remove() end apercu, orbite = false, false end
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, C_FOND)
        draw.SimpleText("Marque d'ermite", "NA.Marque.Titre", 16, 18, C_TEXTE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("clic gauche + glisser = tourner, molette = zoomer", "NA.Marque.Texte", 16, 42, C_DOUX, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    NA_MarqueMenu = f

    local zone = vgui.Create("DScrollPanel", f)
    zone:SetPos(10, 62)
    zone:SetSize(LARGEUR_PANNEAU - 20, hauteur - 62 - 80)
    zone.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, C_PANNEAU) end
    local toile = zone:GetCanvas()
    toile:DockPadding(10, 6, 10, 6)

    local dernier = nil
    for _, c in ipairs(CHAMPS) do
        local section, chemin, nom, mini, maxi, deci = c[1], c[2], c[3], c[4], c[5], c[6]
        if section ~= dernier then
            dernier = section
            local titre = vgui.Create("DPanel", toile)
            titre:Dock(TOP)
            titre:SetTall(28)
            titre:DockMargin(0, section == "Commun" and 0 or 10, 0, 0)
            titre.Paint = function(_, w, h) draw.SimpleText(section, "NA.Marque.Section", 0, h - 4, C_SECTION, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM) end
        end

        local s = vgui.Create("NA_NumSlider", toile)
        s:Dock(TOP)
        s:SetTall(44)
        s:SetText(nom)
        s:SetDark(false)
        s:SetMin(mini)
        s:SetMax(maxi)
        s:SetDecimals(deci)
        s:SetValue(LireValeur(chemin))
        s.OnValueChanged = function(_, v) EcrireValeur(chemin, v) end
    end

    local copier = Bouton(f, "Copier les valeurs", CopierValeurs)
    copier:SetPos(10, hauteur - 76)
    copier:SetSize(LARGEUR_PANNEAU - 20, 30)

    local fermer = Bouton(f, "Fermer", Fermer)
    fermer:SetPos(10, hauteur - 40)
    fermer:SetSize(LARGEUR_PANNEAU - 20, 30)
end

concommand.Add("na_marque_menu", Ouvrir, nil, "Ouvre un panneau pour régler en direct la position de la marque d'ermite sur le visage.")

----------------------------------------------------------
-- La piste "texture de peau" n'est plus abandonnée : elle est implémentée plus haut
-- avec un RenderTarget 512x512 appliqué au slot "face" de la tête réellement dessinée.
-- Les anciennes plaques 3D restent dans ce fichier comme outil de comparaison/réglage,
-- mais AFFICHER_MARQUE=false les garde désactivées.
----------------------------------------------------------

print("[MarquePatch] chargé V6-direct-face-material")
concommand.Add("na_marque_v6_loaded", function()
    local ht = hook.GetTable()
    print("[MarquePatch] V6 autorun chargé OK")
    print("[MarquePatch] draw mutation hook:", tostring(ht["NA_GetFaceDrawMutation"] ~= nil))
    print("[MarquePatch] draw helper:", tostring(isfunction(NA_DrawModelAvecFaceMutation)))
    print("[MarquePatch] direct face material:", tostring(Material("atg/face/face")))
end)
