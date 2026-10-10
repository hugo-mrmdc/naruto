--========================================================
-- Personnalisation du personnage (CLIENT) : apparence des visages
--
-- Les visages models/head/face_N.mdl (atg) n'ont que des textures BLANCHES : la
-- peau, l'iris, les sourcils et la barbe sont teintés par leur matériau. Chaque
-- client crée donc ces matériaux (CreateMaterial) d'après le choix du joueur
-- (NW2String "NA_Perso", posé par sv_playerskin.lua) et les pose sur la tête.
-- Rien ne passe par le réseau en plus, et aucun .vmt par couleur.
--
--   NA_HabillerVisage(ent, p)  -> matériaux, barbe et formes sur une tête (ent)
--   NA_PoserFormes(ent, ferme) -> formes d'yeux / nez (flex), ferme = 0..1 (clignement)
--
-- Le flex doit être reposé à chaque image sur la tête du serveur (le réseau le
-- remet à 0) : cl_clignement.lua appelle NA_PoserFormes au dessin de la tête.
-- Les copies clientside (corps après la mort, portrait du HUD, menu) le gardent.
--========================================================

local materiaux = {}   -- nom -> matériau (gardé pour ne pas être libéré)

local function Teinte(c)
    return string.format("[%.3f %.3f %.3f]", c[1] / 255, c[2] / 255, c[3] / 255)
end

-- Matériau "na_perso_<nom>" (créé une fois), rendu sous la forme utilisable par SetSubMaterial
local function Mat(nom, shader, params)
    if not materiaux[nom] then
        materiaux[nom] = CreateMaterial("na_perso_" .. nom, shader, params)
    end
    return "!na_perso_" .. nom
end

local function Cle(c) return c[1] .. "_" .. c[2] .. "_" .. c[3] end

local TOON = "atg/shared/toon"

-- Nom court du matériau (dernier élément du chemin) -> fonction qui donne le matériau à poser
local FABRIQUES = {
    face = function(p)
        return Mat("peau_" .. Cle(p.peau), "VertexLitGeneric", {
            ["$basetexture"] = "atg/face/face", ["$lightwarptexture"] = TOON,
            ["$color2"] = Teinte(p.peau),
        })
    end,
    eyebrows = function(p)
        return Mat("sourcils_" .. p.sourcils .. "_" .. Cle(p.sourcils_c), "VertexLitGeneric", {
            ["$basetexture"] = "atg/eyebrows/eyebrows_" .. p.sourcils, ["$lightwarptexture"] = "atg/shared/lightwarpshader",
            ["$alphatest"] = 1, ["$color2"] = Teinte(p.sourcils_c),
        })
    end,
    beard_color = function(p)   -- la barbe suit la couleur des cheveux
        return Mat("barbe_" .. Cle(p.cheveux_c), "VertexLitGeneric", {
            ["$basetexture"] = "atg/face/beard_color", ["$lightwarptexture"] = TOON,
            ["$color2"] = Teinte(p.cheveux_c),
        })
    end,
}
-- Yeux : la teinte ne touche que l'iris (le canal alpha de la texture est son masque).
-- "special" = yeux choisis par na_yeux (Ketsuryugan, Sharingan... : sv_yeux.lua) : leur texture
-- (materials/models/naruto_dev/yeux/, iris centré comme ici) remplace celle de l'œil, sans teinte.
for _, oeil in ipairs({ "eyes_g", "eyes_d" }) do
    FABRIQUES[oeil] = function(p, special)
        if special and special ~= "" then
            return Mat(oeil .. "_" .. string.gsub(special, "[^%w]", "_"), "VertexLitGeneric", {
                ["$basetexture"] = special, ["$lightwarptexture"] = TOON,
            })
        end
        return Mat(oeil .. "_" .. Cle(p.yeux_c), "VertexLitGeneric", {
            ["$basetexture"] = "atg/face/" .. oeil, ["$lightwarptexture"] = TOON,
            ["$blendtintbybasealpha"] = 1, ["$blendtintcoloroverbase"] = 0,
            ["$color2"] = Teinte(p.yeux_c),
        })
    end
end

function NA_HabillerVisage(ent, p, yeuxSpeciaux)
    if not IsValid(ent) then return end

    -- l'ordre des matériaux change selon le visage : on cherche par nom
    -- On mémorise aussi le slot + le matériau normal de la peau : les effets temporaires
    -- (tatouage Senju, marques, etc.) peuvent ainsi remplacer UNIQUEMENT le visage puis le
    -- restaurer sans rappeler NA_HabillerVisage et sans toucher aux yeux/sourcils/barbe.
    for i, chemin in ipairs(ent:GetMaterials()) do
        local nom = string.lower(string.match(chemin, "[^/\\]+$") or "")
        local fabrique = FABRIQUES[nom]
        if fabrique then
            local mat = fabrique(p, yeuxSpeciaux)

            -- Point d'extension pour remplacer proprement le matériau FACE via le même
            -- chemin que la custom normale. C'est volontairement AVANT SetSubMaterial :
            -- le tattoo devient donc le matériau officiel du slot face, au lieu d'être
            -- un override de rendu ajouté après coup.
            if nom == "face" then
                local remplacement = hook.Run("NA_GetFaceMaterial", ent, p, mat, yeuxSpeciaux)
                if remplacement ~= nil then mat = remplacement end
            end

            ent:SetSubMaterial(i - 1, mat)
            if nom == "face" then
                ent.NA_FaceSubIndex = i - 1
                ent.NA_FaceBaseMaterial = mat
            end
        end
    end

    ent:SetBodygroup(1, p.barbe)   -- bodygroup "beard" : 0 = aucune

    ent.NA_Forme = { yeux = "eyes_" .. NA_PERSO.YEUX[p.yeux], nez = p.nez > 0 and ("nose_" .. NA_PERSO.NEZ[p.nez]) or nil, avecBouche = p.bouche }
    NA_PoserFormes(ent, 0)
end

-- Cheveux : le matériau d'origine est très sombre ($color2 0,4 x $color 0,3), la teinte
-- du modèle donnerait du noir quelle que soit la couleur. On le remplace par une copie
-- (mêmes textures) teintée à pleine valeur. Les parties qui ne sont pas des cheveux
-- (bandages, bandeau, chapeau) ne sont pas touchées.
-- Bandeaux et bandages : teinte à part (couleur "Bandeau" du menu). Les plaques de métal du
-- bandeau ("symbol", "headgear") et le reste ne sont pas teintés.
local BANDEAUX = { "headband", "heandband", "bandage" }
local NON_TEINTES = { "headgear", "hat", "accessoire", "symbol", "black", "skin", "lower", "part color" }

local LOGOS_PLAQUE = { "symbol", "headgear" }

local function Contient(nom, motifs)
    for _, motif in ipairs(motifs) do
        if string.find(nom, motif, 1, true) then return true end
    end
    return false
end

local function Texture(mat, cle)
    if not mat or mat:IsError() then return nil end
    local t = mat:GetTexture(cle)
    return t and t:GetName()
end

local function MateriauSourceValide(chemin)
    if not isstring(chemin) or chemin == "" or chemin == "0" then return false end
    return true
end

function NA_TeinterCheveux(ent, p)
    if not IsValid(ent) then return end

    -- modèle d'origine : 92 coupes dans un bodygroup (les autres modèles n'ont qu'une coupe)
    if string.find(string.lower(ent:GetModel() or ""), "hairs1_", 1, true) then
        ent:SetBodygroup(0, NA_PERSO.CoupeCheveux(p))
    end

    for i, chemin in ipairs(ent:GetMaterials()) do
        local nom = string.lower(string.match(chemin, "[^/\\]+$") or "")
        local teintable = not Contient(nom, NON_TEINTES)
        local couleur = Contient(nom, BANDEAUX) and p.bandeau_c or p.cheveux_c

        -- plaque de métal du bandeau : logo du village choisi (0 = Konoha), toujours pris dans les
        -- textures de l'addon (materials/atg/hair/) : celles des packs d'origine peuvent manquer et
        -- s'affichent alors en rose. Jamais teintée par la couleur du bandeau.
        if Contient(nom, LOGOS_PLAQUE) then
            local orig = MateriauSourceValide(chemin) and Material(chemin) or nil
            local texture = NA_PERSO.LOGOS[math.max(p.logo, 1)][2]
            ent:SetSubMaterial(i - 1, Mat("plaque_" .. string.gsub(chemin, "[^%w]", "_") .. "_" .. p.logo, "VertexLitGeneric", {
                ["$basetexture"] = texture,
                ["$lightwarptexture"] = orig and not orig:IsError() and Texture(orig, "$lightwarptexture") or nil,
                ["$phong"] = 1, ["$phongexponent"] = 40, ["$phongboost"] = 4,
                ["$phongfresnelranges"] = "[0.4 1 2]",
            }))
        end

        local orig = teintable and MateriauSourceValide(chemin) and Material(chemin) or nil
        if orig and not orig:IsError() and Texture(orig, "$basetexture") then
            local params = {
                ["$basetexture"] = Texture(orig, "$basetexture"),
                ["$bumpmap"] = Texture(orig, "$bumpmap"),
                ["$lightwarptexture"] = Texture(orig, "$lightwarptexture"),
                ["$alphatest"] = orig:GetInt("$alphatest"), ["$translucent"] = orig:GetInt("$translucent"),
                ["$nocull"] = orig:GetInt("$nocull"),
                ["$color2"] = Teinte(couleur),
            }
            ent:SetSubMaterial(i - 1, Mat("cheveux_" .. string.gsub(chemin, "[^%w]", "_") .. "_" .. Cle(couleur), "VertexLitGeneric", params))
        end
    end
end

-- Peau du corps : seul le matériau "mat_skin" des tenues est teinté (le joueur n'a pas
-- de teinte, sinon la tenue serait colorée aussi). Visage d'origine : peau de la tenue.
function NA_PeauCorps(ent, p)
    if not IsValid(ent) then return end
    for _, i in ipairs(ent.NA_PeauIdx or {}) do ent:SetSubMaterial(i, "") end   -- tenue précédente
    ent.NA_PeauIdx = {}
    if p.visage == 0 then return end

    local peau = Mat("corps_" .. Cle(p.peau), "VertexLitGeneric", {
        ["$basetexture"] = "models/debug/debugwhite", ["$lightwarptexture"] = TOON,   -- même ombrage "toon" que le visage
        ["$color2"] = Teinte(p.peau),
    })
    for i, chemin in ipairs(ent:GetMaterials()) do
        if string.lower(string.match(chemin, "[^/\\]+$") or "") == "mat_skin" then
            ent:SetSubMaterial(i - 1, peau)
            ent.NA_PeauIdx[#ent.NA_PeauIdx + 1] = i - 1
        end
    end
end

-- Forme d'yeux à fond, et fondu vers sa version "_blink" quand les paupières se ferment
function NA_PoserFormes(ent, ferme)
    if not IsValid(ent) then return end
    local f = ent.NA_Forme
    if not f then return end

    if f.oeil == nil then   -- indices des flex, cherchés une seule fois (false = absent)
        f.oeil      = ent:GetFlexIDByName(f.yeux) or false
        f.paupieres = ent:GetFlexIDByName(f.yeux .. "_blink") or false
        f.narines   = f.nez and ent:GetFlexIDByName(f.nez) or false
        -- chaque visage a UNE forme de bouche "mouth_<nom>" qui le distingue des autres
        -- (les 28 crânes sont presque identiques) : elle doit être activée
        f.bouche = false
        for i = 0, ent:GetFlexNum() - 1 do
            if string.StartWith(ent:GetFlexName(i), "mouth_") then f.bouche = i break end
        end
    end
    if f.bouche then ent:SetFlexWeight(f.bouche, f.avecBouche == 0 and 0 or 1) end

    if f.oeil then ent:SetFlexWeight(f.oeil, 1 - ferme) end
    if f.paupieres then ent:SetFlexWeight(f.paupieres, ferme) end
    if f.narines then ent:SetFlexWeight(f.narines, 1) end
end

-- Têtes des joueurs (créées par le serveur) : on pose leurs matériaux quand le choix change
local prochaineVerificationApparence = 0
hook.Add("Think", "NA_Perso_Tetes", function()
    local now = CurTime()
    if now < prochaineVerificationApparence then return end
    prochaineVerificationApparence = now + 0.1
    for _, ply in ipairs(player.GetAll()) do
        -- peau du corps : refaite quand le choix ou la tenue change
        local cle = ply:GetNW2String("NA_Perso", "") .. "|" .. ply:GetModel()
        if ply.NA_PeauCle ~= cle then
            ply.NA_PeauCle = cle
            NA_PeauCorps(ply, NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", "")))
        end

        local cheveux = ply:GetNW2Entity("NA_CheveuxEnt")
        if IsValid(cheveux) then
            local json = ply:GetNW2String("NA_Perso", "")
            if cheveux.NA_PersoJson ~= json then
                cheveux.NA_PersoJson = json
                NA_TeinterCheveux(cheveux, NA_PERSO.Decoder(json))
            end
        end

        local tete = ply:GetNW2Entity("NA_TeteEnt")
        if IsValid(tete) then
            local yeux = ply:GetNW2String("NA_Yeux", "")   -- yeux spéciaux (na_yeux)
            local json = ply:GetNW2String("NA_Perso", "") .. "|" .. yeux
            if tete.NA_PersoJson ~= json then
                tete.NA_PersoJson = json
                local p = NA_PERSO.Decoder(ply:GetNW2String("NA_Perso", ""))
                if p.visage > 0 then NA_HabillerVisage(tete, p, yeux) end
            end
        end
    end
end)

--========================================================
-- Recul du visage et des cheveux
--
-- Les tenues (col, masque, bandage de cou) sont faites pour l'ancienne tête models/head_03.mdl :
-- son menton est 1,6 unité plus en retrait que celui des visages numérotés (models/head/), et le
-- masque de la tenue passe juste devant la bouche (0,3 unité) ou disparaît dans le visage.
-- La tête et les cheveux fusionnés au squelette ne peuvent pas être décalés par rapport à la
-- tenue : le client les dessine donc lui-même (copies non fusionnées), à la position de l'os de
-- tête du joueur, reculées de "recul" dixièmes d'unité (choix du menu, 0,7 par défaut).
--   final(v) = tête(animée) * inverse(tête à la pose de référence) * Tr(0, recul, 0) * v
-- (les modèles regardent vers -Y à la pose de référence : reculer = +Y)
--========================================================
-- Repère commun du recul : models/head/face_N.mdl. Les cheveux conservent
-- leur pose propre, mais suivent le même axe de déplacement que le visage.
local REPERE_RECUL = Matrix({
        { 0.000026, 0.000002, -1.0, 0.000054 }, { -0.246546, 0.969131, -0.000004, 0.604915 },
        { 0.969131, 0.246546, 0.000026, 63.517941 }, { 0, 0, 0, 1 } })
local REPERE_RECUL_INV = REPERE_RECUL:GetInverse()

local translation = Matrix()

-- Dessine un modèle en permettant à un effet d'apparence de modifier TEMPORAIREMENT
-- le matériau source "face" lui-même. C'est le dernier recours quand SetSubMaterial et
-- render.MaterialOverrideByIndex sont neutralisés par le pipeline du modèle : le .mdl continue
-- d'utiliser son matériau d'origine, mais sa $basetexture/$color2 sont changées uniquement pendant
-- CE DrawModel puis restaurées immédiatement après. Les yeux/sourcils/barbe ont d'autres IMaterial,
-- ils ne sont donc jamais touchés.
local function MateriauFaceDirect(ent)
    if not IsValid(ent) then return end
    if ent.NA_FaceDirectMaterial and not ent.NA_FaceDirectMaterial:IsError() then
        return ent.NA_FaceDirectMaterial
    end

    for _, chemin in ipairs(ent:GetMaterials()) do
        local nom = string.lower(string.match(chemin, "[^/\\]+$") or "")
        if nom == "face" and chemin ~= "" and chemin ~= "0" then
            local mat = Material(chemin)
            if mat and not mat:IsError() then
                ent.NA_FaceDirectMaterial = mat
                ent.NA_FaceDirectPath = chemin
                return mat
            end
        end
    end
end

function NA_DrawModelAvecFaceMutation(ent, flags, ply)
    if not IsValid(ent) then return end

    local mutation = hook.Run("NA_GetFaceDrawMutation", IsValid(ply) and ply or NULL, ent)
    if not mutation then
        ent:DrawModel(flags)
        return
    end

    local face = MateriauFaceDirect(ent)
    if not face then
        ent:DrawModel(flags)
        return
    end

    local ancienneTexture = face:GetTexture("$basetexture")
    local ancienneCouleur = face:GetVector("$color2")

    local ok, err = xpcall(function()
        -- SetVector ne force pas forcément un snapshot ; on pose la couleur d'abord puis
        -- SetTexture, qui appelle Recompute, pour que les deux changements soient pris ensemble.
        if mutation.color then
            face:SetVector("$color2", mutation.color)
        end
        if mutation.texture then
            face:SetTexture("$basetexture", mutation.texture)
        end
        ent:DrawModel(flags)
    end, debug.traceback)

    -- IMPORTANT : IMaterial est global. On restaure toujours l'état d'origine immédiatement
    -- afin que les autres joueurs/portraits utilisant atg/face/face ne récupèrent pas ce tattoo.
    if ancienneCouleur then face:SetVector("$color2", ancienneCouleur) end
    if ancienneTexture then face:SetTexture("$basetexture", ancienneTexture) end

    if not ok then
        ErrorNoHalt("[NA FaceMutation] " .. tostring(err) .. "\\n")
    end
end

-- Dessine cs (ClientsideModel NON fusionné : tête ou cheveux) sur la tête de ent, reculé de recul/10.
-- Équivalent d'une fusion de squelette, plus un décalage :
--   final(v) = tête(animée) * inverse(os de tête du modèle) * Tr(0, recul, 0) * v
-- La pose du modèle (sa séquence "reference" n'est pas la pose de référence) est mesurée une fois
-- et compensée, sinon la tête se retrouve tournée.
function NA_DessinerRecul(cs, ent, recul)
    if not IsValid(cs) or not IsValid(ent) then return end
    local modeleParent = ent:GetModel()
    if ent.NA_ReculModeleParent ~= modeleParent or ent.NA_ReculOsTete == nil then
        ent.NA_ReculModeleParent = modeleParent
        ent.NA_ReculOsTete = ent:LookupBone("ValveBiped.Bip01_Head1")
    end
    local os = ent.NA_ReculOsTete
    local tete = os and ent:GetBoneMatrix(os)
    if not tete then return end

    -- Les deux pièces doivent subir exactement le même déplacement dans le
    -- repère de la tête du joueur, quelle que soit la famille de cheveux.
    -- La pose propre à chaque modèle reste compensée par NA_PoseInv.
    local modele = cs:GetModel()
    if cs.NA_PoseModele ~= modele then
        cs.NA_PoseInv = nil
        cs.NA_ReculLocal = nil
        cs.NA_PoseModele = modele
    end

    if not cs.NA_PoseInv then   -- pose réelle de l'os de tête du modèle, mesurée à l'origine
        cs:SetPlaybackRate(0)
        cs:SetPos(vector_origin)
        cs:SetAngles(angle_zero)
        cs:InvalidateBoneCache()
        cs:SetupBones()
        local osCs = cs:LookupBone("ValveBiped.Bip01_Head1")
        local pose = osCs and cs:GetBoneMatrix(osCs)
        if not pose then return end   -- pas encore prêt : image suivante
        cs.NA_PoseInv = pose:GetInverse()
    end

    -- Le décalage local est constant tant que le modèle et le réglage restent
    -- identiques : seule la matrice animée du joueur change à chaque dessin.
    if not cs.NA_ReculLocal or cs.NA_ReculValeur ~= recul then
        translation:SetTranslation(Vector(0, recul / 10, 0))
        cs.NA_ReculLocal = REPERE_RECUL_INV * translation * REPERE_RECUL * cs.NA_PoseInv
        cs.NA_ReculValeur = recul
    end
    local placement = tete * cs.NA_ReculLocal
    cs:SetPos(placement:GetTranslation())
    cs:SetAngles(placement:GetAngles())
    -- SetupBones peut réutiliser une pose déjà calculée dans cette image
    -- (ombres, autre vue ou mesure initiale), malgré le nouveau placement.
    cs:InvalidateBoneCache()
    cs:SetupBones()

    -- Dessin centralisé : les effets de visage peuvent muter temporairement le matériau
    -- atg/face/face sans dépendre des submaterials/overrides par index.
    NA_DrawModelAvecFaceMutation(cs, nil, cs.NA_Owner)
end

local copies = {}   -- joueur -> { tete = ClientsideModel, cheveux = ClientsideModel }

-- Renvoie la tête réellement visible côté client.
-- Avec recul > 0, NA_TeteEnt est volontairement masquée et remplacée par copies[ply].tete.
-- Les systèmes d'apparence (tatouages, marques, overrides de matériau...) doivent cibler
-- cette fonction plutôt que ply:GetNW2Entity("NA_TeteEnt") directement.
function NA_GetTeteRendue(ply)
    if not IsValid(ply) then return end
    local c = copies[ply]
    if c and IsValid(c.tete) then return c.tete end
    local tete = ply:GetNW2Entity("NA_TeteEnt")
    if IsValid(tete) then return tete end
end

local function Vider(ply)
    local c = copies[ply]
    if not c then return end
    if IsValid(c.tete) then c.tete:Remove() end
    if IsValid(c.cheveux) then c.cheveux:Remove() end
    copies[ply] = nil
    if IsValid(ply) then   -- les props du serveur se redessinent (sauf joueur invisible)
        local cache = ply:GetNWBool("IsInvisible", false)
        for _, cle in ipairs({ "NA_TeteEnt", "NA_CheveuxEnt" }) do
            local e = ply:GetNW2Entity(cle)
            if IsValid(e) then e:SetNoDraw(cache) end
        end
    end
end

-- Crée ou remet à jour la copie de src (prop du serveur), rend le ClientsideModel
local function Copie(c, cle, src)
    local mdl = src:GetModel() or ""
    if not IsValid(c[cle]) or string.lower(c[cle]:GetModel() or "") ~= string.lower(mdl) then
        if IsValid(c[cle]) then c[cle]:Remove() end
        c[cle] = ClientsideModel(mdl, RENDERGROUP_OPAQUE)
        if not IsValid(c[cle]) then return end
        c[cle]:SetNoDraw(true)
        c[cle].NA_Json = nil
    end
    return c[cle]
end

hook.Add("PostPlayerDraw", "NA_Perso_Recul", function(ply)
    local tete = ply:GetNW2Entity("NA_TeteEnt")
    local persoJson = ply:GetNW2String("NA_Perso", "")
    local p = NA_PERSO.Decoder(persoJson)
    if not IsValid(tete) or p.visage == 0 or p.recul == 0 then
        if copies[ply] then Vider(ply) end
        return
    end
    local cheveux = ply:GetNW2Entity("NA_CheveuxEnt")

    -- nos copies remplacent les props du serveur : on ne dessine plus ceux-ci
    tete:SetNoDraw(true)
    if IsValid(cheveux) then cheveux:SetNoDraw(true) end

    if not ply:Alive() or ply:GetNWBool("IsInvisible", false) then return end
    if ply == LocalPlayer() and not ply:ShouldDrawLocalPlayer() then return end   -- première personne

    copies[ply] = copies[ply] or {}
    local c = copies[ply]
    local yeux = ply:GetNW2String("NA_Yeux", "")
    local json = persoJson .. "|" .. yeux

    local ct = Copie(c, "tete", tete)
    if ct then
        ct.NA_Owner = ply
        local faceKey = hook.Run("NA_GetFaceMaterialCacheKey", ply) or ""
        local jsonFace = json .. "|facefx:" .. tostring(faceKey)
        if ct.NA_Json ~= jsonFace then
            ct.NA_Json = jsonFace
            NA_HabillerVisage(ct, p, yeux)
        end
        NA_PoserFormes(ct, NA_YeuxFermes and NA_YeuxFermes(tete) or 0)   -- clignement
        -- Point d'extension unique pour tout ce qui doit modifier la tête VISIBLE juste
        -- avant son dessin (tatouages, material override, debug...).
        hook.Run("NA_PreDrawTetePerso", ply, ct, tete)
        NA_DessinerRecul(ct, ply, p.recul)
        hook.Run("NA_PostDrawTetePerso", ply, ct, tete)
    end

    if IsValid(cheveux) then
        local cc = Copie(c, "cheveux", cheveux)
        if cc then
            if cc.NA_Json ~= json then
                cc.NA_Json = json
                NA_TeinterCheveux(cc, p)
            end
            NA_DessinerRecul(cc, ply, p.recul)
        end
    end
end)

timer.Create("NA_Perso_Recul_Nettoyage", 2, 0, function()
    for ply in pairs(copies) do
        if not IsValid(ply) then Vider(ply) end
    end
end)
